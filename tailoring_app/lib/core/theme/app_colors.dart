import 'package:flutter/material.dart';

/// Centralised brand palette.
/// Primary: Deep Teal (#006D6D)
/// Accent: Gold (#C9A84C)
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF1E293B);
  static const Color primaryDark = Color(0xFF0F172A);
  static const Color primaryLight = Color(0xFF475569);
  static const Color accent = Color(0xFF64748B);
  static const Color accentDark = Color(0xFF475569);

  // Neutrals (Light)
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF1F3F5);
  static const Color border = Color(0xFFE3E6EA);
  static const Color textPrimary = Color(0xFF1A1F26);
  static const Color textSecondary = Color(0xFF5B6470);
  static const Color textMuted = Color(0xFF8A95A3);

  // Neutrals (Dark)
  static const Color darkBackground = Color(0xFF0E1316);
  static const Color darkSurface = Color(0xFF161C20);
  static const Color darkSurfaceAlt = Color(0xFF1E262B);
  static const Color darkBorder = Color(0xFF2A343A);
  static const Color darkTextPrimary = Color(0xFFF1F3F5);
  static const Color darkTextSecondary = Color(0xFFB5BDC7);

  // Status colours
  static const Color statusPending = Color(0xFFE0A800);
  static const Color statusInProgress = Color(0xFF1E78D6);
  static const Color statusCompleted = Color(0xFF2E9B5C);
  static const Color statusCancelled = Color(0xFFD23B3B);

  // Feedback
  static const Color success = Color(0xFF2E9B5C);
  static const Color warning = Color(0xFFE0A800);
  static const Color error = Color(0xFFD23B3B);
  static const Color info = Color(0xFF1E78D6);
}
