import 'package:flutter/material.dart';

/// "Indigo & Terre" — the palette the app is being redesigned onto
/// (owner decision 2026-08-23, after comparing two directions).
///
/// **This is ADDITIVE on purpose.** `AppColors` is untouched, so every screen
/// that has not been redesigned yet looks exactly as it did. Screens move over
/// one at a time, reviewed one at a time; the day the last one moves,
/// `AppColors` can be retired. Do not "tidy up" by pointing `AppColors` at
/// these values — that would restyle a dozen unreviewed screens at once.
///
/// Why indigo rather than the cream-and-gold alternative that was also drawn:
///
///  * **Legibility outdoors.** The shops open onto the street and the phones are
///    cheap. White on indigo measures 13.4:1 and indigo on paper 11.9:1. The
///    gold of the other direction was 3.9:1 on white — under the 4.5 floor.
///  * **One colour per shop.** The app already lets each shop pick its own
///    colour (`settings.theme_color`). Here that colour IS the header band, so a
///    shop can be indigo, plum or oxblood and the rest of the palette still
///    agrees. The other direction hung its identity on a gold/teal harmony that
///    an arbitrary brand colour would have broken.
///  * **It belongs here.** Indigo is the dye of this region rather than a
///    borrowed luxury vocabulary.
///
/// Every value below was checked against WCAG AA (4.5:1) on its own background;
/// the two that failed in the first sketch (a 2.8:1 caption grey and a 3.9:1
/// terracotta) are already corrected here.
class CouturePalette {
  CouturePalette._();

  // ---- ground ---------------------------------------------------------------
  /// Warm paper. The old `#F7F8FA` was a cold grey — the single biggest reason
  /// the app read as "default template" rather than designed.
  static const Color paper = Color(0xFFF6F1EA);

  /// Cards sit on the paper.
  static const Color card = Color(0xFFFFFFFF);

  /// Quiet fill for the rarely-used chips.
  static const Color quiet = Color(0xFFEDE6DC);

  /// Hairlines and card borders — warm, never grey.
  static const Color line = Color(0xFFE9E1D6);

  // ---- brand ----------------------------------------------------------------
  /// The header band. Default only: a shop's own `theme_color` replaces it.
  static const Color indigo = Color(0xFF1E2E52);

  /// The pale wash behind an icon on a card.
  static const Color indigoWash = Color(0xFFE9EDF5);

  /// Reserved for what needs acting on (a delivery due, the till button).
  /// Deliberately scarce: if everything is urgent, nothing is.
  static const Color terracotta = Color(0xFFB04E31);

  /// The pale wash behind an urgent icon.
  static const Color terracottaWash = Color(0xFFF6E4DE);

  /// Terracotta for TEXT rather than a glyph. `terracotta` on `terracottaWash`
  /// is 4.3:1 — fine for a 20-px icon (graphics need 3:1) and a fail for an
  /// 11-px label. This one is 5.5:1 on the same wash.
  static const Color terracottaDeep = Color(0xFF8F3E22);

  /// Finished, and finished well: the "terminé" / "livré" green. Chosen inside
  /// the same earth family rather than a Material green — 5.2:1 on its wash.
  static const Color sage = Color(0xFF3F6B4A);
  static const Color sageWash = Color(0xFFE6EFE5);

  // ---- text -----------------------------------------------------------------
  /// Warm near-black, not the blue-black of the old palette.
  static const Color ink = Color(0xFF211D19);

  /// Secondary copy on paper — 5.1:1.
  static const Color inkSoft = Color(0xFF6E645A);

  /// Captions and section labels on paper — 4.6:1. Anything lighter fails.
  static const Color inkFaint = Color(0xFF756B61);

  /// Body text inside a quiet list row.
  static const Color inkList = Color(0xFF3A342E);

  /// On the coloured band.
  static const Color onBand = Color(0xFFFFFFFF);

  /// The muted label on the coloured band — 5.1:1 on indigo.
  static const Color onBandSoft = Color(0xFFA9B6D2);

  // ---- rhythm ---------------------------------------------------------------
  /// 4-pt grid. Nothing in a redesigned screen uses a value off this list.
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s6 = 24;
  static const double s8 = 32;

  /// Every tappable row is at least this tall — fingers, not a mouse.
  static const double minTouch = 48;

