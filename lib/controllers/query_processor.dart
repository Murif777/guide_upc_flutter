// controllers/query_processor.dart
import 'package:flutter/material.dart';
import 'package:guide_upc_f/services/assistant_service.dart';
import 'package:guide_upc_f/services/speech_service.dart';
import 'package:guide_upc_f/providers/voice_provider.dart';
import 'package:guide_upc_f/controllers/navigation_controller.dart';
import 'package:guide_upc_f/controllers/user_controller.dart';

class QueryProcessor {
  final AssistantService _assistantService;
  final SpeechService _speechService;
  final NavigationController _navigationController;
  final UserController _userController;
  final Function(String)? onStateUpdate;
  
  QueryProcessor({
    required AssistantService assistantService,
    required SpeechService speechService,
    required NavigationController navigationController,
    required UserController userController,
    this.onStateUpdate,
  }) : _assistantService = assistantService,
       _speechService = speechService,
       _navigationController = navigationController,
       _userController = userController;

  Future<void> processQuery(String query, VoiceProvider voiceProvider, BuildContext context) async {
    if (query.trim().isEmpty) {
      const emptyMsg = "Por favor ingresa tu consulta";
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(emptyMsg)),
      );
      _speakWithStateTracking(emptyMsg, voiceProvider);
      return;
    }

    // Verificar si es una consulta especial (ayuda, cambio de nombre, etc.)
    final handled = _userController.handleSpecialQueries(query, voiceProvider);
    if (handled) {
      return;
    }

    onStateUpdate?.call("Procesando...");

    try {
      final response = await _assistantService.enviarConsulta(query);
      debugPrint("Respuesta recibida: $response");
      
      List<String> navigationSteps = _navigationController.extractNavigationSteps(response);
      
      if (navigationSteps.isNotEmpty) {
        await _handleNavigationResponse(navigationSteps, voiceProvider);
      } else {
        await _handleRegularResponse(response, voiceProvider);
      }

      voiceProvider.setInputText("");
    } catch (error) {
      debugPrint("Error en la consulta: $error");
      const errorMessage = "Error al procesar la consulta.";
      onStateUpdate?.call(errorMessage);
      _speakWithStateTracking(errorMessage, voiceProvider);
    }
  }

  Future<void> _handleNavigationResponse(List<String> navigationSteps, VoiceProvider voiceProvider) async {
    debugPrint("=== _handleNavigationResponse llamado ===");
    debugPrint("Pasos encontrados: ${navigationSteps.length}");
    
    // Solicitar confirmación antes de iniciar navegación
    _navigationController.requestNavigationConfirmation(navigationSteps, voiceProvider);
  }

  Future<void> _handleRegularResponse(String response, VoiceProvider voiceProvider) async {
    final modifiedResponse = _checkForKeywords(response);
    onStateUpdate?.call(modifiedResponse);
    _speakWithStateTracking(modifiedResponse, voiceProvider);
  }

  String _checkForKeywords(String response) {
    const keywords = ["}"];
    final lowerCaseResponse = response.toLowerCase();

    final containsKeyword = keywords.any((keyword) => lowerCaseResponse.contains(keyword));

    if (containsKeyword) {
      return "$response Para una mejor navegación por el campus, busca un punto de referencia y di la frase \"Usar cámara\".";
    }

    return response;
  }

  void _speakWithStateTracking(String text, VoiceProvider voiceProvider) {
    voiceProvider.setIsSpeaking(true);
    
    _speechService.speakText(text, () {
      voiceProvider.setIsSpeaking(false);
    });
  }
}