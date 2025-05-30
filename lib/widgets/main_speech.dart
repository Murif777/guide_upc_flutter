// main_speech.dart (Updated for auto TTS stop)
import 'package:flutter/material.dart';
import 'package:guide_upc_f/providers/voice_provider.dart';
import 'package:guide_upc_f/services/assistant_service.dart';
import 'package:guide_upc_f/services/speech_service.dart';
import 'package:guide_upc_f/services/user_service.dart';
import 'package:guide_upc_f/services/compass_service.dart';
import 'package:guide_upc_f/widgets/camera_widget.dart';
import 'package:guide_upc_f/controllers/navigation_controller.dart';
import 'package:guide_upc_f/controllers/user_controller.dart';
import 'package:guide_upc_f/controllers/query_processor.dart';
import 'package:provider/provider.dart';

class MainSpeech extends StatefulWidget {
  const MainSpeech({super.key});

  @override
  State<MainSpeech> createState() => _MainSpeechState();
}

class _MainSpeechState extends State<MainSpeech> {
  // Services
  final AssistantService _assistantService = AssistantService();
  final SpeechService _speechService = SpeechService();
  final UserService _userService = UserService();
  final CompassService _compassService = CompassService();
  
  // Controllers
  late NavigationController _navigationController;
  late UserController _userController;
  late QueryProcessor _queryProcessor;
  
