import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/pdf_fonts.dart';
import '../../../core/utils/web_helper.dart';
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
      } catch (_) {}
    }
    return null;
  }

  static pw.Widget _cell(String text,
      {bool bold = false,
      PdfColor color = PdfColors.black,
      pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
            fontSize: 9.5,
            color: color,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static pw.Widget _sectionHeader(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14, bottom: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const pw.BoxDecoration(
        color: _teal,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _financialRow(String label, String value,
      {bool bold = false, PdfColor? color, bool isSub = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: isSub ? 12 : 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isSub ? PdfColors.grey700 : PdfColors.grey900,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: bold ? 10.5 : 9.5,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? (bold ? _teal : PdfColors.grey900),
            ),
          ),
        ],
      ),
    );
  }

  static Future<Uint8List> buildPdf({
    required ReportSummary r,
    required String shopName,
    required String periodLabel,
    Uint8List? logoBytes,
  }) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => <pw.Widget>[
          // Header: Shop Branding & Report Title
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
                    'Rapport de la boutique',
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
                      'BILAN PÉRIODIQUE',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: _teal,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Période: $periodLabel',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: _teal, thickness: 1.5),
          pw.SizedBox(height: 10),

          // 3 High-level Executive Metric Cards
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CHIFFRE D\'AFFAIRES',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(formatFcfa(r.totalRevenue),
                          style: const pw.TextStyle(
                              fontSize: 12.5, fontWeight: pw.FontWeight.bold, color: _teal)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TOTAL DES CHARGES',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(formatFcfa(r.totalCosts),
                          style: const pw.TextStyle(
                              fontSize: 12.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromInt(0xFFC5221F))),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: r.netProfit >= 0
                        ? const PdfColor.fromInt(0xFFE6F4EA)
                        : const PdfColor.fromInt(0xFFFCE8E6),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(
                      color: r.netProfit >= 0
                          ? const PdfColor.fromInt(0xFF137333)
                          : const PdfColor.fromInt(0xFFC5221F),
                      width: 0.8,
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BÉNÉFICE NET',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: r.netProfit >= 0
                                  ? const PdfColor.fromInt(0xFF137333)
                                  : const PdfColor.fromInt(0xFFC5221F))),
                      pw.SizedBox(height: 4),
                      pw.Text(formatFcfa(r.netProfit),
                          style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: r.netProfit >= 0
                                  ? const PdfColor.fromInt(0xFF137333)
                                  : const PdfColor.fromInt(0xFFC5221F))),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Section 1: Financial Details
          _sectionHeader('1. L\'argent de la boutique'),
          _financialRow('Argent reçu — commandes des clients', formatFcfa(r.ordersRevenue), isSub: true),
          _financialRow('Argent reçu — ventes en boutique', formatFcfa(r.salesRevenue), isSub: true),
          _financialRow('Argent reçu — ventes en gros', formatFcfa(r.wholesaleRevenue), isSub: true),
          _financialRow('TOTAL DES REVENUS (CHIFFRE D\'AFFAIRES)', formatFcfa(r.totalRevenue), bold: true, color: _teal),
          pw.SizedBox(height: 6),
          _financialRow('Achat de la marchandise vendue', formatFcfa(r.cogs), isSub: true),
          _financialRow('Main d\'œuvre couture (Rémunération à la pièce)', formatFcfa(r.tailorWages), isSub: true),
          _financialRow('Salaires du personnel', formatFcfa(r.salaries), isSub: true),
          _financialRow('Dépenses & Frais d\'exploitation du salon', formatFcfa(r.expenses), isSub: true),
          _financialRow('TOTAL DE L\'ARGENT SORTI', formatFcfa(r.totalCosts), bold: true, color: const PdfColor.fromInt(0xFFC5221F)),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('CE QUI RESTE À LA BOUTIQUE :',
                    style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _teal)),
                pw.Text(
                  formatFcfa(r.netProfit),
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: r.netProfit >= 0 ? const PdfColor.fromInt(0xFF137333) : const PdfColor.fromInt(0xFFC5221F),
                  ),
                ),
              ],
            ),
          ),

          // Section 2: Activity Indicators
          _sectionHeader('2. Le travail de la période'),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _financialRow('Nouveaux clients', '${r.newClients}', isSub: true),
                    _financialRow('Clients servis', '${r.servedClients}', isSub: true),
                    _financialRow('Articles vendus', '${r.productsSoldUnits}', isSub: true),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _financialRow('Commandes créées sur la période', '${r.ordersCreated}', isSub: true),
                    _financialRow('Commandes terminées et livrées', '${r.ordersDelivered}', isSub: true),
                    _financialRow('Commandes en cours à l\'atelier', '${r.ordersActive}', isSub: true),
                  ],
                ),
              ),
            ],
          ),

          // Section 3: Tailors Production Ranking
          if (r.topTailors.isNotEmpty) ...<pw.Widget>[
            _sectionHeader('3. Palmarès de Production des Tailleurs (Période)'),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const <int, pw.TableColumnWidth>{
                0: pw.FlexColumnWidth(0.8),
                1: pw.FlexColumnWidth(3.5),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(2.2),
              },
              children: <pw.TableRow>[
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _teal),
                  children: <pw.Widget>[
                    _cell('#', bold: true, color: PdfColors.white, align: pw.TextAlign.center),
                    _cell('Nom du Tailleur', bold: true, color: PdfColors.white),
                    _cell('Pièces confectionnées', bold: true, color: PdfColors.white, align: pw.TextAlign.center),
                    _cell('Montant rémunéré', bold: true, color: PdfColors.white, align: pw.TextAlign.right),
                  ],
                ),
                ...r.topTailors.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final t = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: idx % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: <pw.Widget>[
                      _cell('${idx + 1}', align: pw.TextAlign.center, bold: true),
                      _cell(t.tailorName, bold: true),
                      _cell('${t.piecesTotal}', align: pw.TextAlign.center),
                      _cell(formatFcfa(t.amountTotal), align: pw.TextAlign.right, bold: true),
                    ],
                  );
                }),
              ],
            ),
          ],

          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Document de gestion confidentiel — $shopName',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
              ),
              pw.Text(
                'Généré par Couture Pro',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
              ),
            ],
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
    final fileName = 'rapport_${r.from}_${r.to}.pdf';
    if (kIsWeb) {
      try {
        final base64Str = base64Encode(bytes);
        triggerPdfDownloadWeb(base64Str, fileName);
      } catch (_) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }
    } else {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }
  }
}
