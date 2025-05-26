import 'package:flutter/material.dart';
import 'package:guide_upc_f/providers/voice_provider.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';

class MainButton extends StatelessWidget {
  const MainButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, voiceProvider, child) {
        String currentText = _getCurrentText(voiceProvider);
        
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _handleVoiceButton(context, voiceProvider),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _getBorderColor(voiceProvider),
                    width: 3,
                  ),
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/eye.png',
                      height: 120,
                      width: 120,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getCurrentText(VoiceProvider voiceProvider) {
    if (!voiceProvider.isButtonPressed) {
      return 'Presiona para iniciar';
    } else if (voiceProvider.isListening && 
               voiceProvider.partialResults.isNotEmpty && 
               voiceProvider.partialResults[0].trim().isNotEmpty) {
      return '"${voiceProvider.partialResults[0]}"';
    } else if (voiceProvider.isListening) {
      return 'Escuchando...';
    } else if (voiceProvider.isSpeaking) {
      return 'Hablando...';
    } else {
      return 'Presiona para hablar';
    }
  }

  Color _getBorderColor(VoiceProvider voiceProvider) {
    if (!voiceProvider.isButtonPressed) {
      return Colors.purple;
    } else if (voiceProvider.isSpeaking) {
      return Colors.red;
    } else if (voiceProvider.isListening) {
      return Colors.blue;
    } else {
      return Colors.green;
    }
  }

  Future<void> _handleVoiceButton(BuildContext context, VoiceProvider voiceProvider) async {
    // Vibrate for tactile feedback
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }

    // If button has never been pressed, initialize the app
    if (!voiceProvider.isButtonPressed) {
      voiceProvider.setIsButtonPressed(true);
      return;
    }

    // If the system is speaking, stop it
    if (voiceProvider.isSpeaking) {
      await voiceProvider.stopSpeaking();
      return;
    }

    // If we're listening, stop listening and process
    if (voiceProvider.isListening) {
      await voiceProvider.stopListening();
      return;
    }

    // Check if voice recognition is available
    if (!voiceProvider.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El reconocimiento de voz no está disponible en este dispositivo.'),
        ),
      );
      return;
    }

    // If not listening or speaking, start listening
    try {
      final started = await voiceProvider.startListening();
      if (!started) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo iniciar el reconocimiento de voz.'),
          ),
        );
      }
    } catch (error) {
      debugPrint("Error al iniciar reconocimiento de voz: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al iniciar el reconocimiento de voz. Inténtalo de nuevo.'),
        ),
      );
    }
  }
}
