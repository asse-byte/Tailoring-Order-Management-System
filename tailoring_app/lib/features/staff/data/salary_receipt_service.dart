import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/money.dart';

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
      } catch (_) {/* fall back */}
    }
    try {
      final data = await rootBundle.load('assets/logo.jpeg');
      return data.buffer.asUint8List();
    } catch (_) {/* fall back to placeholder */}
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
    final doc = pw.Document();
    final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: <pw.Widget>[
                pw.Container(
                  width: 56,
                  height: 56,
                  decoration: pw.BoxDecoration(
                    color: _teal,
                    shape: pw.BoxShape.circle,
                    image: logo != null
                        ? pw.DecorationImage(image: logo, fit: pw.BoxFit.cover)
                        : null,
                  ),
                  alignment: pw.Alignment.center,
                  child: logo == null
                      ? pw.Text('R',
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 30,
                              fontWeight: pw.FontWeight.bold))
                      : null,
                ),
                pw.SizedBox(width: 14),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(shopName,
                        style: const pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: _teal)),
                    pw.Text('Atelier de couture',
                        style: const pw.TextStyle(fontSize: 11, color: _gold)),
                  ],
                ),
                pw.Spacer(),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: <pw.Widget>[
                    pw.Text('REÇU DE PAIEMENT',
                        style: const pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('N° $receiptNo',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.Divider(color: _teal, thickness: 1.5),
            pw.SizedBox(height: 16),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text('Bénéficiaire',
                        style: const pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, color: _teal)),
                    pw.Text(staffName),
                    if (staffPhone.isNotEmpty) pw.Text(staffPhone),
                    pw.Text(roleLabel,
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: <pw.Widget>[
                    pw.Text('Période: $periodLabel'),
                    pw.Text('Date de paiement: $paidAtLabel'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF2F8F8),
                border: pw.Border.all(color: _teal, width: 1),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: <pw.Widget>[
                  pw.Text('MONTANT PAYÉ',
                      style: const pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(formatFcfa(amount),
                      style: const pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: _teal)),
                ],
              ),
            ),

            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text('Signature employé',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 28),
                    pw.Container(width: 150, height: 0.5, color: PdfColors.grey),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text('Signature gérant',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 28),
                    pw.Container(width: 150, height: 0.5, color: PdfColors.grey),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text('$shopName — document de paiement',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
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
