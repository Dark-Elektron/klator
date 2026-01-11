import 'package:flutter/material.dart';

class AppColors {
  final Color displayBackground;
  final Color containerBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;
  final Color accent;
  final Color keypadBackground;
  final Color keypadButton;
  final Color keypadButtonText;
  final String backgroundImage; // Add this

  const AppColors({
    required this.displayBackground,
    required this.containerBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.accent,
    required this.keypadBackground,
    required this.keypadButton,
    required this.keypadButtonText,
    required this.backgroundImage, // Add this
  });

  // Light theme colors
  static const light = AppColors(
    displayBackground: Colors.white38,
    containerBackground: Colors.blueGrey,
    textPrimary: Colors.white,
    textSecondary: Colors.grey,
    textTertiary: Colors.orangeAccent,
    divider: Colors.grey,
    accent: Colors.yellow,
    keypadBackground: Color(0xFFE0E0E0),
    keypadButton: Colors.white,
    keypadButtonText: Colors.black,
    backgroundImage: 'assets/imgs/background_light.svg',
  );

  // Dark theme colors
  static const dark = AppColors(
    displayBackground: Colors.black,
    containerBackground: Color.fromARGB(255, 57, 57, 57),
    textPrimary: Colors.white,
    textSecondary: Color(0xFF9E9E9E),
    textTertiary: Colors.orangeAccent,
    divider: Color(0xFF616161),
    accent: Colors.yellowAccent,
    keypadBackground: Color(0xFF121212),
    keypadButton: Color(0xFF2C2C2C),
    keypadButtonText: Colors.white,
    backgroundImage: 'assets/imgs/background_dark.svg',
  );

  // Helper to get colors based on context
  static AppColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? dark : light;
  }
}
