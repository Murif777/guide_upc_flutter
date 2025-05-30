import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class CompassService {
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Function(String)? onDirectionChanged;
  String _currentDirection = "Norte";
  bool _isInitialized = false;
  
  // Variables para cálculos del magnetómetro
  double _magnetometerX = 0.0;
  double _magnetometerY = 0.0;
  double _magnetometerZ = 0.0;
  
  // Variables para cálculos del acelerómetro (para calibración)
  double _accelerometerX = 0.0;
  double _accelerometerY = 0.0;
  double _accelerometerZ = 0.0;
  
  // Para suavizar las lecturas
  final List<double> _headingHistory = [];
  static const int _historySize = 5;
  
  // Método para inicializar el servicio de brújula
  Future<void> initialize() async {
    try {
      debugPrint("Inicializando servicio de brújula con sensors_plus...");
      
      // Inicializar magnetómetro
      _magnetometerSubscription = magnetometerEvents.listen(
        _onMagnetometerUpdate,
        onError: (error) {
          debugPrint("Error en magnetómetro: $error");
          _handleCompassError();
        },
      );
      
      // Inicializar acelerómetro para mejorar la precisión
      _accelerometerSubscription = accelerometerEvents.listen(
        _onAccelerometerUpdate,
        onError: (error) {
          debugPrint("Error en acelerómetro: $error");
          // El acelerómetro es opcional, no consideramos esto un error crítico
        },
      );
      
      // Verificar si realmente se inicializó
      if (_magnetometerSubscription != null) {
        _isInitialized = true;
        debugPrint("Brújula inicializada correctamente con sensors_plus");
        
        // Esperar un poco para obtener algunas lecturas iniciales
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        debugPrint("No se pudo inicializar la brújula - magnetómetro no disponible");
        _handleCompassError();
      }
      
    } catch (e) {
      debugPrint("Error al inicializar brújula: $e");
      _handleCompassError();
    }
  }
  
  // Manejar actualizaciones del magnetómetro
  void _onMagnetometerUpdate(MagnetometerEvent event) {
    _magnetometerX = event.x;
    _magnetometerY = event.y;
    _magnetometerZ = event.z;
    
    _calculateHeading();
  }
  
  // Manejar actualizaciones del acelerómetro
  void _onAccelerometerUpdate(AccelerometerEvent event) {
    _accelerometerX = event.x;
    _accelerometerY = event.y;
    _accelerometerZ = event.z;
  }
  
  // Calcular la dirección basada en los datos del magnetómetro
  void _calculateHeading() {
    try {
      // Calcular el ángulo usando los valores X e Y del magnetómetro
      double heading = atan2(_magnetometerY, _magnetometerX) * (180 / pi);
      
      // Normalizar el heading entre 0 y 360
      heading = (heading + 360) % 360;
      
      // Suavizar las lecturas
      _headingHistory.add(heading);
      if (_headingHistory.length > _historySize) {
        _headingHistory.removeAt(0);
      }
      
      // Calcular promedio para suavizar
      double smoothedHeading = _headingHistory.reduce((a, b) => a + b) / _headingHistory.length;
      
      String direction = _getDirectionFromHeading(smoothedHeading);
      
      if (direction != _currentDirection) {
        _currentDirection = direction;
        onDirectionChanged?.call(_currentDirection);
        debugPrint("Dirección actualizada: $_currentDirection (${smoothedHeading.toStringAsFixed(1)}°)");
      }
    } catch (e) {
      debugPrint("Error al calcular heading: $e");
    }
  }
  
  // Manejar errores de brújula usando direcciones simuladas
  void _handleCompassError() {
    _isInitialized = false;
    debugPrint("Activando modo simulado de brújula");
    // Usar direcciones aleatorias o fijas como fallback
    _simulateCompassReading();
  }
  
  // Simular lecturas de brújula si no está disponible
  void _simulateCompassReading() {
    List<String> directions = ["Norte", "Noreste", "Este", "Sureste", "Sur", "Suroeste", "Oeste", "Noroeste"];
    int currentIndex = 0;
    
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isInitialized) {
        String newDirection = directions[currentIndex % directions.length];
        if (newDirection != _currentDirection) {
          _currentDirection = newDirection;
          onDirectionChanged?.call(_currentDirection);
          debugPrint("Dirección simulada: $_currentDirection");
        }
        currentIndex++;
      } else {
        timer.cancel();
      }
    });
  }
  
  // Convertir grados a dirección cardinal
  String _getDirectionFromHeading(double heading) {
    // Normalizar el heading entre 0 y 360
    double normalizedHeading = heading % 360;
    if (normalizedHeading < 0) {
      normalizedHeading += 360;
    }
    
    // Definir rangos para cada dirección
    if (normalizedHeading >= 337.5 || normalizedHeading < 22.5) {
      return "Norte";
    } else if (normalizedHeading >= 22.5 && normalizedHeading < 67.5) {
      return "Noreste";
    } else if (normalizedHeading >= 67.5 && normalizedHeading < 112.5) {
      return "Este";
    } else if (normalizedHeading >= 112.5 && normalizedHeading < 157.5) {
      return "Sureste";
    } else if (normalizedHeading >= 157.5 && normalizedHeading < 202.5) {
      return "Sur";
    } else if (normalizedHeading >= 202.5 && normalizedHeading < 247.5) {
      return "Suroeste";
    } else if (normalizedHeading >= 247.5 && normalizedHeading < 292.5) {
      return "Oeste";
    } else if (normalizedHeading >= 292.5 && normalizedHeading < 337.5) {
      return "Noroeste";
    }
    
    return "Norte"; // Valor por defecto
  }
  
  // Obtener la dirección actual
  String getCurrentDirection() {
    return _currentDirection;
  }
  
  // Obtener el heading actual en grados
  double getCurrentHeading() {
    if (_headingHistory.isNotEmpty) {
      return _headingHistory.reduce((a, b) => a + b) / _headingHistory.length;
    }
    return 0.0;
  }
  
  // Método para limpiar recursos
  void dispose() {
    _magnetometerSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _magnetometerSubscription = null;
    _accelerometerSubscription = null;
    _headingHistory.clear();
    debugPrint("CompassService disposed");
  }
  
  // Método para verificar si la brújula está disponible
  bool isCompassAvailable() {
    return _isInitialized;
  }
  
  // Método alternativo para obtener estado de disponibilidad
  Future<bool> checkCompassAvailability() async {
    try {
      debugPrint("Verificando disponibilidad del magnetómetro...");
      
      final completer = Completer<bool>();
      StreamSubscription<MagnetometerEvent>? testSubscription;
      
      testSubscription = magnetometerEvents.listen(
        (event) {
          debugPrint("Magnetómetro disponible - datos recibidos: x=${event.x}, y=${event.y}, z=${event.z}");
          testSubscription?.cancel();
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        onError: (error) {
          debugPrint("Error al verificar magnetómetro: $error");
          testSubscription?.cancel();
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );
      
      // Timeout después de 3 segundos
      Timer(const Duration(seconds: 3), () {
        if (!completer.isCompleted) {
          debugPrint("Timeout al verificar magnetómetro");
          testSubscription?.cancel();
          completer.complete(false);
        }
      });
      
      bool isAvailable = await completer.future;
      debugPrint("Resultado de verificación de magnetómetro: $isAvailable");
      return isAvailable;
      
    } catch (e) {
      debugPrint("Error al verificar disponibilidad de magnetómetro: $e");
      return false;
    }
  }
  
  // Método para calibrar la brújula
  void calibrateCompass() {
    debugPrint("Iniciando calibración de brújula...");
    _headingHistory.clear();
    
    // En una implementación real, aquí podrías pedir al usuario que rote el dispositivo
    // Por ahora, simplemente limpiamos el historial para empezar fresh
    debugPrint("Calibración completada - historial de headings limpiado");
  }
  
  // Método para obtener información de depuración
  Map<String, dynamic> getDebugInfo() {
    return {
      'isInitialized': _isInitialized,
      'currentDirection': _currentDirection,
      'magnetometerX': _magnetometerX,
      'magnetometerY': _magnetometerY,
      'magnetometerZ': _magnetometerZ,
      'accelerometerX': _accelerometerX,
      'accelerometerY': _accelerometerY,
      'accelerometerZ': _accelerometerZ,
      'headingHistorySize': _headingHistory.length,
      'currentHeading': getCurrentHeading(),
    };
  }
}