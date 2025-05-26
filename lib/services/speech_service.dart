import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SpeechService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  SpeechService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('es-ES');
    await _flutterTts.setPitch(1.0);
    
    // Adjust rate based on platform - Usando setSpeechRate en lugar de setRate
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _flutterTts.setSpeechRate(0.55);
    } else {
      await _flutterTts.setSpeechRate(0.5);
    }

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });
  }

  Future<void> speakText(String text, [Function? onDone]) async {
    if (text.isEmpty) return;

    // Stop any previous speech
    await stopSpeaking();
    
    _isSpeaking = true;
    
    try {
      await _flutterTts.speak(text);
      
      // Wait for speech to complete
      while (_isSpeaking) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      if (onDone != null) {
        onDone();
      }
    } catch (e) {
      debugPrint('Error in speech synthesis: $e');
      _isSpeaking = false;
      if (onDone != null) {
        onDone();
      }
    }
  }

  Future<void> speakError(String text, [Function? onDone]) async {
    if (text.isEmpty) return;

    // Stop any previous speech
    await stopSpeaking();
    
    _isSpeaking = true;
    
    try {
      await _flutterTts.setPitch(1.1); // Slightly higher pitch for error
      await _flutterTts.speak(text);
      await _flutterTts.setPitch(1.0); // Reset pitch
      
      // Wait for speech to complete
      while (_isSpeaking) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      if (onDone != null) {
        onDone();
      }
    } catch (e) {
      debugPrint('Error in speech synthesis (error): $e');
      _isSpeaking = false;
      if (onDone != null) {
        onDone();
      }
    }
  }

  bool isSpeaking() {
    return _isSpeaking;
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }
}