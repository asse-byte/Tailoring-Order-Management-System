import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
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
    try {
      final data = await rootBundle.load('assets/logo.jpeg');
      return data.buffer.asUint8List();
    } catch (_) {}
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
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Row(
              children: <pw.Widget>[
                pw.Container(
                  width: 50,
                  height: 50,
                  decoration: pw.BoxDecoration(
                    color: _teal,
                    shape: pw.BoxShape.circle,
                    image: logo != null ? pw.DecorationImage(image: logo, fit: pw.BoxFit.cover) : null,
                  ),
                  alignment: pw.Alignment.center,
                  child: logo == null
                      ? pw.Text('R', style: const pw.TextStyle(color: PdfColors.white, fontSize: 26, fontWeight: pw.FontWeight.bold))
                      : null,
                ),
                pw.SizedBox(width: 12),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(shopName, style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _teal)),
                    pw.Text('Distribution En Gros / Prêt-à-Porter', style: const pw.TextStyle(fontSize: 10, color: _gold)),
                  ],
                ),
                pw.Spacer(),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: <pw.Widget>[
                    pw.Text('FACTURE DE VENTE EN GROS', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('N° GROS-${order.id.substring(0, 6).toUpperCase()}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.Divider(color: _teal, thickness: 1.5),
            pw.SizedBox(height: 12),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text('Client / Commerçant:', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _teal)),
                    pw.Text(order.merchantName, style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    if (order.merchantPhone.isNotEmpty) pw.Text('Tél: ${order.merchantPhone}'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: <pw.Widget>[
                    pw.Text('Date commande: ${order.orderDate}'),
                    pw.Text('Statut: ${order.status == 'livre' ? 'Livré' : 'En cours'}', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Items table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: <pw.TableRow>[
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _teal),
                  children: <pw.Widget>[
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Modèle / Produit', style: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qté', style: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Prix Unitaire', style: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total', style: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  ],
                ),
                ...order.items.map(
                  (item) => pw.TableRow(
                    children: <pw.Widget>[
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(item.model)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${item.qty}', textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(formatFcfa(item.unitPrice), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(formatFcfa(item.total), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Financial Summary box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF2F8F8),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: _teal),
              ),
              child: pw.Column(
                children: <pw.Widget>[
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Total Commande:'),
                    pw.Text(formatFcfa(order.totalAmount), style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ]),
                  pw.SizedBox(height: 4),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Acompte payé:'),
                    pw.Text(formatFcfa(order.advanceAmount + order.paidTotal), style: const pw.TextStyle(color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
                  ]),
                  pw.Divider(),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('RESTE À PAYER:', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(formatFcfa(order.reste), style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _teal)),
                  ]),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Center(child: pw.Text('Merci pour votre confiance !', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
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
    await Printing.sharePdf(bytes: bytes, filename: 'facture_gros_${safeName}.pdf');
  }
}