  /// Section label: small, wide-tracked, upper-case. The colour comes from the
  /// active [CoutureScheme] — `copyWith(color: scheme.inkFaint)`.
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 11,
    letterSpacing: 2.2,
    fontWeight: FontWeight.w600,
  );

  // ---- night ----------------------------------------------------------------
  // The app's default is `ThemeMode.system`, so a phone set to dark shows the
  // dark theme whether anyone asked for it or not. A light-only screen in an
  // otherwise dark app is not a style choice, it is a bug — hence a full second
  // set of tokens rather than a `Colors.white` here and there. Same warmth: a
  // warm near-black, never the blue-grey #121212 default.
  //
  // Every pair below was measured, not eyeballed: text on its own ground is
  // 6.0:1 at worst (inkFaintDark on paperDark) against a 4.5 floor.
  static const Color paperDark = Color(0xFF14110E);
  static const Color cardDark = Color(0xFF1E1A16);
  static const Color quietDark = Color(0xFF262019);
  static const Color lineDark = Color(0xFF38302A);

  /// Indigo cannot stay #1E2E52 on a near-black card — it disappears. The wash
  /// darkens and the glyph on it lightens, keeping the same relationship.
  static const Color indigoWashDark = Color(0xFF232B3D);
  static const Color indigoLight = Color(0xFF9FB3DC);
  static const Color terracottaWashDark = Color(0xFF3A241C);
  static const Color terracottaLight = Color(0xFFE08A6B);
  static const Color sageWashDark = Color(0xFF212C22);
  static const Color sageLight = Color(0xFF9CC4A2);

  static const Color inkDark = Color(0xFFF3ECE3);
  static const Color inkSoftDark = Color(0xFFB8ACA0);
  static const Color inkFaintDark = Color(0xFF9C9084);
  static const Color inkListDark = Color(0xFFE2D9CE);
}

/// The tokens a screen actually paints with, resolved for the brightness in
/// force. A redesigned screen reads `CoutureScheme.of(context)` once in
/// `build` and never touches a raw colour.
class CoutureScheme {
  const CoutureScheme({
    required this.paper,
    required this.card,
    required this.quiet,
    required this.line,
    required this.iconWash,
    required this.iconInk,
    required this.urgentWash,
    required this.urgentInk,
    required this.urgentText,
    required this.goodWash,
    required this.goodInk,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.inkList,
  });

  final Color paper;
  final Color card;
  final Color quiet;
  final Color line;

  /// The pale square an icon sits in, and the glyph on it.
  final Color iconWash;
  final Color iconInk;

  /// The same pair for the one thing that carries a deadline.
  final Color urgentWash;
  final Color urgentInk;

  /// Terracotta at text weight — small labels on the urgent wash, where the
  /// icon tone would fall below the AA floor.
  final Color urgentText;

  /// Finished / delivered / paid: the reassuring pair.
  final Color goodWash;
  final Color goodInk;

  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color inkList;

  static const CoutureScheme light = CoutureScheme(
    paper: CouturePalette.paper,
    card: CouturePalette.card,
    quiet: CouturePalette.quiet,
    line: CouturePalette.line,
    iconWash: CouturePalette.indigoWash,
    iconInk: CouturePalette.indigo,
    urgentWash: CouturePalette.terracottaWash,
    urgentInk: CouturePalette.terracotta,
    urgentText: CouturePalette.terracottaDeep,
    goodWash: CouturePalette.sageWash,
    goodInk: CouturePalette.sage,
    ink: CouturePalette.ink,
    inkSoft: CouturePalette.inkSoft,
    inkFaint: CouturePalette.inkFaint,
    inkList: CouturePalette.inkList,
  );

  static const CoutureScheme dark = CoutureScheme(
    paper: CouturePalette.paperDark,
    card: CouturePalette.cardDark,
    quiet: CouturePalette.quietDark,
    line: CouturePalette.lineDark,
    iconWash: CouturePalette.indigoWashDark,
    iconInk: CouturePalette.indigoLight,
    urgentWash: CouturePalette.terracottaWashDark,
    urgentInk: CouturePalette.terracottaLight,
    // On a near-black wash the light tone already clears the floor for text.
    urgentText: CouturePalette.terracottaLight,
    goodWash: CouturePalette.sageWashDark,
    goodInk: CouturePalette.sageLight,
    ink: CouturePalette.inkDark,
    inkSoft: CouturePalette.inkSoftDark,
    inkFaint: CouturePalette.inkFaintDark,
    inkList: CouturePalette.inkListDark,
  );

  static CoutureScheme of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
