// =============================================================================
// Regression: every generated PDF must be able to draw French properly.
// =============================================================================
// The pdf package falls back to the PDF standard Helvetica when a document
// declares no theme, and Helvetica has no Unicode support. Three characters
// used throughout our documents could not be drawn at all and came out as
// holes — which is the "strange symbols" the shop owner reported on printed
// invoices:
//
//     —  U+2014  every "Revenus — ..." line and every page footer
//     ’  U+2019  apostrophised French
//     œ  U+0153  "Main d'œuvre", on the report and the salary receipt
//
// PdfFonts.theme() embeds a real TrueType face instead. These tests fail if
// anyone goes back to a bare pw.Document().
// =============================================================================

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tailoring_app/core/utils/pdf_fonts.dart';

/// Everything our documents print that Helvetica cannot draw, plus the accented
/// French it can, so a regression in either direction is caught.
const _hardText = 'Main d’œuvre — Reçu à côté • 15 000 FCFA « déjà payé »';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the shared PDF theme embeds a real Unicode font', () async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    doc.addPage(pw.Page(build: (_) => pw.Text(_hardText)));
    final bytes = await doc.save();
    final raw = String.fromCharCodes(bytes);

    // An embedded TrueType font, not one of the 14 built-ins.
    expect(raw.contains('FontFile2'), isTrue,
        reason: 'the PDF must embed a TTF, not fall back to Helvetica');
    expect(raw.contains('/BaseFont /Helvetica'), isFalse,
        reason: 'Helvetica cannot draw —, ’ or œ');
  });

  test('rendering French prints no "unable to find a font" warning', () async {
    // The pdf package reports a missing glyph by printing
    // 'Unable to find a font to draw "X"' and leaving a hole on the page.
    // Capturing that print IS the test: it is exactly the symptom on paper.
    final theme = await PdfFonts.theme();
    final warnings = <String>[];
    await runZoned(() async {
      final doc = pw.Document(theme: theme);
      doc.addPage(pw.Page(build: (_) => pw.Text(_hardText)));
      await doc.save();
    }, zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => warnings.add(line),
    ));

    expect(warnings.where((w) => w.contains('Unable to find a font')), isEmpty,
        reason: 'a character in "$_hardText" has no glyph:\n${warnings.join('\n')}');
    expect(warnings.where((w) => w.contains('no Unicode support')), isEmpty);
  });

  test('the theme is built once and reused', () async {
    expect(identical(await PdfFonts.theme(), await PdfFonts.theme()), isTrue);
  });
}
