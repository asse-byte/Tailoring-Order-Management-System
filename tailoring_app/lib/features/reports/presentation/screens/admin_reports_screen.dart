import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../../core/widgets/section_header.dart';
import 'package:provider/provider.dart';
import '../../../orders/data/orders_repository.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';
import '../../data/reports_pdf_builder.dart';

enum _Granularity { daily, weekly, monthly }

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  late DateTime _from;
  late DateTime _to;
  _Granularity _granularity = _Granularity.daily;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 29));
  }

  Future<void> _pickRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  Future<void> _exportPdf(List<TailoringOrder> orders) async {
    setState(() => _exporting = true);
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    try {
      final String shopName = context.read<ShopSettingsProvider>().shopName;
      final pdf = await ReportsPdfBuilder.build(
        orders: orders,
        from: _from,
        to: _to,
        shopName: shopName,
      );
      final String filename =
          'tailoring-report_${DateFormat('yyyyMMdd').format(_from)}_${DateFormat('yyyyMMdd').format(_to)}.pdf';
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: filename,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFr
              ? 'Impossible de générer le PDF : $e'
              : 'Could not build PDF: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    return Scaffold(
      appBar: AppBar(title: Text(loc.reports)),
      body: StreamBuilder<List<TailoringOrder>>(
        stream: OrdersRepository().watchAllOrders(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return LoadingShimmer.list(count: 4);
          }
          if (snap.hasError) {
            return EmptyState(
              title: loc.orderLoadError,
              message: snap.error.toString(),
              icon: Icons.error_outline,
            );
          }
          final List<TailoringOrder> all = snap.data ?? <TailoringOrder>[];
          final List<TailoringOrder> inRange = _filterByRange(all);
          return RefreshIndicator(
            onRefresh: () async =>
                await Future<void>.delayed(const Duration(milliseconds: 400)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
              children: <Widget>[
                _RangeBar(
                  from: _from,
                  to: _to,
                  onPick: _pickRange,
                  onExport: _exporting ? null : () => _exportPdf(inRange),
                  exporting: _exporting,
                ),
                const SizedBox(height: 20),
                _SummaryCards(orders: inRange),
                const SizedBox(height: 24),
                SectionHeader(title: loc.ordersBreakdown),
                const SizedBox(height: 12),
                _StatusPieCard(orders: inRange),
                const SizedBox(height: 20),
                SectionHeader(
                  title: loc.ordersOverTime,
                  action: SegmentedButton<_Granularity>(
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: <ButtonSegment<_Granularity>>[
                      ButtonSegment<_Granularity>(
                          value: _Granularity.daily,
                          label: Text(isFr ? 'Quotidien' : 'Daily')),
                      ButtonSegment<_Granularity>(
                          value: _Granularity.weekly,
                          label: Text(isFr ? 'Hebdo' : 'Weekly')),
                      ButtonSegment<_Granularity>(
                          value: _Granularity.monthly,
                          label: Text(isFr ? 'Mensuel' : 'Monthly')),
                    ],
                    selected: <_Granularity>{_granularity},
                    onSelectionChanged: (s) =>
                        setState(() => _granularity = s.first),
                  ),
                ),
                const SizedBox(height: 12),
                _OrdersOverTimeCard(
                  orders: inRange,
                  from: _from,
                  to: _to,
                  granularity: _granularity,
                ),
                const SizedBox(height: 20),
                SectionHeader(title: loc.mostOrderedGarmentsTitle),
                const SizedBox(height: 12),
                _TopGarmentsCard(orders: inRange),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  List<TailoringOrder> _filterByRange(List<TailoringOrder> orders) {
    final DateTime endOfDay =
        DateTime(_to.year, _to.month, _to.day, 23, 59, 59);
    return orders.where((o) {
      if (o.createdAt == null) return false;
      return !o.createdAt!.isBefore(_from) && !o.createdAt!.isAfter(endOfDay);
    }).toList(growable: false);
  }
}

// ---------- Range bar ----------

class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.from,
    required this.to,
    required this.onPick,
    required this.onExport,
    required this.exporting,
  });

  final DateTime from;
  final DateTime to;
  final VoidCallback onPick;
  final VoidCallback? onExport;
  final bool exporting;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    final lang = loc.locale.languageCode;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.event_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(isFr ? 'Période' : 'Date range',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  '${DateFormatter.date(from, locale: lang)}  →  ${DateFormatter.date(to, locale: lang)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: isFr ? 'Modifier la période' : 'Change range',
            onPressed: onPick,
          ),
          const SizedBox(width: 4),
          FilledButton.tonalIcon(
            icon: exporting
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(isFr ? 'Exporter' : 'Export'),
            onPressed: onExport,
          ),
        ],
      ),
    );
  }
}

