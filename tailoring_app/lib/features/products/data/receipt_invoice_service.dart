import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/pdf_fonts.dart';
import 'sales_repository.dart';

const PdfColor _teal = PdfColor.fromInt(0xFF0F5257);
const PdfColor _gold = PdfColor.fromInt(0xFFC9A227);
const PdfColor _ink = PdfColor.fromInt(0xFF1A1A1A);
const PdfColor _muted = PdfColor.fromInt(0xFF6B6B6B);
const PdfColor _rule = PdfColor.fromInt(0xFFE0DED9);

/// The single invoice for one trip to the till.
///
/// Available to BOTH roles: it shows only what the customer just paid in front
/// of the seller — never a purchase cost or a margin.
///
/// Sharing goes through `Printing.sharePdf`, i.e. the operating system's own
/// share sheet, which is where WhatsApp appears. The app deliberately does NOT
/// try to hand WhatsApp a file directly: no mobile OS supports attaching a file
/// to a specific chat from outside, so anything that claimed to would be
/// lying about having sent it.
class ReceiptInvoiceService {
  const ReceiptInvoiceService();

  Future<void> shareInvoice(
    SaleReceipt receipt, {
    required String shopName,
    String? logoUrl,
    String? promoLink,
  }) async {
    final Uint8List bytes = await build(
      receipt,
      shopName: shopName,
      logoUrl: logoUrl,
      promoLink: promoLink,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'facture-${_shortId(receipt.id)}.pdf',
    );
  }

  static String _shortId(String id) =>
      id.replaceAll('-', '').substring(0, id.length >= 8 ? 8 : id.length).toUpperCase();

  Future<Uint8List> build(
    SaleReceipt receipt, {
    required String shopName,
    String? logoUrl,
    String? promoLink,
  }) async {
    final pw.MemoryImage? logo = await _loadLogo(logoUrl);
    final doc = pw.Document(theme: await PdfFonts.theme());
    final display = await PdfFonts.display();

    // Voided lines are shown struck through rather than hidden: a customer
    // comparing their copy with the shop's must see the same lines.
    final live = receipt.lines.where((l) => !l.voided).toList();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: <pw.Widget>[
            _header(shopName, logo, display, receipt),
            pw.SizedBox(height: 22),
            _clientBlock(receipt),
            pw.SizedBox(height: 18),
            _table(receipt),
            pw.SizedBox(height: 14),
            _total(receipt, live.length),
            pw.Spacer(),
            _footer(shopName, promoLink),
          ],
        ),
      ),
    );
    return doc.save();
  }

  Future<pw.MemoryImage?> _loadLogo(String? logoUrl) async {
    if (logoUrl == null || logoUrl.isEmpty) return null;
    try {
      final String url =
          logoUrl.startsWith('http') ? logoUrl : '${ApiClient.baseUrl}$logoUrl';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) return pw.MemoryImage(res.bodyBytes);
    } catch (_) {/* the invoice prints fine without it */}
    return null;
  }

  pw.Widget _header(
    String shopName,
    pw.MemoryImage? logo,
    pw.Font display,
    SaleReceipt receipt,
  ) =>
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Container(
            width: 54,
            height: 54,
            decoration: pw.BoxDecoration(
              color: logo == null ? _teal : null,
              borderRadius: pw.BorderRadius.circular(27),
              image: logo == null
                  ? null
                  : pw.DecorationImage(image: logo, fit: pw.BoxFit.cover),
            ),
            alignment: pw.Alignment.center,
            child: logo == null
                ? pw.Text(
                    shopName.isNotEmpty ? shopName.substring(0, 1).toUpperCase() : 'R',
                    style: pw.TextStyle(
                        font: display,
                        fontSize: 26,
                        color: PdfColors.white),
                  )
                : null,
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(shopName,
                    style: pw.TextStyle(
                        font: display, fontSize: 26, color: _teal)),
                pw.SizedBox(height: 2),
                pw.Container(width: 46, height: 2, color: _gold),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              pw.Text('FACTURE',
                  style: const pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                      letterSpacing: 2)),
              pw.SizedBox(height: 3),
              pw.Text('N° ${_shortId(receipt.id)}',
                  style: const pw.TextStyle(fontSize: 10, color: _muted)),
              pw.Text(_dayOf(receipt.soldAt),
                  style: const pw.TextStyle(fontSize: 10, color: _muted)),
            ],
          ),
        ],
      );

  static String _dayOf(String raw) {
    if (raw.isEmpty) return '';
    final DateTime? d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  pw.Widget _clientBlock(SaleReceipt receipt) {
    final String name = (receipt.clientName ?? '').trim();
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF7F6F3),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text('CLIENT',
                    style: const pw.TextStyle(fontSize: 8, color: _muted)),
                pw.SizedBox(height: 3),
                pw.Text(name.isEmpty ? 'Client de passage' : name,
                    style: const pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                if ((receipt.clientPhone ?? '').isNotEmpty)
                  pw.Text(receipt.clientPhone!,
                      style: const pw.TextStyle(fontSize: 10, color: _muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _table(SaleReceipt receipt) {
    pw.Widget cell(String text,
            {bool bold = false, PdfColor color = _ink, bool right = false, bool strike = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          child: pw.Text(
            text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              decoration: strike ? pw.TextDecoration.lineThrough : null,
            ),
          ),
        );

    return pw.Table(
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(5),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2.2),
      },
      children: <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _teal),
          children: <pw.Widget>[
            cell('Article', bold: true, color: PdfColors.white),
            cell('Qté', bold: true, color: PdfColors.white, right: true),
            cell('Prix', bold: true, color: PdfColors.white, right: true),
            cell('Total', bold: true, color: PdfColors.white, right: true),
          ],
        ),
        for (final line in receipt.lines)
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _rule, width: .5)),
            ),
            children: <pw.Widget>[
              cell(line.voided ? '${line.itemName} (annulé)' : line.itemName,
                  strike: line.voided,
                  color: line.voided ? _muted : _ink),
              cell('${line.qty}', right: true, strike: line.voided),
              cell(formatFcfa(line.unitPrice), right: true, strike: line.voided),
              cell(formatFcfa(line.voided ? 0 : line.total),
                  right: true, bold: !line.voided, strike: line.voided),
            ],
          ),
      ],
    );
  }

  pw.Widget _total(SaleReceipt receipt, int liveLines) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: <pw.Widget>[
          pw.Container(
            width: 230,
            padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: _teal,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Text('TOTAL PAYÉ',
                    style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(formatFcfa(receipt.total),
                    style: const pw.TextStyle(
                        fontSize: 15,
                        color: _gold,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      );

  pw.Widget _footer(String shopName, String? promoLink) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: <pw.Widget>[
          pw.Container(height: .5, color: _rule),
          pw.SizedBox(height: 8),
          pw.Text('Merci de votre visite — $shopName',
              style: const pw.TextStyle(fontSize: 9, color: _muted)),
          if (promoLink != null && promoLink.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 3),
            pw.UrlLink(
              destination: promoLink,
              child: pw.Text(promoLink,
                  style: const pw.TextStyle(fontSize: 8, color: _teal)),
            ),
          ],
        ],
      );
}
