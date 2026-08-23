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

  static const IconData calendarCheck = IconData(0xe712, fontFamily: _family);

  // ---- actions --------------------------------------------------------------
  static const IconData plusCircle = IconData(0xe3d6, fontFamily: _family);
  static const IconData plus = IconData(0xe3d4, fontFamily: _family);
  static const IconData minus = IconData(0xe32a, fontFamily: _family);
  static const IconData magnifyingGlass = IconData(0xe30c, fontFamily: _family);
  static const IconData signOut = IconData(0xe42a, fontFamily: _family);
  static const IconData close = IconData(0xe4f6, fontFamily: _family);
  static const IconData refresh = IconData(0xe094, fontFamily: _family);
  static const IconData filter = IconData(0xe266, fontFamily: _family);
  static const IconData filterOff = IconData(0xe26c, fontFamily: _family);
  static const IconData trash = IconData(0xe4a6, fontFamily: _family);
  static const IconData pencil = IconData(0xe3b4, fontFamily: _family);
  static const IconData share = IconData(0xe408, fontFamily: _family);
  static const IconData whatsapp = IconData(0xe5d0, fontFamily: _family);
  static const IconData printer = IconData(0xe3dc, fontFamily: _family);

  /// The two that must flip if the interface is ever mirrored.
  static const IconData caretRight =
      IconData(0xe13a, fontFamily: _family, matchTextDirection: true);
  static const IconData caretLeft =
      IconData(0xe138, fontFamily: _family, matchTextDirection: true);

  // ---- people and things ----------------------------------------------------
  static const IconData user = IconData(0xe4c2, fontFamily: _family);
  static const IconData phone = IconData(0xe3b8, fontFamily: _family);
  static const IconData package = IconData(0xe390, fontFamily: _family);

  // ---- order states ---------------------------------------------------------
  // One glyph per state of an order, so the pill is readable without its label
  // for someone who reads slowly.
  static const IconData clock = IconData(0xe19a, fontFamily: _family);

  /// A needle, not a hammer: this is a sewing workshop. The Material set had
  /// no sewing glyph at all, which is why the old badge showed a mallet.
  static const IconData needle = IconData(0xe82e, fontFamily: _family);
  static const IconData checkCircle = IconData(0xe184, fontFamily: _family);
  static const IconData truck = IconData(0xe4b4, fontFamily: _family);
  static const IconData prohibit = IconData(0xe3de, fontFamily: _family);
  static const IconData warningCircle = IconData(0xe4e2, fontFamily: _family);

  // ---- the shop's own product types -----------------------------------------
  // The manager invents the types (Parfums, Montres, Bonnets…) and picks one of
  // these glyphs for each. Concrete objects, never abstract shapes: a short list
  // of recognisable things is easier to choose from than a long list of ideas.
  static const IconData sprayBottle = IconData(0xe7e4, fontFamily: _family);
  static const IconData sneaker = IconData(0xe80c, fontFamily: _family);
  static const IconData stack = IconData(0xe466, fontFamily: _family);
  static const IconData watch = IconData(0xe4e6, fontFamily: _family);
  static const IconData baseballCap = IconData(0xea28, fontFamily: _family);
  static const IconData handbag = IconData(0xe29c, fontFamily: _family);
  static const IconData eyeglasses = IconData(0xe7ba, fontFamily: _family);
  static const IconData diamond = IconData(0xe1ec, fontFamily: _family);
  static const IconData tShirt = IconData(0xe670, fontFamily: _family);
  static const IconData tag = IconData(0xe478, fontFamily: _family);

  // ---- management -----------------------------------------------------------
  static const IconData wallet = IconData(0xe68a, fontFamily: _family);
  static const IconData chartBar = IconData(0xe150, fontFamily: _family);
  static const IconData storefront = IconData(0xe470, fontFamily: _family);
  static const IconData identificationBadge =
      IconData(0xe6f6, fontFamily: _family);
  static const IconData gear = IconData(0xe270, fontFamily: _family);
}
