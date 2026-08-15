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

  /// Live KPI tiles for the home dashboard. Manager-only (carries cash + debt).
  Future<DashboardKpis> dashboard() async {
    final dynamic res = await _api.get('/api/reports/dashboard');
    return DashboardKpis.fromJson(res as Map<String, dynamic>);
  }

  /// Delivered orders that still owe money — the debt-reminder list.
  Future<UnpaidOrdersPage> unpaidOrders({int limit = 50, int offset = 0}) async {
    final dynamic res = await _api
        .get('/api/reports/unpaid-orders', query: <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    });
    return UnpaidOrdersPage.fromJson(res as Map<String, dynamic>);
  }
}

/// Snapshot behind the dashboard tiles.
class DashboardKpis {
  final int ordersToday;
  final int paymentsToday;
  final int enAttente;
  final int enCours;
  final int termine;
  final int livre;
  final int debtOrders;
  final int debtClients;
  final int debtTotal;

  const DashboardKpis({
    required this.ordersToday,
    required this.paymentsToday,
    required this.enAttente,
    required this.enCours,
    required this.termine,
    required this.livre,
    required this.debtOrders,
    required this.debtClients,
    required this.debtTotal,
  });

  factory DashboardKpis.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> today =
        (j['today'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic> orders =
        (j['orders'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic> debt =
        (j['debt'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return DashboardKpis(
      ordersToday: today['orders_created'] as int? ?? 0,
      paymentsToday: today['payments_collected'] as int? ?? 0,
      enAttente: orders['en_attente'] as int? ?? 0,
      enCours: orders['en_cours'] as int? ?? 0,
      termine: orders['termine'] as int? ?? 0,
      livre: orders['livre'] as int? ?? 0,
      debtOrders: debt['orders_count'] as int? ?? 0,
      debtClients: debt['clients_count'] as int? ?? 0,
      debtTotal: debt['total'] as int? ?? 0,
    );
  }
}

/// One delivered-but-unpaid order, with what is needed for the reminder.
class UnpaidOrder {
  final String id;
  final String clientName;
  final String clientPhone;
  final int total;
  final int paid;
  final int reste;
  final String? deliveredDate;

  const UnpaidOrder({
    required this.id,
    required this.clientName,
    required this.clientPhone,
    required this.total,
    required this.paid,
    required this.reste,
    this.deliveredDate,
  });

  factory UnpaidOrder.fromJson(Map<String, dynamic> j) => UnpaidOrder(
        id: j['id']?.toString() ?? '',
        clientName: j['client_name']?.toString() ?? 'Client supprimé',
        clientPhone: j['client_phone']?.toString() ?? '',
        total: (j['total'] as num?)?.toInt() ?? 0,
        paid: (j['paid'] as num?)?.toInt() ?? 0,
        reste: (j['reste'] as num?)?.toInt() ?? 0,
        deliveredDate: j['delivered_date']?.toString(),
      );
}

class UnpaidOrdersPage {
  final List<UnpaidOrder> items;
  final int totalDue;
  final int totalCount;

  const UnpaidOrdersPage({
    required this.items,
    required this.totalDue,
    required this.totalCount,
  });

  factory UnpaidOrdersPage.fromJson(Map<String, dynamic> j) => UnpaidOrdersPage(
        items: ((j['items'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic e) => UnpaidOrder.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalDue: (j['total_due'] as num?)?.toInt() ?? 0,
        totalCount: (j['total_count'] as num?)?.toInt() ?? 0,
      );
}
