import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SpeechService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  Function? _currentCallback;
  Function? _onTtsComplete;

  SpeechService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('es-ES');
    await _flutterTts.setPitch(1.0);
    
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _flutterTts.setSpeechRate(0.55);
    } else {
      await _flutterTts.setSpeechRate(0.5);
    }

    // MEJORADO: Configurar el completion handler
    _flutterTts.setCompletionHandler(() {
      debugPrint("=== TTS Completion Handler ejecutado ===");
      _isSpeaking = false;
      
      // Ejecutar callback específico primero
      if (_currentCallback != null) {
        debugPrint("Ejecutando callback específico");
        final callback = _currentCallback;
        _currentCallback = null;
        
        // Ejecutar en el siguiente frame para evitar problemas de sincronización
        Future.microtask(() => callback!());
      }
      
      // IMPORTANTE: Notificar que TTS terminó (para cambiar modo del botón)
      if (_onTtsComplete != null) {
        debugPrint("Ejecutando callback de finalización global");
        
        // Ejecutar en el siguiente frame para asegurar que todos los estados se actualicen
        Future.microtask(() => _onTtsComplete!());
      }
    });

    _flutterTts.setStartHandler(() {
      debugPrint("=== TTS Start Handler ejecutado ===");
      _isSpeaking = true;
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint("=== TTS Error Handler: $msg ===");
      _isSpeaking = false;
      
      if (_currentCallback != null) {
        debugPrint("Ejecutando callback por error");
        final callback = _currentCallback;
        _currentCallback = null;
        Future.microtask(() => callback!());
      }
      
      // También notificar finalización por error
      if (_onTtsComplete != null) {
        debugPrint("Ejecutando callback global por error");
        Future.microtask(() => _onTtsComplete!());
      }
    });
  }

  void setTtsCompleteCallback(Function callback) {
    _onTtsComplete = callback;
    debugPrint("Callback de finalización de TTS configurado");
  }

  Future<void> speakText(String text, [Function? onDone]) async {
    if (text.isEmpty) return;

    debugPrint("=== SpeechService.speakText iniciado ===");
    debugPrint("Texto: $text");
    debugPrint("Tiene callback específico: ${onDone != null}");

    // Detener cualquier reproducción anterior
    await stopSpeaking();
    
    // Configurar el callback específico antes de empezar a hablar
    _currentCallback = onDone;
    _isSpeaking = true;
    
    try {
      debugPrint("Iniciando TTS speak...");
      await _flutterTts.speak(text);
      debugPrint("TTS speak() ejecutado, esperando handlers...");
    } catch (e) {
      debugPrint('Error en síntesis de voz: $e');
      _isSpeaking = false;
      
      if (_currentCallback != null) {
        final callback = _currentCallback;
        _currentCallback = null;
        Future.microtask(() => callback!());
      }
      
      if (_onTtsComplete != null) {
        Future.microtask(() => _onTtsComplete!());
      }
    }
  }

  bool isSpeaking() {
    return _isSpeaking;
  }

  Future<void> stopSpeaking() async {
    debugPrint("=== Deteniendo TTS ===");
    _currentCallback = null;
    await _flutterTts.stop();
    _isSpeaking = false;
  }
}