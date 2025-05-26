import 'package:flutter/material.dart';
import 'package:guide_upc_f/widgets/main_button.dart';
import 'package:guide_upc_f/widgets/main_speech.dart';
import 'package:guide_upc_f/widgets/animation_voice.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Text container at the top
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.only(top: 50.0),
                  child: MainSpeech(),
                ),
              ),
              
              // Animation in the middle
              Expanded(
                flex: 3,
                child: AnimationVoice(),
              ),
              
              // Button at the bottom
              Expanded(
                flex: 2,
                child: MainButton(),
              ),
              
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