  // State variables
  String _responseText = "Presiona el botón para iniciar";
  bool _showCamera = false;
  bool _appInitialized = false;
  String _lastProcessedText = "";

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupVoiceListener();
    _initializeCompass();
    _setupTtsCallback(); // Nuevo método para configurar callback de TTS
  }

  void _initializeControllers() {
    _navigationController = NavigationController(
      compassService: _compassService,
      speechService: _speechService,
      onNavigationComplete: _onNavigationComplete,
      onStateUpdate: _updateResponseText,
    );

    _userController = UserController(
      speechService: _speechService,
      userService: _userService,
      onStateUpdate: _updateResponseText,
      onShowNameInput: _setShowNameInput,
    );

    _queryProcessor = QueryProcessor(
      assistantService: _assistantService,
      speechService: _speechService,
      navigationController: _navigationController,
      userController: _userController,
      onStateUpdate: _updateResponseText,
    );

    _navigationController.initialize();
  }

  // Nuevo método para configurar el callback de finalización de TTS
  void _setupTtsCallback() {
    _speechService.setTtsCompleteCallback(() {
      debugPrint("=== TTS ha terminado completamente ===");
      
      // Usar addPostFrameCallback para asegurar que el contexto esté disponible
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
          
          debugPrint("Estado actual del VoiceProvider:");
          debugPrint("- isSpeaking: ${voiceProvider.isSpeaking}");
          debugPrint("- isListening: ${voiceProvider.isListening}");
          debugPrint("- TTS Service isSpeaking: ${_speechService.isSpeaking()}");
          
          // Cambiar el estado del botón automáticamente
          if (voiceProvider.isSpeaking) {
            debugPrint("Deteniendo modo speaking del botón automáticamente");
            voiceProvider.setIsSpeaking(false);
            
            // Auto-iniciar escucha después de un pequeño delay si no estamos en navegación
            if (!_navigationController.isNavigating && 
                !_navigationController.isWaitingForConfirmation && 
                !_userController.showNameInput) {
              
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && !voiceProvider.isListening && !voiceProvider.isSpeaking) {
                  debugPrint("Auto-iniciando escucha después del TTS");
                  voiceProvider.startListening();
                }
              });
            }
          }
        }
      });
    });
  }

  void _updateResponseText(String text) {
    if (mounted) {
      setState(() {
        _responseText = text;
      });
    }
  }

  void _setShowNameInput(bool show) {
    debugPrint("Show name input: $show");
  }

  void _onNavigationComplete() {
    debugPrint("Navegación completada - callback ejecutado");
  }

  void _initializeCompass() async {
    try {
      await _compassService.initialize();
      
      bool isAvailable = await _compassService.checkCompassAvailability();
      
      if (isAvailable) {
        debugPrint("Brújula inicializada correctamente");
      } else {
        debugPrint("Brújula no disponible en este dispositivo");
      }
    } catch (e) {
      debugPrint("Error al inicializar brújula: $e");
    }
  }

  void _setupVoiceListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
      voiceProvider.addListener(_onVoiceProviderChanged);
      
      if (voiceProvider.isButtonPressed && !_appInitialized) {
        setState(() {
          _appInitialized = true;
        });
        _userController.checkFirstTimeUser(voiceProvider);
      }
    });
  }

  void _onVoiceProviderChanged() {
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    
    // Procesar el texto cuando se detiene la escucha Y hay texto transcrito
    if (voiceProvider.transcribedText.isNotEmpty && 
        _appInitialized && 
        voiceProvider.transcribedText != _lastProcessedText &&
        !voiceProvider.isListening &&
        !voiceProvider.isSpeaking) {
      
      final text = voiceProvider.transcribedText;
      _lastProcessedText = text;

      _handleVoiceSubmit(text);
      voiceProvider.resetTranscription();
      _lastProcessedText = "";
    }
    
    if (voiceProvider.isButtonPressed && !_appInitialized) {
      setState(() {
        _appInitialized = true;
      });
      _userController.checkFirstTimeUser(voiceProvider);
    }
  }

  @override
  void dispose() {
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    voiceProvider.removeListener(_onVoiceProviderChanged);
    _navigationController.dispose();
    _compassService.dispose();
    super.dispose();
  }

  Future<void> _handleVoiceSubmit(String voiceText) async {
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);

    debugPrint("=== _handleVoiceSubmit llamado con: '$voiceText' ===");

    // Prioridad 1: Si se está solicitando nombre de usuario
    if (_userController.showNameInput) {
      await _userController.saveName(voiceText, voiceProvider, context);
      return;
    }

    // Prioridad 2: Si está esperando confirmación para iniciar navegación
    if (_navigationController.isWaitingForConfirmation) {
      _navigationController.handleConfirmationCommand(voiceText, voiceProvider);
      return;
    }

    // Prioridad 3: Si está navegando activamente (paso a paso)
    if (_navigationController.isNavigating) {
      _navigationController.handleNavigationCommand(voiceText, voiceProvider);
      return;
    }

    // Prioridad 4: Consulta general
    await _queryProcessor.processQuery(voiceText, voiceProvider, context);
  }
  
  @override
  Widget build(BuildContext context) {
    if (_showCamera) {
      return const CameraWidget();
    }

    return Consumer<VoiceProvider>(
      builder: (context, voiceProvider, child) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Área de respuesta del asistente
                Container(
                  height: 120,
                  width: double.infinity,
                  child: SingleChildScrollView(
                    child: Text(
                      _responseText,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      semanticsLabel: "Respuesta del asistente: $_responseText",
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Indicador de confirmación de navegación
                if (_navigationController.isWaitingForConfirmation) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.yellow.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.yellow.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "⏳ Esperando Confirmación",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Diga 'comenzar navegación' para iniciar",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                
                // Indicador de navegación activa
                if (_navigationController.isNavigating) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "🧭 Navegación Activa",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Paso ${_navigationController.currentStepIndex + 1} de ${_navigationController.navigationSteps.length}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (_navigationController.currentDirection.isNotEmpty && _compassService.isCompassAvailable()) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Dirección: ${_navigationController.currentDirection}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                
                // Área de estado de escucha
                Container(
                  height: 40,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: voiceProvider.isListening 
                        ? Colors.blue.withOpacity(0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: voiceProvider.isListening
                        ? Text(
                            voiceProvider.partialResults.isNotEmpty 
                                ? 'Escuchando: "${voiceProvider.partialResults[0]}"'
                                : 'Escuchando...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Indicador de reproducción de voz (con información adicional de debug)
                if (voiceProvider.isSpeaking)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "🔊 Reproduciendo respuesta...",
                          style: TextStyle(
                            color: Colors.orange,
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "TTS Service: ${_speechService.isSpeaking() ? 'Activo' : 'Inactivo'}",
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Botón para activar cámara (solo si no está en navegación o confirmación)
                const SizedBox(height: 16),
                
                if (!_navigationController.isNavigating && 
                    !_navigationController.isWaitingForConfirmation && 
                    !_userController.showNameInput)
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showCamera = true;
                      });
                    },
                    child: const Text("Usar Cámara"),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}