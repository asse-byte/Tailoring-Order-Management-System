import '../../../core/network/api_client.dart';

class FinanceSummary {
  final String from;
  final String to;
  final int monthsCounted;
  final int salesRevenue;
  final int ordersRevenue;
  final int wholesaleRevenue;
  final int totalRevenue;
  final int costOfGoodsSold;
  final int tailorWages;
  final int salaries;
  final int expenses;
  final int totalCosts;
  final int netProfit;

  const FinanceSummary({
    required this.from,
    required this.to,
    required this.monthsCounted,
    required this.salesRevenue,
    required this.ordersRevenue,
    required this.wholesaleRevenue,
    required this.totalRevenue,
    required this.costOfGoodsSold,
    required this.tailorWages,
    required this.salaries,
    required this.expenses,
    required this.totalCosts,
    required this.netProfit,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) {
    final rev =
        (json['revenue'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final cos = (json['costs'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return FinanceSummary(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      monthsCounted: (json['months_counted'] as num?)?.toInt() ?? 1,
      salesRevenue: (rev['sales'] as num?)?.toInt() ?? 0,
      ordersRevenue: (rev['orders'] as num?)?.toInt() ?? 0,
      wholesaleRevenue: (rev['wholesale'] as num?)?.toInt() ?? 0,
      totalRevenue: (rev['total'] as num?)?.toInt() ?? 0,
      // Cost of the goods sold. It was missing from this model entirely, so the
      // cost rows on screen (wages + salaries + expenses) never added up to the
      // "total des dépenses" the same screen printed underneath them.
      costOfGoodsSold: (cos['cost_of_goods_sold'] as num?)?.toInt() ?? 0,
      tailorWages: (cos['tailor_wages'] as num?)?.toInt() ?? 0,
      salaries: (cos['salaries'] as num?)?.toInt() ?? 0,
      expenses: (cos['expenses'] as num?)?.toInt() ?? 0,
      totalCosts: (cos['total'] as num?)?.toInt() ?? 0,
      netProfit: (json['net_profit'] as num?)?.toInt() ?? 0,
    );
  }
}

class Expense {
  final String id;
  final String reason;
  final int amount;
  final String spentAt;

  const Expense({
    required this.id,
    required this.reason,
    required this.amount,
    required this.spentAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      spentAt: json['spent_at']?.toString() ?? '',
    );
  }
}

class SaleItem {
  final String id;
  final String kind; // 'produit' | 'pret-a-porter'
  final String itemName;
  final int qty;
  final int price;
  final int total;
  final String soldAt;
  final bool voided;

  const SaleItem({
    required this.id,
    required this.kind,
    required this.itemName,
    required this.qty,
    required this.price,
    required this.total,
    required this.soldAt,
    required this.voided,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      itemName: json['item_name'] as String? ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      soldAt: json['sold_at']?.toString() ?? '',
      voided: json['voided'] as bool? ?? false,
    );
  }
}

/// A generic detail line shown in a finance category table.
class FinanceRow {
  final String title;
  final String subtitle;
  final int amount;
  const FinanceRow({
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  factory FinanceRow.fromJson(Map<String, dynamic> json) {
    final String date = (json['on_date'] as String?) ?? '';
    final String detail = (json['detail'] as String?) ?? '';
    return FinanceRow(
      title: (json['title'] as String?) ?? '—',
      subtitle: detail.isEmpty ? date : '$date · $detail',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The operations behind one KPI card, with the subtotal the SERVER computed.
///
/// The screen used to add these up itself by folding the rows of a paginated
/// list endpoint — 20 orders, 50 sales, 50 expenses. On a busy month it printed
/// a subtotal covering only the first page, right under a card holding the true
/// figure: two different numbers for the same thing on one screen. [total] now
/// always covers the whole period, whatever [rows] happens to hold.
class FinanceCategory {
  final int total;
  final List<FinanceRow> rows;
  final bool truncated;

  const FinanceCategory({
    required this.total,
    required this.rows,
    required this.truncated,
  });

  static const FinanceCategory empty =
      FinanceCategory(total: 0, rows: <FinanceRow>[], truncated: false);

  factory FinanceCategory.fromJson(Map<String, dynamic>? json) {
    if (json == null) return empty;
    return FinanceCategory(
      total: (json['total'] as num?)?.toInt() ?? 0,
      rows: ((json['rows'] as List?) ?? <dynamic>[])
          .map((e) => FinanceRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      truncated: (json['truncated'] as bool?) ?? false,
    );
  }
}

/// The four detail tables of the Finances screen, in one call.
class FinanceDetail {
  final FinanceCategory orders;
  final FinanceCategory sales;
  final FinanceCategory wages;
  final FinanceCategory expenses;

  const FinanceDetail({
    required this.orders,
    required this.sales,
    required this.wages,
    required this.expenses,
  });

  factory FinanceDetail.fromJson(Map<String, dynamic> json) => FinanceDetail(
        orders: FinanceCategory.fromJson(json['orders'] as Map<String, dynamic>?),
        sales: FinanceCategory.fromJson(json['sales'] as Map<String, dynamic>?),
        wages: FinanceCategory.fromJson(json['wages'] as Map<String, dynamic>?),
        expenses:
            FinanceCategory.fromJson(json['expenses'] as Map<String, dynamic>?),
      );
}

class FinanceRepository {
  FinanceRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<FinanceSummary> getSummary(
      {required String from, required String to}) async {
    final dynamic res = await _api.get('/api/finance/summary', query: {
      'from': from,
      'to': to,
    });
    return FinanceSummary.fromJson(res as Map<String, dynamic>);
  }

  // ---- period-filtered detail rows (each finance category) ----------------
  //
  // ONE call, and the subtotal comes back with the rows. The four separate
  // fetchers this replaced each hit a paginated list endpoint and left the
  // screen to fold the rows into a subtotal, which therefore covered only the
  // first page — 20 orders, 50 sales, 50 expenses. See FinanceCategory.
  Future<FinanceDetail> detail(
      {required String from, required String to}) async {
    final dynamic res =
        await _api.get('/api/finance/detail', query: {'from': from, 'to': to});
    return FinanceDetail.fromJson(res as Map<String, dynamic>);
  }

  Future<List<Expense>> listExpenses() async {
    final dynamic res = await _api.get('/api/expenses');
    return (res['items'] as List)
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Expense> createExpense({
    required String reason,
    required int amount,
    required String spentAt,
  }) async {
    final dynamic res = await _api.post('/api/expenses', body: {
      'reason': reason,
      'amount': amount,
      'spent_at': spentAt,
    });
    return Expense.fromJson(res as Map<String, dynamic>);
  }

  Future<void> correctExpense(
    String id, {
    required int newAmount,
    required String reason,
  }) async {
    await _api.post('/api/expenses/$id/corrections', body: {
      'new_amount': newAmount,
      'reason': reason,
    });
  }

  Future<List<SaleItem>> listSales() async {
    final dynamic res = await _api.get('/api/sales');
    return (res['items'] as List)
        .map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> correctSale(
    String id, {
    required int newQty,
    required String reason,
  }) async {
    await _api.post('/api/sales/$id/corrections', body: {
      'new_qty': newQty,
      'reason': reason,
    });
  }
}
