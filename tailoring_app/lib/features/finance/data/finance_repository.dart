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
    final rev = (json['revenue'] as Map<String, dynamic>?) ?? <String, dynamic>{};
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
}

class FinanceRepository {
  FinanceRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<FinanceSummary> getSummary({required String from, required String to}) async {
    final dynamic res = await _api.get('/api/finance/summary', query: {
      'from': from,
      'to': to,
    });
    return FinanceSummary.fromJson(res as Map<String, dynamic>);
  }

  // ---- period-filtered detail rows (each finance category) ----------------

  Future<List<FinanceRow>> expenseRows({required String from, required String to}) async {
    final dynamic res = await _api.get('/api/expenses', query: {'from': from, 'to': to});
    return (res['items'] as List)
        .map((e) => e as Map<String, dynamic>)
        .where((e) => (e['voided'] as bool? ?? false) == false)
        .map((e) => FinanceRow(
              title: (e['reason'] as String?) ?? '—',
              subtitle: (e['spent_at'] as String?) ?? '',
              amount: (e['amount'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  Future<List<FinanceRow>> saleRows({required String from, required String to}) async {
    final dynamic res = await _api.get('/api/sales', query: {'from': from, 'to': to});
    return (res['items'] as List)
        .map((e) => e as Map<String, dynamic>)
        .where((e) => (e['voided'] as bool? ?? false) == false)
        .map((e) => FinanceRow(
              title: '${e['item_name'] ?? ''} ×${e['qty'] ?? 1}',
              subtitle: ((e['sold_at'] as String?) ?? '').split('T').first,
              amount: (e['total'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  Future<List<FinanceRow>> tailorWageRows({required String from, required String to}) async {
    final dynamic res = await _api.get('/api/tailor-entries', query: {'from': from, 'to': to});
    return (res['items'] as List).map((e) => e as Map<String, dynamic>).map((e) {
      final garment = (e['garment_type'] as String?) ?? '';
      final name = (e['tailor_name'] as String?) ?? '';
      return FinanceRow(
        title: garment.isEmpty ? name : '$name — $garment',
        subtitle: '${e['entry_date'] ?? ''} · ${e['pieces_count'] ?? 0} pc',
        amount: (e['amount'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<List<FinanceRow>> deliveredOrderRows({required String from, required String to}) async {
    final dynamic res = await _api.get('/api/orders',
        query: {'status': 'livre', 'from': from, 'to': to});
    return (res['items'] as List).map((e) => e as Map<String, dynamic>).map((e) {
      return FinanceRow(
        title: (e['client_name'] as String?) ?? 'Client',
        subtitle: 'Livré ${((e['delivered_date'] as String?) ?? '').split('T').first}',
        amount: (e['total'] as num?)?.toInt() ?? (e['price'] as num?)?.toInt() ?? 0,
      );
    }).toList();
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
