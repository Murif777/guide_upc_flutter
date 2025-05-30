// controllers/navigation_controller.dart
import 'package:flutter/material.dart';
import 'package:guide_upc_f/services/compass_service.dart';
import 'package:guide_upc_f/services/speech_service.dart';
import 'package:guide_upc_f/providers/voice_provider.dart';
import 'dart:async';

class NavigationController {
  final CompassService _compassService;
  final SpeechService _speechService;
  final VoidCallback? onNavigationComplete;
  final Function(String)? onStateUpdate;
  
  List<String> _navigationSteps = [];
  int _currentStepIndex = -1;
  bool _isNavigating = false;
  bool _isWaitingForConfirmation = false; // Nuevo estado
  Timer? _compassTimer;
  String _currentDirection = "";
  
  NavigationController({
    required CompassService compassService,
    required SpeechService speechService,
    this.onNavigationComplete,
    this.onStateUpdate,
  }) : _compassService = compassService, _speechService = speechService;

  // Getters
  bool get isNavigating => _isNavigating;
  bool get isWaitingForConfirmation => _isWaitingForConfirmation; // Nuevo getter
  int get currentStepIndex => _currentStepIndex;
  List<String> get navigationSteps => List.unmodifiable(_navigationSteps);
  String get currentDirection => _currentDirection;
  
  void initialize() {
    _compassService.onDirectionChanged = (direction) {
      _currentDirection = direction;
      debugPrint("Dirección actualizada: $direction");
    };
  }

  List<String> extractNavigationSteps(String response) {
    List<String> steps = [];
    List<String> lines = response.split('\n');
    
    for (String line in lines) {
      String trimmedLine = line.trim();
      RegExp regExp = RegExp(r'^\s*(\d+)[\.\)\-\s]+(.+)$');
      RegExpMatch? match = regExp.firstMatch(trimmedLine);
      
      if (match != null) {
        String step = match.group(2)?.trim() ?? '';
        if (step.isNotEmpty) {
          steps.add(step);
          debugPrint("Paso extraído: $step");
        }
      } else {
        RegExp altRegExp = RegExp(r'^\s*(paso|step)\s*(\d+)\s*[:\-]?\s*(.+)$', caseSensitive: false);
        RegExpMatch? altMatch = altRegExp.firstMatch(trimmedLine);
        
        if (altMatch != null) {
          String step = altMatch.group(3)?.trim() ?? '';
          if (step.isNotEmpty) {
            steps.add(step);
            debugPrint("Paso extraído (alternativo): $step");
          }
        }
      }
    }
    
    if (steps.isEmpty) {
      List<String> sentences = response.split(RegExp(r'[.;]\s*'));
      for (String sentence in sentences) {
        String trimmed = sentence.trim();
        if (trimmed.isNotEmpty && 
            (trimmed.toLowerCase().contains('camina') ||
             trimmed.toLowerCase().contains('dirígete') ||
             trimmed.toLowerCase().contains('ve hacia') ||
             trimmed.toLowerCase().contains('sigue') ||
             trimmed.toLowerCase().contains('gira') ||
             trimmed.toLowerCase().contains('continúa'))) {
          steps.add(trimmed);
          debugPrint("Paso extraído por contenido: $trimmed");
        }
      }
    }
    
    debugPrint("Total de pasos extraídos: ${steps.length}");
    return steps;
  }

  // Nuevo método: solicitar confirmación para iniciar navegación
  void requestNavigationConfirmation(List<String> steps, VoiceProvider voiceProvider) {
    if (steps.isEmpty) {
      debugPrint("No se encontraron pasos de navegación");
      _safeSetSpeaking(voiceProvider, false);
      return;
    }
    
    _navigationSteps = steps;
    _currentStepIndex = -1; // No hemos empezado aún
    _isNavigating = false;   // No navegando aún
    _isWaitingForConfirmation = true; // Esperando confirmación
    
    String confirmationText = "He encontrado una ruta con ${steps.length} intrucciones. Comenzaremos la navegación paso a paso en cuanto confirme diciendo 'Comenzar navegación'.";
    
    debugPrint("Solicitando confirmación de navegación: $confirmationText");
    onStateUpdate?.call(confirmationText);
    
    _safeSetSpeaking(voiceProvider, true);
    
    Timer? confirmationTimeout = Timer(const Duration(seconds: 15), () {
      debugPrint("TIMEOUT: El speech de confirmación se demoró demasiado");
      _safeSetSpeaking(voiceProvider, false);
      _startListeningForConfirmation(voiceProvider);
    });
    
    _speechService.speakText(confirmationText, () {
      confirmationTimeout?.cancel();
      debugPrint("Terminó de hablar la confirmación");
      _safeSetSpeaking(voiceProvider, false);
      _startListeningForConfirmation(voiceProvider);
    });
  }

