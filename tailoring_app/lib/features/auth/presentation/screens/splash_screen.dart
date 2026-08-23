import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';

/// The half-second before the app knows who is holding the phone. Auth and
/// redirect logic live in the GoRouter `redirect` callback; this screen only
/// has to be something to look at while that resolves.
///
/// It cannot show the shop's own colour or logo: the settings that carry them
/// have not been fetched yet at this point. So it shows the house indigo and
/// the app's own name, and hands over to the login screen — which does know
/// the shop — as soon as it can.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CouturePalette.indigo,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: const Icon(
                CoutureIcons.scissors,
                size: 38,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: CouturePalette.s6),
            Text(
              context.loc.appName,
              style: const TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: CouturePalette.onBand,
                height: 1.1,
              ),
            ),
            const SizedBox(height: CouturePalette.s2),
            Text(
              context.loc.tagline.toUpperCase(),
              style: CouturePalette.sectionLabel
                  .copyWith(color: CouturePalette.onBandSoft),
            ),
            const SizedBox(height: CouturePalette.s8 + CouturePalette.s1),
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white.withValues(alpha: 0.7),
                strokeWidth: 2.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
