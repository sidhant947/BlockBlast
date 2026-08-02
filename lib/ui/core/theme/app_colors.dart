import 'package:flutter/material.dart';

class AppColors {
  static const Color bg = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color buttonBg = Color(0xFF000000);
  static const Color buttonText = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFFFFFFFF);
  static const Color headingDark = Color(0xFFFFFFFF);
  static const Color subtext = Color(0xFFA0A0A0);
  static const Color gridLines = Color(0xFF262626);

  static const List<Color> blockColors = [
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF00C7BE),
    Color(0xFF30B0C7),
    Color(0xFF007AFF),
    Color(0xFFAF52DE),
  ];
}

class AppTheme {
  static ThemeData get dark => ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'BebasNeue',
            ),
      );
}