  void _startListeningForConfirmation(VoiceProvider voiceProvider) async {
    debugPrint("=== _startListeningForConfirmation llamado ===");
    
    if (!_isWaitingForConfirmation) {
      debugPrint("Ya no esperando confirmación - saliendo");
      return;
    }
    
    // Pequeño delay para asegurar que no esté hablando
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (voiceProvider.isSpeaking) {
      debugPrint("Todavía hablando, esperando...");
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    try {
      debugPrint("Iniciando escucha para confirmación...");
      final started = await voiceProvider.startListening();
      if (started) {
        debugPrint("Escucha para confirmación iniciada correctamente");
      } else {
        debugPrint("No se pudo iniciar la escucha para confirmación");
        // Reintentar una vez
        await Future.delayed(const Duration(milliseconds: 500));
        final retryStarted = await voiceProvider.startListening();
        debugPrint("Reintento de escucha para confirmación: $retryStarted");
      }
    } catch (e) {
      debugPrint("Error en startListening para confirmación: $e");
    }
  }

  // Nuevo método: confirmar e iniciar navegación
  void confirmAndStartNavigation(VoiceProvider voiceProvider) {
    debugPrint("=== confirmAndStartNavigation llamado ===");
    
    if (!_isWaitingForConfirmation) {
      debugPrint("No se estaba esperando confirmación");
      return;
    }
    
    if (_navigationSteps.isEmpty) {
      debugPrint("No hay pasos de navegación guardados");
      _isWaitingForConfirmation = false;
      return;
    }
    
    // Cambiar estados
    _isWaitingForConfirmation = false;
    _isNavigating = true;
    _currentStepIndex = 0;
    
    debugPrint("Navegación confirmada. Iniciando con ${_navigationSteps.length} pasos");
    
    // Detener escucha si está activa
    if (voiceProvider.isListening) {
      voiceProvider.stopListening();
    }
    
    // Pequeño delay antes de empezar a hablar la primera instrucción
    Future.delayed(const Duration(milliseconds: 200), () {
      _speakCurrentNavigationStep(voiceProvider);
    });
  }

  // Nuevo método: cancelar confirmación
  void cancelNavigationConfirmation(VoiceProvider voiceProvider) {
    debugPrint("=== cancelNavigationConfirmation llamado ===");
    
    _isWaitingForConfirmation = false;
    _isNavigating = false;
    _currentStepIndex = -1;
    _navigationSteps.clear();
    
    String cancelText = "Navegación cancelada. ¿Qué más puedo ayudarte?";
    onStateUpdate?.call(cancelText);
    
    _safeSetSpeaking(voiceProvider, true);
    
    Timer? cancelTimeout = Timer(const Duration(seconds: 10), () {
      debugPrint("TIMEOUT: El speech de cancelación se demoró demasiado");
      _safeSetSpeaking(voiceProvider, false);
      _tryAutoStartListening(voiceProvider);
    });
    
    _speechService.speakText(cancelText, () {
      cancelTimeout?.cancel();
      _safeSetSpeaking(voiceProvider, false);
      _tryAutoStartListening(voiceProvider);
    });
  }

  // Nuevo método: manejar comandos durante la espera de confirmación
  void handleConfirmationCommand(String command, VoiceProvider voiceProvider) {
    debugPrint("=== handleConfirmationCommand llamado con: '$command' ===");
    
    String lowerCommand = command.toLowerCase().trim();
    
    if (lowerCommand.contains("comenzar navegación") || 
        lowerCommand.contains("comenzar navegacion") ||
        lowerCommand.contains("iniciar navegación") ||
        lowerCommand.contains("iniciar navegacion") ||
        lowerCommand.contains("comenzar") ||
        lowerCommand.contains("iniciar") ||
        lowerCommand.contains("empezar") ||
        lowerCommand.contains("si") ||
        lowerCommand.contains("sí") ||
        lowerCommand.contains("confirmar") ||
        lowerCommand.contains("confirmo")) {
      confirmAndStartNavigation(voiceProvider);
    } else if (lowerCommand.contains("no") ||
               lowerCommand.contains("cancelar") ||
               lowerCommand.contains("salir") ||
               lowerCommand.contains("terminar")) {
      cancelNavigationConfirmation(voiceProvider);
    } else {
      // Comando no reconocido durante confirmación
      String errorText = "No entendí su respuesta. Diga 'comenzar navegación' para iniciar la ruta, o 'cancelar' para salir.";
      
      _safeSetSpeaking(voiceProvider, true);
      
      Timer? errorTimeout = Timer(const Duration(seconds: 10), () {
        debugPrint("TIMEOUT: El speech de error en confirmación se demoró demasiado");
        _safeSetSpeaking(voiceProvider, false);
        _startListeningForConfirmation(voiceProvider);
      });
      
      _speechService.speakText(errorText, () {
        errorTimeout?.cancel();
        _safeSetSpeaking(voiceProvider, false);
        _startListeningForConfirmation(voiceProvider);
      });
    }
  }

  void _speakCurrentNavigationStep(VoiceProvider voiceProvider) {
    debugPrint("=== _speakCurrentNavigationStep llamado ===");
    debugPrint("_currentStepIndex: $_currentStepIndex");
    debugPrint("_navigationSteps.length: ${_navigationSteps.length}");
    debugPrint("_isNavigating: $_isNavigating");
    debugPrint("voiceProvider.isSpeaking: ${voiceProvider.isSpeaking}");
    
    if (!_isNavigating) {
      debugPrint("Navegación no está activa - saliendo");
      _safeSetSpeaking(voiceProvider, false);
      return;
    }
    
    if (_currentStepIndex < 0 || _currentStepIndex >= _navigationSteps.length) {
      debugPrint("ERROR: Índice de paso inválido: $_currentStepIndex");
      debugPrint("Rango válido: 0 a ${_navigationSteps.length - 1}");
      completeNavigation(voiceProvider);
      return;
    }

    String currentStep = _navigationSteps[_currentStepIndex];
    debugPrint("Paso actual: $currentStep");
    
    String responseText = "Paso ${_currentStepIndex + 1} de ${_navigationSteps.length}: $currentStep";
    onStateUpdate?.call(responseText);
    
    String speechText = "Paso ${_currentStepIndex + 1}: $currentStep";
    debugPrint("Texto a hablar: $speechText");
    
    _safeSetSpeaking(voiceProvider, true);
    
    Timer? speechTimeout = Timer(const Duration(seconds: 15), () {
      debugPrint("TIMEOUT: El speech se demoró demasiado");
      _safeSetSpeaking(voiceProvider, false);
      _askToContinueNavigation(voiceProvider);
    });
    
    _speechService.speakText(speechText, () {
      speechTimeout?.cancel();
      debugPrint("Terminó de hablar el paso ${_currentStepIndex + 1}");
      _safeSetSpeaking(voiceProvider, false);
      
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_isNavigating) {
          _askToContinueNavigation(voiceProvider);
        }
      });
    });
  }

  void _askToContinueNavigation(VoiceProvider voiceProvider) {
    debugPrint("=== _askToContinueNavigation llamado ===");
    debugPrint("_isNavigating: $_isNavigating");
    debugPrint("_currentStepIndex: $_currentStepIndex");
    debugPrint("Total steps: ${_navigationSteps.length}");
    
    if (!_isNavigating) {
      debugPrint("Navegación ya no está activa");
      _safeSetSpeaking(voiceProvider, false);
      return;
    }
    
    if (_currentStepIndex < _navigationSteps.length - 1) {
      String continueText = "¿Quiere continuar con la siguiente instrucción? Diga 'siguiente' para continuar.";
      
      if (_compassService.isCompassAvailable() && _currentDirection.isNotEmpty) {
        continueText += " En este momento se encuentra mirando hacia el $_currentDirection.";
      }
      
      onStateUpdate?.call(continueText);
      debugPrint("Preguntando para continuar: $continueText");
      
      _safeSetSpeaking(voiceProvider, true);
      
      Timer? continueTimeout = Timer(const Duration(seconds: 8), () {
        debugPrint("TIMEOUT: El speech de continuación se demoró demasiado");
        _safeSetSpeaking(voiceProvider, false);
        _startListeningAfterSpeech(voiceProvider);
      });
      
      _speechService.speakText(continueText, () {
        continueTimeout?.cancel();
        debugPrint("Terminó de preguntar para continuar");
        _safeSetSpeaking(voiceProvider, false);
        _startListeningAfterSpeech(voiceProvider);
      });
    } else {
      debugPrint("Último paso completado");
      completeNavigation(voiceProvider);
    }
  }

  void _startListeningAfterSpeech(VoiceProvider voiceProvider) async {
    debugPrint("=== _startListeningAfterSpeech llamado ===");
    
    if (!_isNavigating) {
      debugPrint("Navegación no está activa - no iniciar escucha");
      return;
    }
    
    if (voiceProvider.isSpeaking) {
      debugPrint("Todavía hablando, esperando...");
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    try {
      debugPrint("Intentando iniciar escucha...");
      final started = await voiceProvider.startListening();
      if (started) {
        debugPrint("Escucha iniciada correctamente");
        if (_compassService.isCompassAvailable()) {
          _startCompassUpdates(voiceProvider);
        }
      } else {
        debugPrint("No se pudo iniciar la escucha");
        await Future.delayed(const Duration(milliseconds: 500));
        final retryStarted = await voiceProvider.startListening();
        debugPrint("Reintento de escucha: $retryStarted");
      }
    } catch (e) {
      debugPrint("Error en startListening: $e");
    }
  }

  void handleNextNavigationStep(VoiceProvider voiceProvider) {
    debugPrint("=== handleNextNavigationStep llamado ===");
    debugPrint("_currentStepIndex antes: $_currentStepIndex");
    
    _stopCompassUpdates();
    if (voiceProvider.isListening) {
      voiceProvider.stopListening();
    }
    
    if (_currentStepIndex < _navigationSteps.length - 1) {
      _currentStepIndex++;
      debugPrint("Avanzando al paso ${_currentStepIndex + 1}");
      _speakCurrentNavigationStep(voiceProvider);
    } else {
      debugPrint("Ya en el último paso");
      completeNavigation(voiceProvider);
    }
  }

  void repeatCurrentStep(VoiceProvider voiceProvider) {
    debugPrint("=== repeatCurrentStep llamado ===");
    _stopCompassUpdates();
    if (voiceProvider.isListening) {
      voiceProvider.stopListening();
    }
    _speakCurrentNavigationStep(voiceProvider);
  }

  void completeNavigation(VoiceProvider voiceProvider) {
    debugPrint("=== completeNavigation llamado ===");
    
    String completionText = "Has llegado a tu destino. Navegación completada. ¿Qué más puedo ayudarte?";
    
    _isNavigating = false;
    _isWaitingForConfirmation = false;
    _currentStepIndex = -1;
    _navigationSteps.clear();
    
    _stopCompassUpdates();
    debugPrint("Navegación completada");
    
    onStateUpdate?.call(completionText);
    
    _safeSetSpeaking(voiceProvider, true);
    
    Timer? completionTimeout = Timer(const Duration(seconds: 15), () {
      debugPrint("TIMEOUT: El speech de completación se demoró demasiado");
      _safeSetSpeaking(voiceProvider, false);
      _tryAutoStartListening(voiceProvider);
    });
    
    _speechService.speakText(completionText, () {
      completionTimeout?.cancel();
      debugPrint("Terminó de hablar completación");
      _safeSetSpeaking(voiceProvider, false);
      _tryAutoStartListening(voiceProvider);
      onNavigationComplete?.call();
    });
  }

  void cancelNavigation(VoiceProvider voiceProvider) {
    debugPrint("=== cancelNavigation llamado ===");
    
    _isNavigating = false;
    _isWaitingForConfirmation = false;
    _currentStepIndex = -1;
    _navigationSteps.clear();
    _stopCompassUpdates();
    
    String cancelText = "Navegación cancelada. ¿Qué más puedo ayudarte?";
    onStateUpdate?.call(cancelText);
    
    _safeSetSpeaking(voiceProvider, true);
    
    Timer? cancelTimeout = Timer(const Duration(seconds: 10), () {
      debugPrint("TIMEOUT: El speech de cancelación se demoró demasiado");
      _safeSetSpeaking(voiceProvider, false);
      _tryAutoStartListening(voiceProvider);
    });
    
    _speechService.speakText(cancelText, () {
      cancelTimeout?.cancel();
      _safeSetSpeaking(voiceProvider, false);
      _tryAutoStartListening(voiceProvider);
    });
    
    debugPrint("Navegación cancelada por el usuario");
  }

  void _tryAutoStartListening(VoiceProvider voiceProvider) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_isNavigating && !_isWaitingForConfirmation) {
      try {
        await voiceProvider.startListening();
        debugPrint("Auto-inicio de escucha exitoso");
      } catch (e) {
        debugPrint("Error en auto-inicio de escucha: $e");
      }
    }
  }

  void handleNavigationCommand(String command, VoiceProvider voiceProvider) {
    debugPrint("=== handleNavigationCommand llamado con: '$command' ===");
    
    String lowerCommand = command.toLowerCase().trim();
    
    if (lowerCommand.contains("siguiente") || lowerCommand.contains("continuar") || lowerCommand.contains("continua")) {
      handleNextNavigationStep(voiceProvider);
    } else if (lowerCommand.contains("repetir") || lowerCommand.contains("repite") || lowerCommand.contains("otra vez")) {
      repeatCurrentStep(voiceProvider);
    } else if (lowerCommand.contains("cancelar") || lowerCommand.contains("parar") || lowerCommand.contains("salir") || lowerCommand.contains("terminar")) {
      cancelNavigation(voiceProvider);
    } else if (lowerCommand.contains("dirección") || lowerCommand.contains("orientación") || lowerCommand.contains("hacia donde")) {
      _handleDirectionQuery(voiceProvider);
    } else {
      String errorText = "Comando no reconocido. Diga 'siguiente' para continuar, 'repetir' para escuchar de nuevo, 'dirección' para conocer su orientación, o 'cancelar' para salir de la navegación.";
      
      _safeSetSpeaking(voiceProvider, true);
      
      Timer? errorTimeout = Timer(const Duration(seconds: 10), () {
        debugPrint("TIMEOUT: El speech de error se demoró demasiado");
        _safeSetSpeaking(voiceProvider, false);
        _startListeningAfterSpeech(voiceProvider);
      });
      
      _speechService.speakText(errorText, () {
        errorTimeout?.cancel();
        _safeSetSpeaking(voiceProvider, false);
        _startListeningAfterSpeech(voiceProvider);
      });
    }
  }

  void _handleDirectionQuery(VoiceProvider voiceProvider) {
    String directionText;
    
    if (_compassService.isCompassAvailable() && _currentDirection.isNotEmpty) {
      directionText = "Actualmente se encuentra mirando hacia el $_currentDirection";
    } else {
      directionText = "No puedo determinar su orientación actual";
    }
    
    _safeSetSpeaking(voiceProvider, true);
    
    Timer? directionTimeout = Timer(const Duration(seconds: 10), () {
      debugPrint("TIMEOUT: El speech de dirección se demoró demasiado");
      _safeSetSpeaking(voiceProvider, false);
      _startListeningAfterSpeech(voiceProvider);
    });
    
    _speechService.speakText(directionText, () {
      directionTimeout?.cancel();
      _safeSetSpeaking(voiceProvider, false);
      _startListeningAfterSpeech(voiceProvider);
    });
  }

  void _startCompassUpdates(VoiceProvider voiceProvider) {
    _stopCompassUpdates();
    
    if (!_compassService.isCompassAvailable()) {
      debugPrint("Brújula no disponible para actualizaciones");
      return;
    }
    
    _compassTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isNavigating) {
        debugPrint("Deteniendo actualizaciones de brújula - navegación no activa");
        timer.cancel();
        return;
      }
      
      if (!voiceProvider.isSpeaking && !voiceProvider.isListening) {
        if (_currentDirection.isNotEmpty) {
          String directionText = "Actualmente mirando hacia el $_currentDirection";
          debugPrint("Actualizando dirección: $directionText");
          
          _safeSetSpeaking(voiceProvider, true);
          _speechService.speakText(directionText, () {
            _safeSetSpeaking(voiceProvider, false);
          });
        }
      }
    });
  }

  void _stopCompassUpdates() {
    _compassTimer?.cancel();
    _compassTimer = null;
  }

  void _safeSetSpeaking(VoiceProvider voiceProvider, bool value) {
  try {
    voiceProvider.setIsSpeaking(value);
    debugPrint("isSpeaking establecido a: $value");
    
    // Si se está estableciendo a false y el TTS realmente terminó,
    // asegurar que el callback global también se ejecute
    if (!value && !_speechService.isSpeaking()) {
      debugPrint("TTS realmente ha terminado, estado sincronizado");
    }
  } catch (e) {
    debugPrint("Error al establecer isSpeaking: $e");
  }
}

  void dispose() {
    _stopCompassUpdates();
  }
}