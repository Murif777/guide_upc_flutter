// controllers/user_controller.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guide_upc_f/services/speech_service.dart';
import 'package:guide_upc_f/services/user_service.dart';
import 'package:guide_upc_f/providers/voice_provider.dart';

class UserController {
  final SpeechService _speechService;
  final UserService _userService;
  final Function(String)? onStateUpdate;
  final Function(bool)? onShowNameInput;

  String _userName = "";
  bool _showNameInput = false;

  UserController({
    required SpeechService speechService,
    required UserService userService,
    this.onStateUpdate,
    this.onShowNameInput,
  }) : _speechService = speechService,
       _userService = userService;

  // Getters
  String get userName => _userName;
  bool get showNameInput => _showNameInput;

  Future<void> checkFirstTimeUser(VoiceProvider voiceProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedName = prefs.getString('userName');

      if (storedName != null) {
        _userName = storedName;
        String welcomeText =
            "Bienvenido $_userName. ¿Qué te gustaría hacer hoy?";
        onStateUpdate?.call(welcomeText);
        _speakWithStateTracking(welcomeText, voiceProvider);
      } else {
        _showNameInput = true;
        onShowNameInput?.call(true);
        String welcomeText = "Bienvenido a guide UPC. ¿Cuál es tu nombre?";
        onStateUpdate?.call(welcomeText);
        _speakWithStateTracking(welcomeText, voiceProvider);
      }
    } catch (error) {
      debugPrint("Error al verificar el usuario: $error");
      String defaultText = "Bienvenido a guide UPC";
      onStateUpdate?.call(defaultText);
      _speakWithStateTracking(defaultText, voiceProvider);
    }
  }

  Future<void> saveName(
    String nameToSave,
    VoiceProvider voiceProvider,
    BuildContext context,
  ) async {
    if (nameToSave.trim().isEmpty) {
      const errorMsg = "Campo vacío. Por favor ingresa tu nombre.";
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor ingresa tu nombre")),
      );
      _speakWithStateTracking(errorMsg, voiceProvider);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', nameToSave.trim());

      _userName = nameToSave.trim();
      _showNameInput = false;
      onShowNameInput?.call(false);

      String welcomeText =
          "Hola $_userName, bienvenido a guide UPC, una aplicacion en la que podras: "
          "Pedir descripciones de lugares, Buscar la ruta mas optima a tu destino señalando lugar de origen y destino, "
          "pedir ayuda a una persona si lo necesitas, entre otras cosas. ¿Qué gustaría hacer hoy?";

      onStateUpdate?.call(welcomeText);
      _speakWithStateTracking(welcomeText, voiceProvider);
      voiceProvider.setInputText("");
    } catch (error) {
      debugPrint("Error al guardar el nombre: $error");
      const errorMsg = "No se pudo guardar tu nombre";
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(errorMsg)));
      _speakWithStateTracking(errorMsg, voiceProvider);
    }
  }

  void promptForNameChange(VoiceProvider voiceProvider) {
    _showNameInput = true;
    onShowNameInput?.call(true);
    String changeNameText = "Por favor, dime tu nuevo nombre";
    onStateUpdate?.call(changeNameText);
    _speakWithStateTracking(changeNameText, voiceProvider);
    voiceProvider.resetTranscription();
  }

  Future<void> requestHelp(VoiceProvider voiceProvider) async {
    const helpText =
        "No te preocupes y mantén la calma, la ayuda está en camino a tu ubicación.";
    _speakWithStateTracking(helpText, voiceProvider);

    try {
      // Obtener ubicación actual
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Permisos de ubicación denegados');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Permisos de ubicación denegados permanentemente');
        return;
      }

      // Obtener posición actual
      final Position position = await Geolocator.getCurrentPosition();
      final String googleMapsLink =
          'https://www.google.com/maps?q=${position.latitude},${position.longitude}';

      // Enviar notificación directamente usando sendTelegramNotification
      await _userService.sendTelegramNotification(googleMapsLink);
      debugPrint("Solicitud de ayuda enviada correctamente");
    } catch (e) {
      debugPrint("Error al enviar solicitud de ayuda: $e");
    }
  }

  bool handleSpecialQueries(String query, VoiceProvider voiceProvider) {
    final lowerCaseQuery = query.toLowerCase();

    if (lowerCaseQuery.contains("ayuda") ||
        lowerCaseQuery.contains("socorro") ||
        lowerCaseQuery.contains("emergencia")) {
      requestHelp(voiceProvider);
      return true;
    }

    const changeNamePatterns = [
      "cambiar nombre",
      "cambiar mi nombre",
      "quiero cambiar mi nombre",
      "modifica mi nombre",
      "actualiza mi nombre",
    ];

    final shouldChangeName = changeNamePatterns.any(
      (pattern) => lowerCaseQuery.contains(pattern),
    );

    if (shouldChangeName) {
      promptForNameChange(voiceProvider);
      return true;
    }

    return false;
  }

  void _speakWithStateTracking(String text, VoiceProvider voiceProvider) {
    debugPrint("=== _speakWithStateTracking iniciado ===");
    voiceProvider.setIsSpeaking(true);

    _speechService.speakText(text, () {
      debugPrint(
        "Callback específico ejecutado, estableciendo isSpeaking a false",
      );
      voiceProvider.setIsSpeaking(false);
    });
  }
}
