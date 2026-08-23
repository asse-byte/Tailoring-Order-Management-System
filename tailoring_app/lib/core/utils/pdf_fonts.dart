import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Fonts for every PDF the app produces (facture, reçu, rapport).
///
/// The `pdf` package falls back to the PDF standard Helvetica when a document
/// declares no theme, and Helvetica has **no Unicode support**. Three
/// characters used all over our French documents simply could not be drawn:
///
///   * `—` (U+2014) in every "Revenus — ..." line and every page footer,
///   * `’` (U+2019) in apostrophised French,
///   * `œ` (U+0153) in "Main d'œuvre", on the report and the salary receipt.
///
/// They came out as holes or wrong glyphs, which is the "strange symbols" the
/// shop owner reported on printed invoices. Embedding a real TrueType face
/// fixes it for good — including for anything the shop types itself, such as a
/// client name.
///
/// Loaded once and cached: parsing a TTF on every share is slow, and the
/// tailoring shops print all day.
class PdfFonts {
  PdfFonts._();

  static pw.ThemeData? _cached;

  /// Lato for text (humanist, prints cleanly at small sizes) with Cormorant
  /// Garamond for the shop name and document titles — a tailored, unmistakably
  /// "couture" masthead rather than the default Helvetica look.
  static Future<pw.ThemeData> theme() async {
    if (_cached != null) return _cached!;
    final regular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Lato-Regular.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Lato-Bold.ttf'));
    final display = pw.Font.ttf(
        await rootBundle.load('assets/fonts/CormorantGaramond-SemiBold.ttf'));
    _cached = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: regular,
      boldItalic: bold,
      // Anything the base face somehow lacks falls back rather than vanishing.
      fontFallback: <pw.Font>[display, bold],
    );
    return _cached!;
  }

  /// The display face on its own, for a shop name or a document title.
  static Future<pw.Font> display() async => pw.Font.ttf(
      await rootBundle.load('assets/fonts/CormorantGaramond-SemiBold.ttf'));
}
