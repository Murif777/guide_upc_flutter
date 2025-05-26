import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:guide_upc_f/services/speech_service.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceProvider extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final SpeechService _speechService = SpeechService();
  
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isAvailable = false;
  bool _hasPermission = false;
  bool _isButtonPressed = false;
  bool _isInitialized = false;
  String _transcribedText = '';
  String _inputText = '';
  List<String> _partialResults = [];
  String _lastError = '';

  // Getters
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isAvailable => _isAvailable;
  bool get hasPermission => _hasPermission;
  bool get isButtonPressed => _isButtonPressed;
  bool get isInitialized => _isInitialized;
  String get transcribedText => _transcribedText;
  String get inputText => _inputText;
  List<String> get partialResults => _partialResults;
  String get lastError => _lastError;

  VoiceProvider() {
    _initSpeech();
  }

  // Initialize speech recognition
  Future<void> _initSpeech() async {
    try {
      debugPrint('Iniciando configuración de reconocimiento de voz...');
      
      // Primero solicitar permisos explícitamente
      await _requestMicrophonePermission();
      
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            notifyListeners();
          } else if (status == 'listening') {
            _isListening = true;
            notifyListeners();
          }
        },
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg} - ${error.permanent}');
          _lastError = error.errorMsg;
          _isListening = false;
          
          // Si es un error permanente, reinicializar
          if (error.permanent) {
            _isAvailable = false;
            _hasPermission = false;
          }
          notifyListeners();
        },
        debugLogging: kDebugMode,
      );
      
      if (_isAvailable) {
        _hasPermission = await _speech.hasPermission;
        _isInitialized = true;
        debugPrint('Reconocimiento de voz inicializado correctamente');
        debugPrint('Disponible: $_isAvailable, Permisos: $_hasPermission');
      } else {
        debugPrint('Reconocimiento de voz no disponible');
        _lastError = 'Reconocimiento de voz no disponible en este dispositivo';
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing speech: $e');
      _isAvailable = false;
      _hasPermission = false;
      _isInitialized = false;
      _lastError = 'Error al inicializar: $e';
      notifyListeners();
    }
  }

  // Solicitar permisos de micrófono explícitamente
  Future<void> _requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      debugPrint('Permiso de micrófono: $status');
      
      if (status.isDenied || status.isPermanentlyDenied) {
        _hasPermission = false;
        _lastError = 'Permisos de micrófono denegados';
        if (status.isPermanentlyDenied) {
          _lastError = 'Permisos de micrófono denegados permanentemente. Ve a configuración.';
        }
      } else if (status.isGranted) {
        _hasPermission = true;
      }
    } catch (e) {
      debugPrint('Error solicitando permisos: $e');
      _lastError = 'Error al solicitar permisos: $e';
    }
  }

  // Start listening for speech
  Future<bool> startListening() async {
    debugPrint('Intentando iniciar reconocimiento...');
    debugPrint('Estado actual - Escuchando: $_isListening, Hablando: $_isSpeaking, Disponible: $_isAvailable, Permisos: $_hasPermission');
    
    // Verificar si ya está escuchando o hablando
    if (_isListening) {
      debugPrint('Ya está escuchando');
      return false;
    }
    
    if (_isSpeaking) {
      debugPrint('No se puede escuchar mientras se está hablando');
      return false;
    }

    // Verificar si está inicializado
    if (!_isInitialized) {
      debugPrint('Reconocimiento no inicializado, reinicializando...');
      await _initSpeech();
      if (!_isInitialized) {
        _lastError = 'No se pudo inicializar el reconocimiento de voz';
        notifyListeners();
        return false;
      }
    }

    // Verificar disponibilidad
    if (!_isAvailable) {
      debugPrint('Speech recognition not available');
      _lastError = 'Reconocimiento de voz no disponible';
      notifyListeners();
      return false;
    }

    // Verificar permisos
    if (!_hasPermission) {
      debugPrint('No speech recognition permission, requesting...');
      await _requestMicrophonePermission();
      if (!_hasPermission) {
        _lastError = 'Permisos de micrófono requeridos';
        notifyListeners();
        return false;
      }
    }

    // Detener cualquier reconocimiento previo con más tiempo de espera
    if (_speech.isListening) {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Limpiar estado previo
    _partialResults = [];
    _transcribedText = '';
    _lastError = '';
    notifyListeners();

    try {
      debugPrint('Iniciando reconocimiento de voz...');
      
      await _speech.listen(
        localeId: 'es_ES',
        onResult: (result) {
          debugPrint('Resultado recibido: ${result.recognizedWords} (final: ${result.finalResult})');
          if (result.finalResult) {
            _transcribedText = result.recognizedWords;
            _isListening = false;
            debugPrint('Transcripción final: $_transcribedText');
          } else {
            _partialResults = [result.recognizedWords];
          }
          notifyListeners();
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        onSoundLevelChange: (level) {
          // Opcional: mostrar nivel de sonido para debug
          if (kDebugMode && level > 0.5) {
            debugPrint('Nivel de sonido: $level');
          }
        },
      );
      
      // Verificar el estado después de llamar a listen con un pequeño delay
      await Future.delayed(const Duration(milliseconds: 200));
      _isListening = _speech.isListening;
      
      if (_isListening) {
        debugPrint('Reconocimiento iniciado exitosamente');
        _lastError = '';
      } else {
        debugPrint('No se pudo iniciar el reconocimiento');
        _lastError = 'No se pudo iniciar el reconocimiento de voz';
      }
      
      notifyListeners();
      return _isListening;
      
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      _isListening = false;
      _lastError = 'Error al iniciar reconocimiento: $e';
      notifyListeners();
      return false;
    }
  }

  // Stop listening for speech
  Future<bool> stopListening() async {
    if (!_isListening) {
      return true;
    }

    try {
      debugPrint('Deteniendo reconocimiento de voz...');
      await _speech.stop();
      _isListening = false;
      
      // If there are partial results, take them as final
      if (_partialResults.isNotEmpty && _partialResults[0].trim().isNotEmpty) {
        _transcribedText = _partialResults[0];
        debugPrint('Usando resultado parcial como final: $_transcribedText');
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error stopping speech recognition: $e');
      _isListening = false;
      _lastError = 'Error al detener reconocimiento: $e';
      notifyListeners();
      return false;
    }
  }

  // Reset transcription
  void resetTranscription() {
    _transcribedText = '';
    _partialResults = [];
    _lastError = '';
    notifyListeners();
  }

  // Set input text
  void setInputText(String text) {
    _inputText = text;
    notifyListeners();
  }

  // Set is speaking
  void setIsSpeaking(bool value) {
    _isSpeaking = value;
    notifyListeners();
  }

  // Stop speaking
  Future<void> stopSpeaking() async {
    await _speechService.stopSpeaking();
    _isSpeaking = false;
    notifyListeners();
  }

  // Set button pressed
  void setIsButtonPressed(bool value) {
    _isButtonPressed = value;
    notifyListeners();
  }

  // Método para reinicializar el reconocimiento si es necesario
  Future<void> reinitializeSpeech() async {
    debugPrint('Reinicializando reconocimiento de voz...');
    _isInitialized = false;
    _isAvailable = false;
    _hasPermission = false;
    await _initSpeech();
  }

  // Método para obtener información de diagnóstico
  Map<String, dynamic> getDiagnosticInfo() {
    return {
      'isAvailable': _isAvailable,
      'hasPermission': _hasPermission,
      'isInitialized': _isInitialized,
      'isListening': _isListening,
      'isSpeaking': _isSpeaking,
      'lastError': _lastError,
    };
  }
}