import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/money.dart';
import 'reports_repository.dart';

/// Builds and shares the printable business report (rapport) — manager-only.
class ReportPdfService {
  const ReportPdfService._();

  static const PdfColor _teal = PdfColor.fromInt(0xFF006D6D);
  static const PdfColor _gold = PdfColor.fromInt(0xFFC9A84C);

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
    } catch (_) {/* fall back */}
    return null;
  }

  static pw.Widget _row(String label, String value, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(label,
              style: pw.TextStyle(
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
        child: pw.Text(t,
            style: const pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold, color: _teal)),
      );

  static Future<Uint8List> buildPdf({
    required ReportSummary r,
    required String shopName,
    required String periodLabel,
    Uint8List? logoBytes,
  }) async {
    final doc = pw.Document();
    final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => <pw.Widget>[
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
                    ? pw.Text('R',
                        style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold))
                    : null,
              ),
              pw.SizedBox(width: 14),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(shopName,
                      style: const pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: _teal)),
                  pw.Text('Rapport d\'activité', style: const pw.TextStyle(color: _gold)),
                ],
              ),
              pw.Spacer(),
              pw.Text('Période:\n$periodLabel',
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.Divider(color: _teal, thickness: 1.5),

          _sectionTitle('Résultat financier'),
          _row('Revenus — ventes produits/prêt-à-porter', formatFcfa(r.salesRevenue)),
          _row('Revenus — commandes livrées', formatFcfa(r.ordersRevenue)),
          _row('REVENU TOTAL', formatFcfa(r.totalRevenue), bold: true, color: _teal),
          pw.SizedBox(height: 6),
          _row('Coût des marchandises vendues', formatFcfa(r.cogs)),
          _row('Main d\'œuvre couture (à la pièce)', formatFcfa(r.tailorWages)),
          _row('Salaires mensuels (au prorata)', formatFcfa(r.salaries)),
          _row('Dépenses', formatFcfa(r.expenses)),
          _row('COÛTS TOTAUX', formatFcfa(r.totalCosts), bold: true),
          pw.Divider(),
          _row('BÉNÉFICE NET', formatFcfa(r.netProfit),
              bold: true, color: r.netProfit >= 0 ? _teal : PdfColors.red),

          _sectionTitle('Activité'),
          _row('Nouveaux clients', '${r.newClients}'),
          _row('Clients servis (commandes livrées)', '${r.servedClients}'),
          _row('Commandes créées', '${r.ordersCreated}'),
          _row('Commandes livrées', '${r.ordersDelivered}'),
          _row('Commandes en cours (actuel)', '${r.ordersActive}'),
          _row('Unités de produits vendues', '${r.productsSoldUnits}'),

          if (r.topTailors.isNotEmpty) ...<pw.Widget>[
            _sectionTitle('Classement des tailleurs (période)'),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: <int, pw.TableColumnWidth>{
                0: const pw.FlexColumnWidth(0.6),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(2),
              },
              children: <pw.TableRow>[
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _teal),
                  children: <pw.Widget>[
                    _cell('#', bold: true, color: PdfColors.white),
                    _cell('Tailleur', bold: true, color: PdfColors.white),
                    _cell('Pièces', bold: true, color: PdfColors.white),
                    _cell('Montant', bold: true, color: PdfColors.white),
                  ],
                ),
                ...List.generate(r.topTailors.length, (i) {
                  final t = r.topTailors[i];
                  return pw.TableRow(children: <pw.Widget>[
                    _cell('${i + 1}'),
                    _cell(t.tailorName),
                    _cell('${t.piecesTotal}'),
                    _cell(formatFcfa(t.amountTotal)),
                  ]);
                }),
              ],
            ),
          ],

          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text('$shopName — document interne (gérant)',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<void> shareReport({
    required ReportSummary r,
    required String shopName,
    required String periodLabel,
    String? logoUrl,
  }) async {
    final bytes = await buildPdf(
      r: r,
      shopName: shopName,
      periodLabel: periodLabel,
      logoBytes: await _logoBytes(logoUrl),
    );
    await Printing.sharePdf(
        bytes: bytes, filename: 'rapport_${r.from}_${r.to}.pdf');
  }

  static pw.Widget _cell(String text,
      {bool bold = false, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }
}
