import '../../../core/network/api_client.dart';

class FinanceSummary {
  final String from;
  final String to;
  final int monthsCounted;
  final int salesRevenue;
  final int ordersRevenue;
  final int totalRevenue;
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
    required this.totalRevenue,
    required this.tailorWages,
    required this.salaries,
    required this.expenses,
    required this.totalCosts,
    required this.netProfit,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) {
    final rev = json['revenue'] as Map<String, dynamic>;
    final cos = json['costs'] as Map<String, dynamic>;
    return FinanceSummary(
      from: json['from'] as String,
      to: json['to'] as String,
      monthsCounted: json['months_counted'] as int,
      salesRevenue: rev['sales'] as int,
      ordersRevenue: rev['orders'] as int,
      totalRevenue: rev['total'] as int,
      tailorWages: cos['tailor_wages'] as int,
      salaries: cos['salaries'] as int,
      expenses: cos['expenses'] as int,
      totalCosts: cos['total'] as int,
      netProfit: json['net_profit'] as int,
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
      id: json['id'] as String,
      reason: json['reason'] as String,
      amount: json['amount'] as int,
      spentAt: json['spent_at'] as String,
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
      id: json['id'] as String,
      kind: json['kind'] as String,
      itemName: json['item_name'] as String? ?? '',
      qty: json['qty'] as int,
      price: json['price'] as int,
      total: json['total'] as int,
      soldAt: json['sold_at'] as String,
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
