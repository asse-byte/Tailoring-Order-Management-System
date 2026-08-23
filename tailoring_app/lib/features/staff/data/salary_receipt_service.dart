import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/pdf_fonts.dart';

/// Builds and shares a salary payment RECEIPT (reçu de paiement) — for
/// documentation when a monthly employee or a tailor is paid. Manager-only
/// context (only reached from the finance/staff screens).
class SalaryReceiptService {
  const SalaryReceiptService._();

  static const PdfColor _teal = PdfColor.fromInt(0xFF006D6D);
  static const PdfColor _gold = PdfColor.fromInt(0xFFC9A84C);

  /// Same logo priority as the invoice: uploaded logo → bundled asset → "R".
  static Future<Uint8List?> _logoBytes(String? logoUrl) async {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        final url = logoUrl.startsWith('http')
            ? logoUrl
            : '${ApiClient.baseUrl}$logoUrl';
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) return res.bodyBytes;
      } catch (_) {}
    }
    return null;
  }

  static Future<Uint8List> buildPdf({
    required String shopName,
    required String staffName,
    required String staffPhone,
    required String roleLabel,
    required String periodLabel,
    required int amount,
    required String paidAtLabel,
    required String receiptNo,
    Uint8List? logoBytes,
  }) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            // Header: Shop Branding & Receipt Title
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: <pw.Widget>[
                pw.Container(
                  width: 52,
                  height: 52,
                  decoration: pw.BoxDecoration(
                    color: _teal,
                    shape: pw.BoxShape.circle,
                    image: logo != null
                        ? pw.DecorationImage(image: logo, fit: pw.BoxFit.cover)
                        : null,
                  ),
                  alignment: pw.Alignment.center,
                  child: logo == null
                      ? pw.Text(
                          shopName.trim().isNotEmpty ? shopName.trim()[0].toUpperCase() : 'C',
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 26,
                              fontWeight: pw.FontWeight.bold))
                      : null,
                ),
                pw.SizedBox(width: 14),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(
                      shopName,
                      style: const pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _teal,
                      ),
                    ),
                    pw.Text(
                      'Règlement du Personnel & Main d\'œuvre',
                      style: const pw.TextStyle(fontSize: 9.5, color: _gold),
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: <pw.Widget>[
                      pw.Text(
                        'REÇU DE SALAIRE',
                        style: const pw.TextStyle(
                          fontSize: 12.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _teal,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'N° $receiptNo',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Divider(color: _teal, thickness: 1.5),
            pw.SizedBox(height: 12),

            // Beneficiary & Payment Metadata Container
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey200, width: 0.8),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: <pw.Widget>[
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(
                        'BÉNÉFICIAIRE',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: _teal,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        staffName,
                        style: const pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900,
                        ),
                      ),
                      if (staffPhone.isNotEmpty)
                        pw.Text('Tél: $staffPhone',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text('Poste / Fonction: $roleLabel',
                          style: const pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _teal)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: <pw.Widget>[
                      pw.Text('Période: $periodLabel',
                          style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                      pw.SizedBox(height: 4),
                      pw.Text('Date de règlement: $paidAtLabel',
                          style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800)),
                      pw.SizedBox(height: 2),
                      pw.Text('Type: Salaire mensuel / Acompte',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Amount summary card
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: <pw.Widget>[
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('MONTANT TOTAL RÉGLÉ',
                          style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _teal)),
                      pw.SizedBox(height: 2),
                      pw.Text('Paiement validé et acquitté',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text(
                    formatFcfa(amount),
                    style: const pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _teal,
                    ),
                  ),
                ],
              ),
            ),

            pw.Spacer(),

            // Signature boxes
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Container(
                  width: 220,
                  height: 90,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Signature du Bénéficiaire :',
                          style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _teal)),
                      pw.Spacer(),
                      pw.Text('Date et signature',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                    ],
                  ),
                ),
                pw.Container(
                  width: 220,
                  height: 90,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Cachet & Signature de la Direction :',
                          style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _teal)),
                      pw.Spacer(),
                      pw.Text('Pour accord et paiement',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Divider(color: PdfColors.grey300, thickness: 0.5),
            pw.Center(
              child: pw.Text(
                '$shopName — Pièce justificative comptable | Couture Pro',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
              ),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static Future<void> shareReceipt({
    required String shopName,
    required String staffName,
    required String staffPhone,
    required String roleLabel,
    required String periodLabel,
    required int amount,
    required String paidAtLabel,
    required String receiptNo,
    String? logoUrl,
  }) async {
    final bytes = await buildPdf(
      shopName: shopName,
      staffName: staffName,
      staffPhone: staffPhone,
      roleLabel: roleLabel,
      periodLabel: periodLabel,
      amount: amount,
      paidAtLabel: paidAtLabel,
      receiptNo: receiptNo,
      logoBytes: await _logoBytes(logoUrl),
    );
    final safeName = staffName.replaceAll(RegExp(r'[^\w]'), '_');
    await Printing.sharePdf(
        bytes: bytes, filename: 'recu_${safeName}_$periodLabel.pdf');
  }
}