// ---------- Summary cards ----------

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.orders});
  final List<TailoringOrder> orders;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    final NumberFormat money =
        NumberFormat.simpleCurrency(locale: loc.locale.toString());
    final int total = orders.length;
    final int completed =
        orders.where((o) => o.status == AppConstants.statusCompleted).length;
    final double revenue = orders
        .where(
            (o) => o.status == AppConstants.statusCompleted && o.price != null)
        .fold<double>(0.0, (s, o) => s + o.price!);
    final double avgTicket = completed == 0 ? 0 : revenue / completed;

    final List<({String label, String value, IconData icon, Color color})>
        cards = <({String label, String value, IconData icon, Color color})>[
      (
        label: loc.totalRevenue,
        value: money.format(revenue),
        icon: Icons.payments_outlined,
        color: AppColors.primary,
      ),
      (
        label: loc.orders,
        value: total.toString(),
        icon: Icons.receipt_long_outlined,
        color: AppColors.statusInProgress,
      ),
      (
        label: loc.statusCompleted,
        value: completed.toString(),
        icon: Icons.check_circle_outline,
        color: AppColors.statusCompleted,
      ),
      (
        label: isFr ? 'Panier moyen' : 'Avg ticket',
        value: money.format(avgTicket),
        icon: Icons.trending_up_rounded,
        color: AppColors.accentDark,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: cards
          .map((c) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: c.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(c.icon, color: c.color, size: 16),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(c.value,
                            style: Theme.of(context).textTheme.headlineSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(c.label,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ))
          .toList(growable: false),
    );
  }
}

// ---------- Status pie chart ----------

