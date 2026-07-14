import '../../../core/network/api_client.dart';

class TopTailor {
  final String tailorId;
  final String tailorName;
  final int piecesTotal;
  final int amountTotal;

  const TopTailor({
    required this.tailorId,
    required this.tailorName,
    required this.piecesTotal,
    required this.amountTotal,
  });

  factory TopTailor.fromJson(Map<String, dynamic> j) => TopTailor(
        tailorId: j['tailor_id'] as String,
        tailorName: j['tailor_name'] as String? ?? '',
        piecesTotal: j['pieces_total'] as int? ?? 0,
        amountTotal: j['amount_total'] as int? ?? 0,
      );
}

/// Full business report for a period — the item-8 payload. Manager-only.
class ReportSummary {
  final String from;
  final String to;
  final int salesRevenue;
  final int ordersRevenue;
  final int totalRevenue;
  final int cogs;
  final int tailorWages;
  final int salaries;
  final int expenses;
  final int totalCosts;
  final int netProfit;
  final int newClients;
  final int servedClients;
  final int ordersCreated;
  final int ordersDelivered;
  final int ordersActive;
  final int productsSoldUnits;
  final List<TopTailor> topTailors;

  const ReportSummary({
    required this.from,
    required this.to,
    required this.salesRevenue,
    required this.ordersRevenue,
    required this.totalRevenue,
    required this.cogs,
    required this.tailorWages,
    required this.salaries,
    required this.expenses,
    required this.totalCosts,
    required this.netProfit,
    required this.newClients,
    required this.servedClients,
    required this.ordersCreated,
    required this.ordersDelivered,
    required this.ordersActive,
    required this.productsSoldUnits,
    required this.topTailors,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> j) {
    final rev = j['revenue'] as Map<String, dynamic>;
    final cost = j['costs'] as Map<String, dynamic>;
    final cli = j['clients'] as Map<String, dynamic>;
    final ord = j['orders'] as Map<String, dynamic>;
    return ReportSummary(
      from: j['from'] as String,
      to: j['to'] as String,
      salesRevenue: rev['sales'] as int? ?? 0,
      ordersRevenue: rev['orders'] as int? ?? 0,
      totalRevenue: rev['total'] as int? ?? 0,
      cogs: cost['cost_of_goods_sold'] as int? ?? 0,
      tailorWages: cost['tailor_wages'] as int? ?? 0,
      salaries: cost['salaries'] as int? ?? 0,
      expenses: cost['expenses'] as int? ?? 0,
      totalCosts: cost['total'] as int? ?? 0,
      netProfit: j['net_profit'] as int? ?? 0,
      newClients: cli['new'] as int? ?? 0,
      servedClients: cli['served'] as int? ?? 0,
      ordersCreated: ord['created'] as int? ?? 0,
      ordersDelivered: ord['delivered'] as int? ?? 0,
      ordersActive: ord['active'] as int? ?? 0,
      productsSoldUnits: j['products_sold_units'] as int? ?? 0,
      topTailors: (j['top_tailors'] as List? ?? [])
          .map((e) => TopTailor.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReportsRepository {
  ReportsRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;
  final ApiClient _api;

  static String _d(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<ReportSummary> summary(DateTime from, DateTime to) async {
    final dynamic res = await _api
        .get('/api/reports/summary?from=${_d(from)}&to=${_d(to)}');
    return ReportSummary.fromJson(res as Map<String, dynamic>);
  }
}
