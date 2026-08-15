import 'dart:convert' show base64Encode;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/web_helper.dart';
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
  static Future<Uint8List?> fetchLogoBytes(String? logoUrl) => _logoBytes(logoUrl);

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
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            // Top Header: Shop branding & Invoice title
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: <pw.Widget>[
                pw.Container(
                  width: 54,
                  height: 54,
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
                          style: pw.TextStyle(
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
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _teal,
                      ),
                    ),
                    pw.Text(
                      'Haute Couture & Confection Sur-Mesure',
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
                        'FACTURE CLIENT',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: _teal,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'N° ${order.id.length >= 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase()}',
                        style: pw.TextStyle(
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

            // Client info & Order dates container
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
                        'INFORMATIONS CLIENT',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: _teal,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        order.clientName,
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900,
                        ),
                      ),
                      if (order.clientPhone.isNotEmpty)
                        pw.Text(
                          'Tél: ${order.clientPhone}',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: <pw.Widget>[
                      pw.Text('Date de commande: ${df(order.createdAt)}',
                          style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800)),
                      pw.SizedBox(height: 2),
                      pw.Text('Date de retrait prévue: ${df(order.expectedDate)}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _teal)),
                      if (order.tailorName != null && order.tailorName!.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('Couturier: ${order.tailorName}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Line items table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: <int, pw.TableColumnWidth>{
                0: const pw.FlexColumnWidth(3.5),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              children: <pw.TableRow>[
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _teal),
                  children: <pw.Widget>[
                    _cell('Désignation de l\'article', bold: true, color: PdfColors.white),
                    _cell('Quantité', bold: true, color: PdfColors.white, align: pw.TextAlign.center),
                    _cell('Prix Unitaire', bold: true, color: PdfColors.white, align: pw.TextAlign.right),
                    _cell('Total Ligne', bold: true, color: PdfColors.white, align: pw.TextAlign.right),
                  ],
                ),
                ...order.activeItems.map((it) => pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.white),
                      children: <pw.Widget>[
                        _cell(it.garmentType),
                        _cell('${it.quantity}', align: pw.TextAlign.center),
                        _cell(formatFcfa(it.unitPrice), align: pw.TextAlign.right),
                        _cell(formatFcfa(it.lineTotal), bold: true, align: pw.TextAlign.right),
                      ],
                    )),
              ],
            ),
            pw.SizedBox(height: 14),

            // Summary Totals Block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total Général:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                          pw.Text(formatFcfa(order.total),
                              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _teal)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Avance Versée:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                          pw.Text(formatFcfa(order.advance),
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900)),
                        ],
                      ),
                      pw.Divider(color: PdfColors.grey400, thickness: 0.8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('RESTE À PAYER:',
                              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                          pw.Text(formatFcfa(order.reste),
                              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Important Terms / Notice Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.amber300, width: 1.0),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                color: PdfColors.amber50,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(
                    'ENGAGEMENT & CONDITIONS :',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.amber900,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Merci de vous présenter pour le retrait de votre commande à la date convenue. '
                    'Tout article non réclamé dans un délai de 30 jours dégage l\'atelier de toute responsabilité.',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey900,
                    ),
                  ),
                ],
              ),
            ),

            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300, thickness: 0.5),
            pw.Center(
              child: pw.Text(
                'Merci pour votre confiance — $shopName | Système de Gestion Couture Pro',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
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
    String promoGroupLink = '',
    String? logoUrl,
  }) async {
    final bytes = await buildPdf(
      order: order,
      shopName: shopName,
      promoGroupLink: promoGroupLink,
      logoBytes: await _logoBytes(logoUrl),
    );
    final safeClient = order.clientName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final fileName = 'facture_$safeClient.pdf';
    if (kIsWeb) {
      _downloadPdfWeb(bytes, fileName);
    } else {
      await Printing.sharePdf(
          bytes: bytes, filename: fileName);
    }
  }

  static void _downloadPdfWeb(Uint8List bytes, String filename) {
    try {
      final base64Str = base64Encode(bytes);
      triggerPdfDownloadWeb(base64Str, filename);
    } catch (_) {
      Printing.sharePdf(bytes: bytes, filename: filename);
    }
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
    String promoGroupLink = '',
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

    final uri = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(msg.toString())}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens WhatsApp with a friendly notification that the garment is ready.
  static Future<bool> sendOrderReadyWhatsApp({
    required TailoringOrder order,
    required String shopName,
  }) async {
    final phone = _waPhone(order.clientPhone);
    if (phone == null) return false;

    final msg = StringBuffer()
      ..writeln('Bonjour ${order.clientName},')
      ..writeln()
      ..writeln('Bonne nouvelle ! Votre commande chez $shopName est prête pour retrait !')
      ..writeln('Reste à régler: ${formatFcfa(order.reste)}')
      ..writeln()
      ..writeln('Vous pouvez passer la récupérer à l\'atelier à tout moment.')
      ..writeln('Merci beaucoup pour votre patience et votre confiance !')
      ..writeln('À très bientôt chez $shopName.');

    final uri = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(msg.toString())}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Generates a branded PDF receipt for a counter product/model sale.
  static Future<Uint8List> buildSaleReceiptPdf({
    required String itemName,
    required String itemKind,
    required int qty,
    required int unitPrice,
    required int total,
    required String shopName,
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();
    final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context ctx) => pw.Column(
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
                          style: pw.TextStyle(
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
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _teal,
                      ),
                    ),
                    pw.Text(
                      'Boutique & Vente Prêt-à-Porter',
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
                        'REÇU DE VENTE',
                        style: pw.TextStyle(
                          fontSize: 12.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _teal,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Date: ${_fmtDate(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Divider(color: _teal, thickness: 1.5),
            pw.SizedBox(height: 14),

            // Item table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const <int, pw.TableColumnWidth>{
                0: pw.FlexColumnWidth(3.5),
                1: pw.FlexColumnWidth(1.8),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(2),
                4: pw.FlexColumnWidth(2),
              },
              children: <pw.TableRow>[
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _teal),
                  children: <pw.Widget>[
                    _cell('Désignation de l\'article', bold: true, color: PdfColors.white),
                    _cell('Catégorie', bold: true, color: PdfColors.white),
                    _cell('Qté', bold: true, color: PdfColors.white, align: pw.TextAlign.center),
                    _cell('Prix Unitaire', bold: true, color: PdfColors.white, align: pw.TextAlign.right),
                    _cell('Total', bold: true, color: PdfColors.white, align: pw.TextAlign.right),
                  ],
                ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.white),
                  children: <pw.Widget>[
                    _cell(itemName, bold: true),
                    _cell(itemKind == 'pret_a_porter' ? 'Prêt-à-Porter' : 'Produit / Accessoire'),
                    _cell('$qty', align: pw.TextAlign.center),
                    _cell(formatFcfa(unitPrice), align: pw.TextAlign.right),
                    _cell(formatFcfa(total), bold: true, align: pw.TextAlign.right),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Summary Totals Badge
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL PAYÉ:',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: _teal,
                        ),
                      ),
                      pw.Text(
                        formatFcfa(total),
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: _teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300, thickness: 0.5),
            pw.Center(
              child: pw.Text(
                'Merci pour votre achat chez $shopName ! — Couture Pro',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  static String _fmtDate(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
}