class _StatusPieCard extends StatelessWidget {
  const _StatusPieCard({required this.orders});
  final List<TailoringOrder> orders;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    final Map<String, int> counts = <String, int>{
      AppConstants.statusPending: 0,
      AppConstants.statusInProgress: 0,
      AppConstants.statusCompleted: 0,
      AppConstants.statusCancelled: 0,
    };
    for (final o in orders) {
      counts[o.status] = (counts[o.status] ?? 0) + 1;
    }
    final int total = orders.length;
    final List<({String key, String label, Color color, int count})> rows =
        <({String key, String label, Color color, int count})>[
      (
        key: AppConstants.statusPending,
        label: loc.statusPending,
        color: AppColors.statusPending,
        count: counts[AppConstants.statusPending]!
      ),
      (
        key: AppConstants.statusInProgress,
        label: loc.statusInProgress,
        color: AppColors.statusInProgress,
        count: counts[AppConstants.statusInProgress]!
      ),
      (
        key: AppConstants.statusCompleted,
        label: loc.statusCompleted,
        color: AppColors.statusCompleted,
        count: counts[AppConstants.statusCompleted]!
      ),
      (
        key: AppConstants.statusCancelled,
        label: loc.statusCancelled,
        color: AppColors.statusCancelled,
        count: counts[AppConstants.statusCancelled]!
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: total == 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text(isFr
                      ? 'Aucune donnée pour cette période.'
                      : 'No data for this range.')),
            )
          : Row(
              children: <Widget>[
                SizedBox(
                  height: 160,
                  width: 160,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 38,
                      sections: rows
                          .where((r) => r.count > 0)
                          .map((r) => PieChartSectionData(
                                color: r.color,
                                value: r.count.toDouble(),
                                radius: 36,
                                title: '${(r.count * 100 / total).round()}%',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ))
                          .toList(growable: false),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rows
                        .map((r) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    height: 10,
                                    width: 10,
                                    decoration: BoxDecoration(
                                      color: r.color,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(r.label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium),
                                  ),
                                  Text(
                                    r.count.toString(),
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ))
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------- Orders-over-time line chart ----------

class _OrdersOverTimeCard extends StatelessWidget {
  const _OrdersOverTimeCard({
    required this.orders,
    required this.from,
    required this.to,
    required this.granularity,
  });

  final List<TailoringOrder> orders;
  final DateTime from;
  final DateTime to;
  final _Granularity granularity;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    final lang = loc.locale.languageCode;
    final List<({DateTime bucketStart, int count})> buckets =
        _bucketize(orders, from, to, granularity);

    if (buckets.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(isFr
            ? 'Aucune donnée pour cette période.'
            : 'No data for this range.'),
      );
    }

    final double maxY = buckets
        .map((b) => b.count.toDouble())
        .fold<double>(0.0, (a, b) => a > b ? a : b);
    final double safeMaxY = (maxY < 4 ? 4 : maxY) + 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 12, 8),
      height: 220,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (buckets.length - 1).toDouble(),
          minY: 0,
          maxY: safeMaxY,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 0.6),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (safeMaxY / 4).ceilToDouble(),
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (buckets.length / 5).ceilToDouble().clamp(1, 99),
                getTitlesWidget: (v, _) {
                  final int i = v.toInt();
                  if (i < 0 || i >= buckets.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _bucketLabel(buckets[i].bucketStart, granularity, lang),
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textMuted),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: List<FlSpot>.generate(
                buckets.length,
                (i) => FlSpot(i.toDouble(), buckets[i].count.toDouble()),
              ),
              isCurved: true,
              barWidth: 2.4,
              color: AppColors.primary,
              dotData: FlDotData(
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 3,
                  color: AppColors.primary,
                  strokeColor: Colors.white,
                  strokeWidth: 1.4,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<({DateTime bucketStart, int count})> _bucketize(
    List<TailoringOrder> orders,
    DateTime from,
    DateTime to,
    _Granularity g,
  ) {
    DateTime floorDate(DateTime d) {
      switch (g) {
        case _Granularity.daily:
          return DateTime(d.year, d.month, d.day);
        case _Granularity.weekly:
          final DateTime day = DateTime(d.year, d.month, d.day);
          return day.subtract(Duration(days: day.weekday - 1));
        case _Granularity.monthly:
          return DateTime(d.year, d.month);
      }
    }

    DateTime nextDate(DateTime d) {
      switch (g) {
        case _Granularity.daily:
          return d.add(const Duration(days: 1));
        case _Granularity.weekly:
          return d.add(const Duration(days: 7));
        case _Granularity.monthly:
          return DateTime(d.year, d.month + 1);
      }
    }

    final Map<DateTime, int> bucketed = <DateTime, int>{};
    DateTime cursor = floorDate(from);
    final DateTime endFloor = floorDate(to);
    while (!cursor.isAfter(endFloor)) {
      bucketed[cursor] = 0;
      cursor = nextDate(cursor);
    }
    for (final TailoringOrder o in orders) {
      if (o.createdAt == null) continue;
      final DateTime k = floorDate(o.createdAt!);
      if (bucketed.containsKey(k)) {
        bucketed[k] = bucketed[k]! + 1;
      }
    }
    final List<DateTime> keys = bucketed.keys.toList(growable: false)..sort();
    return keys
        .map((k) => (bucketStart: k, count: bucketed[k]!))
        .toList(growable: false);
  }

  static String _bucketLabel(DateTime d, _Granularity g, String locale) {
    switch (g) {
      case _Granularity.daily:
      case _Granularity.weekly:
        return DateFormat('d MMM', locale).format(d);
      case _Granularity.monthly:
        return DateFormat('MMM yy', locale).format(d);
    }
  }
}

// ---------- Top garments bar chart ----------

class _TopGarmentsCard extends StatelessWidget {
  const _TopGarmentsCard({required this.orders});
  final List<TailoringOrder> orders;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    final Map<String, int> counts = <String, int>{};
    for (final o in orders) {
      counts[o.garmentType] = (counts[o.garmentType] ?? 0) + 1;
    }
    final List<MapEntry<String, int>> entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final List<MapEntry<String, int>> top = entries.take(6).toList();

    if (top.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(isFr
            ? 'Aucune donnée pour cette période.'
            : 'No data for this range.'),
      );
    }

    final double maxY = top
        .map((e) => e.value.toDouble())
        .fold<double>(0.0, (a, b) => a > b ? a : b);
    final double safeMaxY = (maxY < 4 ? 4 : maxY) + 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 12, 8),
      height: 240,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: BarChart(
        BarChartData(
          maxY: safeMaxY,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 0.6),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (safeMaxY / 4).ceilToDouble(),
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) {
                  final int i = v.toInt();
                  if (i < 0 || i >= top.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      loc.garmentName(top[i].key),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List<BarChartGroupData>.generate(top.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: top[i].value.toDouble(),
                  color: AppColors.primary,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
