import 'package:flutter/material.dart';

class AppColors {
  // Light palette: The Airy Sanctuary
  static const Color lightBackground = Color(0xFFFAFAF5);
  static const Color lightSurface = Color(0xFFFAFAF5);
  static const Color lightSurfaceContainerLow = Color(0xFFF3F4EE);
  static const Color lightSurfaceContainer = Color(0xFFECEFE7);
  static const Color lightSurfaceContainerHigh = Color(0xFFE5EAE0);
  static const Color lightSurfaceContainerHighest = Color(0xFFDEE4DA);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);

  static const Color lightOnBackground = Color(0xFF2E342D);
  static const Color lightOnSurface = Color(0xFF2E342D);
  static const Color lightOnSurfaceVariant = Color(0xFF5A6159);

  // Dark palette: The Sophisticated Guardian
  static const Color darkBackground = Color(0xFF0F1413);
  static const Color darkSurface = Color(0xFF0F1413);
  static const Color darkSurfaceContainerLow = Color(0xFF151D1B);
  static const Color darkSurfaceContainer = Color(0xFF1B2421);
  static const Color darkSurfaceContainerHigh = Color(0xFF24302C);
  static const Color darkSurfaceContainerHighest = Color(0xFF2E3B36);
  static const Color darkSurfaceContainerLowest = Color(0xFF0A0F0E);

  static const Color darkOnBackground = Color(0xFFE6ECE8);
  static const Color darkOnSurface = Color(0xFFE6ECE8);
  static const Color darkOnSurfaceVariant = Color(0xFFC2C8C5);

  // Semantic brand tones
  static const Color primary = Color(0xFF51634E);
  static const Color primaryDim = Color(0xFF465742);
  static const Color onPrimary = Color(0xFFE9FEE2);

  static const Color secondary = Color(0xFF6F8680);
  static const Color secondaryContainer = Color(0xFFD9E5E4);
  static const Color onSecondaryContainer = Color(0xFF495454);

  static const Color tertiary = Color(0xFF6C7A74);
  static const Color tertiaryContainer = Color(0xFFD6F3D6);
  static const Color onTertiaryContainer = Color(0xFF445D47);

  static const Color error = Color(0xFFB25E66);
  static const Color success = Color(0xFF5D8A65);

  // Utility tones
  static const Color outlineVariant = Color(0xFFADB4AA);
  static const Color ambientShadow = Color(0x0F2E342D);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDim],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkSilkGradient = LinearGradient(
    colors: [Color(0xFF4A5D57), Color(0xFF24302C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
