import 'package:flutter/material.dart';

/// Brand palette shared by light and dark themes.
abstract final class AppColors {
  static const primary = Color.fromARGB(255, 108, 58, 235);
  static const blue = Color(0xFF007BFF);
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);
  static const gray = Color(0xFF3B3B3B);
  static const lightGray = Color(0xFFF5F5F5);
  static const mediumGray = Color(0xFF9E9E9E);
  static const statusBarBg = Color(0xFFFAFAFA);

  // Light surfaces
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color.fromARGB(255, 241, 241, 241);
  static const lightHighlightSurface = Color(0xFFE1F4FE);
  static const lightBorder = Color(0xFFE5E5E5);
  static const lightTextPrimary = Color(0xFF1A1A1A);
  static const lightTextSecondary = Color(0xFF6B6B6B);

  // Dark surfaces
  static const darkBackground = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
  static const darkBorder = Color(0xFF2C2C2C);
  static const darkTextPrimary = Color(0xFFF5F5F5);
  static const darkTextSecondary = Color(0xFFB0B0B0);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? darkBackground : lightBackground;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? darkSurface : lightSurface;

  static Color borderOf(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? darkTextPrimary : lightTextPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color chipTagBgOf(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.10)
      : const Color(0xFFF0F0F0);
}
