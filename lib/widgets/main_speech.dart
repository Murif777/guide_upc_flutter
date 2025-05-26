import 'package:flutter/material.dart';
import 'package:guide_upc_f/providers/voice_provider.dart';
import 'package:guide_upc_f/services/assistant_service.dart';
import 'package:guide_upc_f/services/speech_service.dart';
import 'package:guide_upc_f/services/user_service.dart';
import 'package:guide_upc_f/widgets/camera_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainSpeech extends StatefulWidget {
  const MainSpeech({super.key});

  @override
  State<MainSpeech> createState() => _MainSpeechState();
}

class _MainSpeechState extends State<MainSpeech> {
  final AssistantService _assistantService = AssistantService();
  final SpeechService _speechService = SpeechService();
  final UserService _userService = UserService();
  
  String _responseText = "Presiona el botón para iniciar";
  String _userName = "";
  bool _showNameInput = false;
  bool _showCamera = false;
  bool _appInitialized = false;
  String _lastProcessedText = ""; // Para evitar procesar el mismo texto múltiples veces

  @override
  void initState() {
    super.initState();
    _setupVoiceListener();
  }

  void _setupVoiceListener() {
    // Add post-frame callback to access the provider after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
      
      // Add listener for continuous monitoring
      voiceProvider.addListener(_onVoiceProviderChanged);
      
      // Check if button has been pressed to initialize the app
      if (voiceProvider.isButtonPressed && !_appInitialized) {
        setState(() {
          _appInitialized = true;
        });
        _checkFirstTimeUser();
      }
    });
  }

  void _onVoiceProviderChanged() {
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    
    // Check if we have new transcribed text, app is initialized, and we just stopped listening
    if (voiceProvider.transcribedText.isNotEmpty && 
        _appInitialized && 
        voiceProvider.transcribedText != _lastProcessedText &&
        !voiceProvider.isListening && // Only process when not actively listening
        !voiceProvider.isSpeaking) { // Don't process while the assistant is speaking
      
      final text = voiceProvider.transcribedText;
      _lastProcessedText = text; // Remember this text to avoid reprocessing
      

      
      // Small delay for better UX, then process automatically
      Future.delayed(const Duration(milliseconds: 300), () {
        _handleVoiceSubmit(text);
        voiceProvider.resetTranscription();
        _lastProcessedText = ""; // Reset after processing
      });
    }
    
    // Check if button was just pressed to initialize
    if (voiceProvider.isButtonPressed && !_appInitialized) {
      setState(() {
        _appInitialized = true;
      });
      _checkFirstTimeUser();
    }
  }

  @override
  void dispose() {
    // Remove the listener to prevent memory leaks
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    voiceProvider.removeListener(_onVoiceProviderChanged);
    super.dispose();
  }

  Future<void> _checkFirstTimeUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedName = prefs.getString('userName');
      
      if (storedName != null) {
        // Not first time, give personalized welcome
        setState(() {
          _userName = storedName;
          _responseText = "Bienvenido $_userName. ¿Qué te gustaría hacer hoy?";
        });
        _speakWithStateTracking(_responseText);
      } else {
        // First time, ask for name
        setState(() {
          _showNameInput = true;
          _responseText = "Bienvenido a guide UPC. ¿Cuál es tu nombre?";
        });
        _speakWithStateTracking(_responseText);
      }
    } catch (error) {
      debugPrint("Error al verificar el usuario: $error");
      setState(() {
        _responseText = "Bienvenido a guide UPC";
      });
      _speakWithStateTracking(_responseText);
    }
  }

  void _speakWithStateTracking(String text) {
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    voiceProvider.setIsSpeaking(true);
    
    _speechService.speakText(text, () {
      voiceProvider.setIsSpeaking(false);
    });
  }

  Future<void> _saveName(String nameToSave) async {
    if (nameToSave.trim().isEmpty) {
      const errorMsg = "Campo vacío. Por favor ingresa tu nombre.";
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor ingresa tu nombre")),
      );
      _speakWithStateTracking(errorMsg);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', nameToSave.trim());
      
      setState(() {
        _userName = nameToSave.trim();
        _showNameInput = false;
        _responseText = "Hola $_userName, bienvenido a guide UPC, una aplicacion en la que podras: "
            "Pedir descripciones de lugares, Buscar la ruta mas optima a tu destino señalando lugar de origen y destino, "
            "pedir ayuda a una persona si lo necesitas, entre otras cosas. ¿Qué gustaría hacer hoy?";
      });
      
      _speakWithStateTracking(_responseText);
      Provider.of<VoiceProvider>(context, listen: false).setInputText("");
    } catch (error) {
      debugPrint("Error al guardar el nombre: $error");
      const errorMsg = "No se pudo guardar tu nombre";
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(errorMsg)),
      );
      _speakWithStateTracking(errorMsg);
    }
  }



  Future<void> _handleVoiceSubmit(String voiceText) async {
    // Si estamos pidiendo el nombre, guardar el nombre
    if (_showNameInput) {
      await _saveName(voiceText);
      return;
    }

    // Si no estamos pidiendo el nombre, procesar como consulta normal
    await _processQuery(voiceText);
  }

  String _checkForKeywords(String response) {
    const keywords = ["}"];
    final lowerCaseResponse = response.toLowerCase();

    // Check if any keyword is in the response
    final containsKeyword = keywords.any((keyword) => lowerCaseResponse.contains(keyword));

    if (containsKeyword) {
      return "$response Para una mejor navegación por el campus, busca un punto de referencia y di la frase \"Usar cámara\".";
    }

    return response;
  }

  bool _handleSpecialQueries(String query) {
    final lowerCaseQuery = query.toLowerCase();
    
    if (lowerCaseQuery.contains("usar cámara")) {
      _openCamera();
      return true;
    }

    if (lowerCaseQuery.contains("ayuda")) {
      _pedirAyuda();
      return true;
    }

    // New functionality: Change name
    const changeNamePatterns = [
      "cambiar nombre", 
      "cambiar mi nombre", 
      "quiero cambiar mi nombre", 
      "modifica mi nombre", 
      "actualiza mi nombre"
    ];
    
    final shouldChangeName = changeNamePatterns.any((pattern) => lowerCaseQuery.contains(pattern));
    
    if (shouldChangeName) {
      _promptForNameChange();
      return true;
    }

    return false;
  }

  void _promptForNameChange() {
    setState(() {
      _showNameInput = true;
      _responseText = "Por favor, dime tu nuevo nombre";
    });
    
    _speakWithStateTracking(_responseText);
    
    // Clear previous transcription to avoid interference
    Provider.of<VoiceProvider>(context, listen: false).resetTranscription();
  }

  void _pedirAyuda() {
    _speakWithStateTracking("No te preocupes y manten la calma, la ayuda está en camino a tu ubicación.");
    _userService.sendLocationHelp();
  }

  Future<void> _processQuery(String query) async {
    if (query.trim().isEmpty) {
      const emptyMsg = "Por favor ingresa tu consulta";
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(emptyMsg)),
      );
      _speakWithStateTracking(emptyMsg);
      return;
    }

    // Check if the query contains special phrases
    final handled = _handleSpecialQueries(query);
    if (handled) {
      return;
    }

    setState(() {
      _responseText = "Procesando...";
    });

    try {
      final response = await _assistantService.enviarConsulta(query);

      // Check keywords and modify the response if necessary
      final modifiedResponse = _checkForKeywords(response);

      setState(() {
        _responseText = modifiedResponse;
      });

      // Speak the response and update the state
      _speakWithStateTracking(modifiedResponse);

      // Clear the provider after sending
      Provider.of<VoiceProvider>(context, listen: false).setInputText("");
    } catch (error) {
      debugPrint("Error en la consulta: $error");
      const errorMessage = "Error al procesar la consulta.";
      setState(() {
        _responseText = errorMessage;
      });
      _speakWithStateTracking(errorMessage);
    }
  }

  void _openCamera() {
    setState(() {
      _responseText = "Abriendo la cámara...";
      _showCamera = true;
    });
    _speakWithStateTracking("Abriendo la cámara...");
  }

  @override
  Widget build(BuildContext context) {
    // Conditional rendering
    if (_showCamera) {
      return const CameraWidget();
    }

    return Consumer<VoiceProvider>(
      builder: (context, voiceProvider, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _responseText,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                semanticsLabel: "Respuesta del asistente: $_responseText",
              ),
              
              const SizedBox(height: 16),
              
              voiceProvider.isListening
                  ? Container(
                      height: 40,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          voiceProvider.partialResults.isNotEmpty 
                              ? 'Escuchando: "${voiceProvider.partialResults[0]}"'
                              : 'Escuchando...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(height: 40),
              
              const SizedBox(height: 16),
              
              if (voiceProvider.isSpeaking)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Procesando consulta...",
                    style: TextStyle(
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}