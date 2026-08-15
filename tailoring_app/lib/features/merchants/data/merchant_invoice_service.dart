import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/money.dart';
import '../domain/merchant_models.dart';

class MerchantInvoiceService {
  const MerchantInvoiceService._();

  static const PdfColor _teal = PdfColor.fromInt(0xFF006D6D);
  static const PdfColor _gold = PdfColor.fromInt(0xFFC9A84C);

  static Future<Uint8List?> _logoBytes(String? logoUrl) async {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        final url = logoUrl.startsWith('http') ? logoUrl : '${ApiClient.baseUrl}$logoUrl';
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) return res.bodyBytes;
      } catch (_) {}
    }
    return null;
  }

  // ---- Wholesale Merchant Invoice ----
  static Future<Uint8List> buildWholesalePdf({
    required String shopName,
    required WholesaleOrder order,
    Uint8List? logoBytes,
  }) async {
    final doc = pw.Document();
    final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            // Header: Shop Branding & Title
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
                      'Distribution En Gros & Prêt-à-Porter',
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
                        'FACTURE DE GROS',
                        style: const pw.TextStyle(
                          fontSize: 12.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _teal,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'N° GROS-${order.id.length >= 6 ? order.id.substring(0, 6).toUpperCase() : order.id.toUpperCase()}',
                        style: const pw.TextStyle(
                          fontSize: 9.5,
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

            // Merchant / Client Info Card
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
                        'CLIENT / COMMERÇANT',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: _teal,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        order.merchantName,
                        style: const pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900,
                        ),
                      ),
                      if (order.merchantPhone.isNotEmpty)
                        pw.Text('Tél: ${order.merchantPhone}',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: <pw.Widget>[
                      pw.Text('Date commande: ${order.orderDate}',
                          style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800)),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: order.status == 'livre' ? const PdfColor.fromInt(0xFFE6F4EA) : const PdfColor.fromInt(0xFFFEF7E0),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          order.status == 'livre' ? 'Livré' : 'En cours de préparation',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: order.status == 'livre' ? const PdfColor.fromInt(0xFF137333) : const PdfColor.fromInt(0xFFB06000),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Items table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const <int, pw.TableColumnWidth>{
                0: pw.FlexColumnWidth(3.5),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2),
              },
              children: <pw.TableRow>[
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _teal),
                  children: <pw.Widget>[
                    _cell('Modèle / Produit', bold: true, color: PdfColors.white),
                    _cell('Qté', bold: true, color: PdfColors.white, align: pw.TextAlign.center),
                    _cell('Prix Unitaire', bold: true, color: PdfColors.white, align: pw.TextAlign.right),
                    _cell('Total', bold: true, color: PdfColors.white, align: pw.TextAlign.right),
                  ],
                ),
                ...order.items.asMap().entries.map(
                  (entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: idx % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                      ),
                      children: <pw.Widget>[
                        _cell(item.model, bold: true),
                        _cell('${item.qty}', align: pw.TextAlign.center),
                        _cell(formatFcfa(item.unitPrice), align: pw.TextAlign.right),
                        _cell(formatFcfa(item.total), bold: true, align: pw.TextAlign.right),
                      ],
                    );
                  },
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Financial Summary box
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 250,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  ),
                  child: pw.Column(
                    children: <pw.Widget>[
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total Commande:', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text(formatFcfa(order.totalAmount),
                              style: const pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Acomptes reçus:', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text(
                            formatFcfa(order.advanceAmount + order.paidTotal),
                            style: const pw.TextStyle(
                              fontSize: 10.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromInt(0xFF137333),
                            ),
                          ),
                        ],
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6),
                        child: pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'RESTE À PAYER:',
                            style: const pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: _teal,
                            ),
                          ),
                          pw.Text(
                            formatFcfa(order.reste),
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: order.reste > 0 ? const PdfColor.fromInt(0xFFC5221F) : _teal,
                            ),
                          ),
                        ],
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
                'Merci pour votre confiance commerciale ! — $shopName | Couture Pro',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
              ),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static Future<void> shareWholesaleInvoice({
    required String shopName,
    required WholesaleOrder order,
    String? logoUrl,
  }) async {
    final bytes = await buildWholesalePdf(
      shopName: shopName,
      order: order,
      logoBytes: await _logoBytes(logoUrl),
    );
    final safeName = order.merchantName.replaceAll(RegExp(r'[^\w]'), '_');
    final fileName = 'facture_gros_$safeName.pdf';
    await Printing.sharePdf(bytes: bytes, filename: fileName);
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
}
