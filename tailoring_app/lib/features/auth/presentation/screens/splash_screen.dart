import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// Branded splash screen. Auth/onboarding redirect logic is handled by
/// the GoRouter `redirect` callback, so this screen mostly just renders
/// while auth state is resolving.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 96,
              width: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.content_cut_rounded,
                size: 44,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              context.loc.appName,
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.loc.tagline,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.7),
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
