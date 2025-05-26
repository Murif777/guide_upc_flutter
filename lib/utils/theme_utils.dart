import 'package:flutter/material.dart';

class ThemeUtils {
  // Define the Colors object
  static const lightColors = {
    'text': Color(0xFF11181C),
    'background': Color(0xFFFFFFFF),
  };

  static const darkColors = {
    'text': Color(0xFFFFFFFF),
    'background': Color(0xFF151718),
  };

  // Get colors based on brightness
  static Map<String, Color> getColors(Brightness brightness) {
    return brightness == Brightness.light ? lightColors : darkColors;
  }

  // Get text color based on brightness
  static Color getTextColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return getColors(brightness)['text']!;
  }

  // Get background color based on brightness
  static Color getBackgroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return getColors(brightness)['background']!;
  }
}
