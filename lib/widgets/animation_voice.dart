import 'package:flutter/material.dart';
import 'package:guide_upc_f/providers/voice_provider.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

class AnimationVoice extends StatefulWidget {
  const AnimationVoice({super.key});

  @override
  State<AnimationVoice> createState() => _AnimationVoiceState();
}

class _AnimationVoiceState extends State<AnimationVoice>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final List<AnimationController> _barControllers;
  late final List<Animation<double>> _barAnimations;
  bool _wasPlayingBefore = false;

  final List<double> _baseSizes = [14, 6, 12, 8, 10, 14]; // Tamaños base de las barras
  final Color _barColor = const Color(0xFF16A54E);

  @override
  void initState() {
    super.initState();
    
    // Controlador principal
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Controladores individuales para cada barra
    _barControllers = List.generate(6, (index) => 
      AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + (index * 100)), // Duraciones variables
      )
    );

    // Animaciones para cada barra con diferentes curvas
    _barAnimations = _barControllers.asMap().entries.map((entry) {
      int index = entry.key;
      AnimationController controller = entry.value;
      
      return Tween<double>(
        begin: 0.3, // Altura mínima
        end: 1.0,   // Altura máxima
      ).animate(CurvedAnimation(
        parent: controller,
        curve: _getCurveForBar(index),
      ));
    }).toList();
  }

  Curve _getCurveForBar(int index) {
    final curves = [
      Curves.easeInOut,
      Curves.bounceInOut,
      Curves.elasticInOut,
      Curves.easeInOutCubic,
      Curves.fastOutSlowIn,
      Curves.easeInOutBack,
    ];
    return curves[index % curves.length];
  }

  void _handleAnimationState(bool isSpeaking) {
    if (isSpeaking && !_wasPlayingBefore) {
      // Iniciar todas las animaciones con pequeños delays
      for (int i = 0; i < _barControllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 50), () {
          if (mounted && isSpeaking) {
            _barControllers[i].repeat(reverse: true);
          }
        });
      }
      _animationController.forward();
      _wasPlayingBefore = true;
    } else if (!isSpeaking && _wasPlayingBefore) {
      // Detener todas las animaciones
      for (var controller in _barControllers) {
        controller.animateTo(0.3);
      }
      _animationController.reverse();
      _wasPlayingBefore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, voiceProvider, child) {
        _handleAnimationState(voiceProvider.isSpeaking);

        return Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: voiceProvider.isSpeaking 
                ? _barColor.withOpacity(0.1) 
                : Colors.grey.withOpacity(0.05),
              border: Border.all(
                color: voiceProvider.isSpeaking 
                  ? _barColor.withOpacity(0.3) 
                  : Colors.grey.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Barras de audio animadas
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(6, (index) {
                      return AnimatedBuilder(
                        animation: _barAnimations[index],
                        builder: (context, child) {
                          final baseHeight = _baseSizes[index];
                          final animatedHeight = baseHeight * _barAnimations[index].value;
                          
                          // FIX: Clamp el valor de opacidad entre 0.0 y 1.0
                          final opacityValue = voiceProvider.isSpeaking 
                            ? (0.8 + 0.2 * _barAnimations[index].value).clamp(0.0, 1.0)
                            : 0.3;
                          
                          return Container(
                            width: 4,
                            height: animatedHeight * 2, // Multiplicamos para mayor visibilidad
                            decoration: BoxDecoration(
                              color: voiceProvider.isSpeaking 
                                ? _barColor.withOpacity(opacityValue)
                                : _barColor.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: voiceProvider.isSpeaking ? [
                                BoxShadow(
                                  color: _barColor.withOpacity(0.3),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ] : null,
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ),
                
                // Indicador central cuando no está hablando
                if (!voiceProvider.isSpeaking)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                    ),
                    child: Icon(
                      Icons.mic_off,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ),
                
                // Efecto de pulso cuando está hablando
                if (voiceProvider.isSpeaking)
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      // FIX: También aplicar clamp aquí por seguridad
                      final pulseOpacity = (0.3 * (1 - _animationController.value)).clamp(0.0, 1.0);
                      
                      return Container(
                        width: 120 + (20 * _animationController.value),
                        height: 120 + (20 * _animationController.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _barColor.withOpacity(pulseOpacity),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  ),
                
                // Texto indicativo
                Positioned(
                  bottom: -30,
                  child: Text(
                    voiceProvider.isSpeaking ? 'Escuchando...' : 'Toca para hablar',
                    style: TextStyle(
                      color: voiceProvider.isSpeaking ? _barColor : Colors.grey[600],
                      fontSize: 12,
                      fontWeight: voiceProvider.isSpeaking ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _barControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}