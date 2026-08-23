// =============================================================================
// The UI font must ship inside the app, not be fetched from Google on launch.
// =============================================================================
// google_fonts downloads a font at runtime on first launch unless the file is
// bundled AND declared in pubspec's assets. In Mali that download often just
// fails, and the package falls back to the system face — so the shop sees an
// app that does not look like the one that was designed, with no error anywhere.
//
// main.dart sets `allowRuntimeFetching = false` so there is no network path at
// all. That makes the bundle the only source, and a file that is missing,
// renamed, or left out of pubspec.yaml becomes a real breakage.
//
// The check is deliberately on the ASSET BUNDLE rather than on GoogleFonts
// itself: google_fonts resolves a missing font asynchronously and swallows the
// error, so calling it here would pass even with every file deleted. Loading
// the asset is what actually fails when the bundle is wrong.
// =============================================================================

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// The weights app_theme.dart asks for, under the names google_fonts matches.
const List<String> _required = <String>[
  'assets/google_fonts/Poppins-Regular.ttf',  // w400
  'assets/google_fonts/Poppins-Medium.ttf',   // w500
  'assets/google_fonts/Poppins-SemiBold.ttf', // w600
  'assets/google_fonts/Poppins-Bold.ttf',     // w700
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final String path in _required) {
    test('$path is bundled', () async {
      final data = await rootBundle.load(path);
      // A real TrueType file, not a stray HTML error page saved with a .ttf
      // name — which is exactly what a failed download leaves behind.
      expect(data.lengthInBytes, greaterThan(20000),
          reason: '$path is too small to be a real font file');
      expect(data.getUint32(0), anyOf(0x00010000, 0x74727565),
          reason: '$path does not start with a TrueType signature');
    });
  }

  // The icon family is vendored (see lib/core/theme/couture_icons.dart), so
  // nothing but this asset stands between the app and a screen full of empty
  // boxes — there is no package to notice the file is gone.
  test('the icon font is bundled', () async {
    final data = await rootBundle.load('assets/icons/Phosphor.ttf');
    expect(data.lengthInBytes, greaterThan(100000),
        reason: 'the Phosphor font is truncated or missing');
    expect(data.getUint32(0), anyOf(0x00010000, 0x74727565),
        reason: 'assets/icons/Phosphor.ttf is not a TrueType file');
  });

  test('the PDF faces are bundled too', () async {
    for (final String path in <String>[
      'assets/fonts/Lato-Regular.ttf',
      'assets/fonts/Lato-Bold.ttf',
      'assets/fonts/CormorantGaramond-SemiBold.ttf',
    ]) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(20000), reason: '$path is truncated');
    }
  });
}
