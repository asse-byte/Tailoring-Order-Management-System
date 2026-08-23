import '../../../core/network/api_client.dart';
import '../domain/product_category.dart';

/// One line of a completed sale, as the API gives it back.
class SaleReceiptLine {
  const SaleReceiptLine({
    required this.id,
    required this.kind,
    required this.itemName,
    required this.qty,
    required this.unitPrice,
    required this.total,
    this.voided = false,
    this.corrected = false,
  });

  final String id;
  final String kind;
  final String itemName;
  final int qty;
  final int unitPrice;
  final int total;
  final bool voided;
  final bool corrected;

  factory SaleReceiptLine.fromJson(Map<String, dynamic> j) => SaleReceiptLine(
        id: j['id']?.toString() ?? '',
        kind: j['kind']?.toString() ?? 'produit',
        itemName: j['item_name']?.toString() ?? '',
        qty: (j['qty'] as num?)?.toInt() ?? 0,
        unitPrice: (j['unit_price'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        voided: j['voided'] as bool? ?? false,
        corrected: j['corrected'] as bool? ?? false,
      );
}

/// A finished trip to the till: the client (when given) plus every line.
class SaleReceipt {
  const SaleReceipt({
    required this.id,
    required this.total,
    required this.itemsCount,
    required this.soldAt,
    this.clientId,
    this.clientName,
    this.clientPhone,
    this.note,
    this.voided = false,
    this.lines = const <SaleReceiptLine>[],
  });

  final String id;
  final int total;
  final int itemsCount;
  final String soldAt;
  final String? clientId;
  final String? clientName;
  final String? clientPhone;
  final String? note;
  final bool voided;
  final List<SaleReceiptLine> lines;

  factory SaleReceipt.fromJson(Map<String, dynamic> j) => SaleReceipt(
        id: j['id']?.toString() ?? '',
        total: (j['total'] as num?)?.toInt() ?? 0,
        itemsCount: (j['items_count'] as num?)?.toInt() ?? 0,
        soldAt: j['sold_at']?.toString() ?? '',
        clientId: j['client_id']?.toString(),
        // The list view exposes client_name; the create response echoes the
        // snapshot column instead, so accept either.
        clientName: (j['client_name'] ?? j['client_name_snapshot'])?.toString(),
        clientPhone: (j['client_phone'] ?? j['client_phone_snapshot'])?.toString(),
        note: j['note']?.toString(),
        voided: j['voided'] as bool? ?? false,
        lines: (j['lines'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => SaleReceiptLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Counter sales and the shop's product types.
///
/// Creating a sale is open to both roles; listing sales back is manager-only
/// (a list of receipts is a list of takings), so the history calls throw for
/// the secretary — the screens that use them are behind the manager guard.
class SalesRepository {
  SalesRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  // ---- product types -------------------------------------------------------

  Future<List<ProductCategory>> listCategories() async {
    final dynamic res = await _api.get('/api/product-categories');
    return (res['items'] as List)
        .map((e) => ProductCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProductCategory> createCategory({
    required String label,
    String? icon,
    int? sortOrder,
  }) async {
    final dynamic res = await _api.post('/api/product-categories', body: {
      'label': label,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
    return ProductCategory.fromJson(res as Map<String, dynamic>);
  }

  Future<ProductCategory> updateCategory(
    String id, {
    String? label,
    String? icon,
    int? sortOrder,
  }) async {
    final dynamic res = await _api.put('/api/product-categories/$id', body: {
      if (label != null) 'label': label,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
    return ProductCategory.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String id) =>
      _api.delete('/api/product-categories/$id');

  // ---- selling -------------------------------------------------------------

  /// Sell a whole basket as ONE receipt. Every line succeeds or none does.
  Future<SaleReceipt> checkout({
    required List<Map<String, dynamic>> lines,
    String? clientId,
    String? clientName,
    String? clientPhone,
    String? note,
  }) async {
    final dynamic res = await _api.post('/api/sales/receipts', body: {
      'lines': lines,
      if (clientId != null) 'client_id': clientId,
      if (clientName != null && clientName.isNotEmpty) 'client_name': clientName,
      if (clientPhone != null && clientPhone.isNotEmpty) 'client_phone': clientPhone,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return SaleReceipt.fromJson(res as Map<String, dynamic>);
  }

  // ---- history (manager only) ---------------------------------------------

  Future<({List<SaleReceipt> items, int totalAmount, int totalCount})> listReceipts({
    String? from,
    String? to,
    String? clientId,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final dynamic res = await _api.get('/api/sales/receipts', query: {
      'limit': '$limit',
      'offset': '$offset',
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (clientId != null) 'client_id': clientId,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return (
      items: (res['items'] as List)
          .map((e) => SaleReceipt.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalAmount: (res['total_amount'] as num?)?.toInt() ?? 0,
      totalCount: (res['total_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<SaleReceipt> getReceipt(String id) async {
    final dynamic res = await _api.get('/api/sales/receipts/$id');
    return SaleReceipt.fromJson(res as Map<String, dynamic>);
  }

  /// Change or cancel a line of a completed sale.
  ///
  /// Sales are append-only, so this never edits the original row: it writes a
  /// correction with a mandatory reason, and the stock difference goes back on
  /// the shelf in the same transaction. To the seller it just looks like
  /// fixing a mistake.
  Future<void> correctLine(
    String saleId, {
    int? newQty,
    bool? voided,
    required String reason,
  }) =>
      _api.post('/api/sales/$saleId/corrections', body: {
        if (newQty != null) 'new_qty': newQty,
        if (voided != null) 'voided': voided,
        'reason': reason,
      });
}
