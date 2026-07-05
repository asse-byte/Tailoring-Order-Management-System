import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_constants.dart';
import '../../orders/domain/entities/order.dart';

/// Builds a clean, single-document PDF summary for a given date range.
///
/// Pure compute (no UI deps) so it's easy to test and re-use from
/// Settings export, scheduled jobs, etc.
class ReportsPdfBuilder {
  ReportsPdfBuilder._();

  static const PdfColor _primary = PdfColor.fromInt(0xFF006D6D);
  static const PdfColor _accent = PdfColor.fromInt(0xFFC9A84C);
  static const PdfColor _muted = PdfColor.fromInt(0xFF5B6470);
  static const PdfColor _border = PdfColor.fromInt(0xFFE3E6EA);

  static Future<pw.Document> build({
    required List<TailoringOrder> orders,
    required DateTime from,
    required DateTime to,
  }) async {
    final NumberFormat money = NumberFormat.simpleCurrency();
    final DateFormat dFmt = DateFormat('d MMM yyyy');

    // ---- compute aggregates ----
    final List<TailoringOrder> inRange = orders.where((o) {
      if (o.createdAt == null) return false;
      final DateTime endOfDay = DateTime(to.year, to.month, to.day, 23, 59, 59);
      return !o.createdAt!.isBefore(from) && !o.createdAt!.isAfter(endOfDay);
    }).toList(growable: false);

    final int total = inRange.length;
    final int pending = _countBy(inRange, AppConstants.statusPending);
    final int inProgress = _countBy(inRange, AppConstants.statusInProgress);
    final int completed = _countBy(inRange, AppConstants.statusCompleted);
    final int cancelled = _countBy(inRange, AppConstants.statusCancelled);
    final double revenue = inRange
        .where(
            (o) => o.status == AppConstants.statusCompleted && o.price != null)
        .fold(0.0, (sum, o) => sum + o.price!);

    // Top garments (max 5)
    final Map<String, int> byGarment = <String, int>{};
    for (final o in inRange) {
      byGarment[o.garmentType] = (byGarment[o.garmentType] ?? 0) + 1;
    }
    final List<MapEntry<String, int>> topGarments = byGarment.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ---- pdf ----
    final pw.Document doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context ctx) => <pw.Widget>[
          _header(from, to, dFmt),
          pw.SizedBox(height: 18),
          _summaryGrid(total, revenue, completed, money),
          pw.SizedBox(height: 18),
          _sectionTitle('Orders by status'),
          pw.SizedBox(height: 6),
          _statusTable(pending, inProgress, completed, cancelled),
          pw.SizedBox(height: 18),
          _sectionTitle('Top garment types'),
          pw.SizedBox(height: 6),
          if (topGarments.isEmpty)
            pw.Text('No data for this range.',
                style: const pw.TextStyle(color: _muted))
          else
            _topGarmentsTable(topGarments.take(5).toList()),
          pw.SizedBox(height: 18),
          _sectionTitle('Order list'),
          pw.SizedBox(height: 6),
          if (inRange.isEmpty)
            pw.Text('No orders in this range.',
                style: const pw.TextStyle(color: _muted))
          else
            _ordersTable(inRange, money, dFmt),
        ],
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(color: _muted, fontSize: 9),
          ),
        ),
      ),
    );
    return doc;
  }

  // ---------- pieces ----------

  static pw.Widget _header(DateTime from, DateTime to, DateFormat dFmt) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text('Tailoring Studio',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _primary,
                )),
            pw.SizedBox(height: 2),
            pw.Text('Business report',
                style: const pw.TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFF1F3F5),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: _border),
          ),
          child: pw.Text(
            '${dFmt.format(from)}  →  ${dFmt.format(to)}',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryGrid(
      int total, double revenue, int completed, NumberFormat money) {
    final List<({String label, String value})> cells =
        <({String label, String value})>[
      (label: 'Total orders', value: total.toString()),
      (label: 'Completed', value: completed.toString()),
      (label: 'Revenue', value: money.format(revenue)),
    ];
    return pw.Row(
      children: cells
          .map((c) => pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.only(right: 8),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _border),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(c.label,
                          style:
                              const pw.TextStyle(fontSize: 9, color: _muted)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        c.value,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(growable: false),
    );
  }

  static pw.Widget _sectionTitle(String text) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 1.4)),
        ),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      );

  static pw.Widget _statusTable(int p, int ip, int c, int x) {
    return pw.TableHelper.fromTextArray(
      headers: const <String>['Status', 'Count'],
      data: <List<String>>[
        <String>['Pending', p.toString()],
        <String>['In Progress', ip.toString()],
        <String>['Completed', c.toString()],
        <String>['Cancelled', x.toString()],
      ],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: const <int, pw.Alignment>{
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
      },
      headerDecoration:
          const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F3F5)),
      border: pw.TableBorder.all(color: _border, width: 0.6),
    );
  }

  static pw.Widget _topGarmentsTable(List<MapEntry<String, int>> items) {
    return pw.TableHelper.fromTextArray(
      headers: const <String>['Garment', 'Orders'],
      data: items
          .map((e) => <String>[e.key, e.value.toString()])
          .toList(growable: false),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: const <int, pw.Alignment>{
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
      },
      headerDecoration:
          const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F3F5)),
      border: pw.TableBorder.all(color: _border, width: 0.6),
    );
  }

  static pw.Widget _ordersTable(
      List<TailoringOrder> orders, NumberFormat money, DateFormat dFmt) {
    final List<List<String>> rows = orders
        .take(80)
        .map<List<String>>((o) => <String>[
              o.createdAt != null ? dFmt.format(o.createdAt!) : '—',
              o.customerName,
              o.garmentType,
              _statusLabel(o.status),
              o.price != null ? money.format(o.price!) : '—',
            ])
        .toList(growable: false);
    return pw.TableHelper.fromTextArray(
      headers: const <String>[
        'Placed',
        'Customer',
        'Garment',
        'Status',
        'Price'
      ],
      data: rows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F3F5)),
      border: pw.TableBorder.all(color: _border, width: 0.6),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FixedColumnWidth(70),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1.4),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FixedColumnWidth(60),
      },
      cellAlignments: const <int, pw.Alignment>{
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerRight,
      },
    );
  }

  static int _countBy(List<TailoringOrder> list, String status) =>
      list.where((o) => o.status == status).length;

  static String _statusLabel(String s) {
    switch (s) {
      case AppConstants.statusPending:
        return 'Pending';
      case AppConstants.statusInProgress:
        return 'In Progress';
      case AppConstants.statusCompleted:
        return 'Completed';
      case AppConstants.statusCancelled:
        return 'Cancelled';
    }
    return s;
  }
}
