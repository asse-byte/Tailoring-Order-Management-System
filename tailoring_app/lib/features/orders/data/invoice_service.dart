import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/money.dart';
import '../domain/entities/order.dart';

/// Builds and shares the order invoice (PDF) and opens WhatsApp.
///
/// Available to BOTH roles — it only exposes the order price the client
/// already knows, never internal financials (cost, profit, wages).
class InvoiceService {
  const InvoiceService._();

  static const PdfColor _teal = PdfColor.fromInt(0xFF006D6D);
  static const PdfColor _gold = PdfColor.fromInt(0xFFC9A84C);

  /// Resolves the logo bytes for the invoice, in priority order:
  /// 1. the shop's uploaded logo (settings URL), 2. the bundled default
  /// `assets/logo.jpeg`, 3. null (the PDF then draws the "R" placeholder).
  static Future<Uint8List?> _logoBytes(String? logoUrl) async {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        final url = logoUrl.startsWith('http')
            ? logoUrl
            : '${ApiClient.baseUrl}$logoUrl';
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) return res.bodyBytes;
      } catch (_) {/* fall back to bundled asset */}
    }
    try {
      final data = await rootBundle.load('assets/logo.jpeg');
      return data.buffer.asUint8List();
    } catch (_) {/* fall back to placeholder */}
    return null;
  }

  static Future<Uint8List> buildPdf({
    required TailoringOrder order,
    required String shopName,
    required String promoGroupLink,
    Uint8List? logoBytes,
  }) async {
    final doc = pw.Document();
    final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
    const df = _fmtDate;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            // Header: logo (or "R" placeholder) + shop name.
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
                    pw.Text('FACTURE',
                        style: const pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('N° ${order.id.substring(0, 8).toUpperCase()}',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.Divider(color: _teal, thickness: 1.5),
            pw.SizedBox(height: 12),

            // Client + dates.
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text('Client',
                        style: const pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, color: _teal)),
                    pw.Text(order.clientName),
                    if (order.clientPhone.isNotEmpty)
                      pw.Text(order.clientPhone),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: <pw.Widget>[
                    pw.Text('Date: ${df(order.createdAt)}'),
                    pw.Text('Livraison prévue: ${df(order.expectedDate)}'),
                    if (order.tailorName != null && order.tailorName!.isNotEmpty)
                      pw.Text('Couturier: ${order.tailorName}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Line items table.
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: <int, pw.TableColumnWidth>{
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              children: <pw.TableRow>[
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _teal),
                  children: <pw.Widget>[
                    _cell('Article', bold: true, color: PdfColors.white),
                    _cell('Qté', bold: true, color: PdfColors.white),
                    _cell('P. Unitaire', bold: true, color: PdfColors.white),
                    _cell('Total', bold: true, color: PdfColors.white),
                  ],
                ),
                ...order.activeItems.map((it) => pw.TableRow(
                      children: <pw.Widget>[
                        _cell(it.garmentType),
                        _cell('${it.quantity}'),
                        _cell(formatFcfa(it.unitPrice)),
                        _cell(formatFcfa(it.lineTotal)),
                      ],
                    )),
              ],
            ),
            pw.SizedBox(height: 12),

            // Totals.
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: <pw.Widget>[
                  pw.Text('TOTAL: ${formatFcfa(order.total)}',
                      style: const pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: _teal)),
                  pw.Text('Avance: ${formatFcfa(order.advance)}'),
                  pw.Text('Reste à payer: ${formatFcfa(order.reste)}',
                      style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),

            pw.Spacer(),
            if (promoGroupLink.isNotEmpty) ...<pw.Widget>[
              pw.Divider(color: PdfColors.grey400),
              pw.UrlLink(
                destination: promoGroupLink,
                child: pw.Text(
                  'Rejoignez notre groupe: $promoGroupLink',
                  style: const pw.TextStyle(
                      color: _teal,
                      decoration: pw.TextDecoration.underline,
                      fontSize: 11),
                ),
              ),
            ],
            pw.Center(
              child: pw.Text('Merci de votre confiance — $shopName',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  /// Build + open the OS share/print sheet for the invoice.
  static Future<void> shareInvoice({
    required TailoringOrder order,
    required String shopName,
    required String promoGroupLink,
    String? logoUrl,
  }) async {
    final bytes = await buildPdf(
      order: order,
      shopName: shopName,
      promoGroupLink: promoGroupLink,
      logoBytes: await _logoBytes(logoUrl),
    );
    await Printing.sharePdf(
        bytes: bytes, filename: 'facture_${order.clientName}.pdf');
  }

  /// International phone for wa.me: keep digits, prepend Mali (223) when an
  /// 8-digit local number is given. Returns null if clearly invalid.
  static String? _waPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length == 8) digits = '223$digits';
    return digits.length >= 8 ? digits : null;
  }

  /// Opens WhatsApp to the client with a prefilled order summary.
  /// Returns false if the phone number is missing/invalid.
  static Future<bool> sendWhatsApp({
    required TailoringOrder order,
    required String shopName,
    required String promoGroupLink,
  }) async {
    final phone = _waPhone(order.clientPhone);
    if (phone == null) return false;

    final lines = order.activeItems
        .map((it) => '• ${it.garmentType} x${it.quantity} = ${formatFcfa(it.lineTotal)}')
        .join('\n');
    final msg = StringBuffer()
      ..writeln('Bonjour ${order.clientName},')
      ..writeln('Voici le récapitulatif de votre commande chez $shopName:')
      ..writeln(lines)
      ..writeln('Total: ${formatFcfa(order.total)}')
      ..writeln('Avance: ${formatFcfa(order.advance)} — Reste: ${formatFcfa(order.reste)}');
    if (promoGroupLink.isNotEmpty) {
      msg.writeln('Rejoignez notre groupe: $promoGroupLink');
    }

    final uri = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(msg.toString())}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String _fmtDate(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static pw.Widget _cell(String text,
      {bool bold = false, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }
}
