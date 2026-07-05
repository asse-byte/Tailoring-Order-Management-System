import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tiny BuildContext extension so the rest of the app can grab the right
/// neutral colour without sprinkling Theme.of(context).brightness checks.
extension AppContextX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get cSurface => isDark ? AppColors.darkSurface : AppColors.surface;
  Color get cSurfaceAlt =>
      isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;
  Color get cBorder => isDark ? AppColors.darkBorder : AppColors.border;
  Color get cTextPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get cTextSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
}
