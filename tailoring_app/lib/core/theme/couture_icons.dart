import 'package:flutter/widgets.dart';

/// The app's icon family: Phosphor Regular, one weight, drawn on a single
/// 1.5-px stroke. The screens used to mix Material glyphs of three different
/// eras (filled, rounded, outlined) which is a large part of why the app read
/// as assembled rather than designed.
///
/// **Why the font is vendored instead of taken from `phosphor_flutter`.**
/// That package's `PhosphorIconData extends IconData`, and `IconData` became a
/// `final class` in Flutter — the package no longer compiles at all on the
/// version this app is built with (`phosphor_flutter` 2.1.0 is its latest
/// release, so there is nothing to upgrade to). What the package really ships
/// is a font plus a table of code points; both are MIT-licensed, so the font
/// sits in `assets/icons/Phosphor.ttf` with its licence beside it and the code
/// points this app actually uses are listed below. Nothing else was lost: the
/// package's own `PhosphorIcon` widget is a thin wrapper over `Icon`.
///
/// Adding an icon = one line here. Take the code point from
/// https://phosphoricons.com (Regular weight); Flutter tree-shakes the font
/// down to the glyphs named in this file, so the 480 KB asset costs a few
/// hundred bytes in the built app.
class CoutureIcons {
  CoutureIcons._();

  static const String _family = 'PhosphorRegular';

  // ---- the till and the counter ---------------------------------------------
  static const IconData cashRegister = IconData(0xed80, fontFamily: _family);
  static const IconData receipt = IconData(0xe3ec, fontFamily: _family);

  /// Orders in the workshop. Deliberately NOT the receipt glyph: the till's
  /// receipts and the tailoring orders are two different lists, and the same
  /// picture on both is the fastest way to send someone to the wrong screen.
  static const IconData clipboardText = IconData(0xe198, fontFamily: _family);
  static const IconData shoppingBag = IconData(0xe416, fontFamily: _family);

  // ---- the workshop ---------------------------------------------------------
  static const IconData scissors = IconData(0xeae0, fontFamily: _family);
  static const IconData coatHanger = IconData(0xe7fe, fontFamily: _family);
  static const IconData images = IconData(0xe836, fontFamily: _family);

  // ---- the diary ------------------------------------------------------------
  static const IconData calendarBlank = IconData(0xe10a, fontFamily: _family);
  static const IconData clockCounterClockwise =
      IconData(0xe1a0, fontFamily: _family);

  // ---- actions --------------------------------------------------------------
  static const IconData plusCircle = IconData(0xe3d6, fontFamily: _family);
  static const IconData magnifyingGlass = IconData(0xe30c, fontFamily: _family);
  static const IconData signOut = IconData(0xe42a, fontFamily: _family);

  /// The only icon that must flip if the interface is ever mirrored.
  static const IconData caretRight =
      IconData(0xe13a, fontFamily: _family, matchTextDirection: true);

  // ---- management -----------------------------------------------------------
  static const IconData wallet = IconData(0xe68a, fontFamily: _family);
  static const IconData chartBar = IconData(0xe150, fontFamily: _family);
  static const IconData storefront = IconData(0xe470, fontFamily: _family);
  static const IconData identificationBadge =
      IconData(0xe6f6, fontFamily: _family);
  static const IconData gear = IconData(0xe270, fontFamily: _family);
}
