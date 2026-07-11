import '../../../core/network/api_client.dart';
import '../domain/entities/order.dart';

/// A line to send when creating/adding to an order.
class NewOrderItem {
  const NewOrderItem({
    required this.garmentType,
    required this.quantity,
    required this.unitPrice,
  });
  final String garmentType;
  final int quantity;
  final int unitPrice;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'garment_type': garmentType,
        'quantity': quantity,
        'unit_price': unitPrice,
      };
}

/// REST repository for /api/orders. Statuses and money use the API values
/// directly (en_attente/en_cours/termine/livre, FCFA ints).
class OrdersRepository {
  OrdersRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<TailoringOrder>> list({
    String? status,
    String? clientId,
    DateTime? from,
    DateTime? to,
    int limit = 50,
    int offset = 0,
  }) async {
    final dynamic res = await _api.get('/api/orders', query: <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (status != null) 'status': status,
      if (clientId != null) 'client_id': clientId,
      if (from != null) 'from': _dateStr(from),
      if (to != null) 'to': _dateStr(to),
    });
    return (res['items'] as List)
        .map((e) => TailoringOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TailoringOrder> getById(String id) async =>
      TailoringOrder.fromJson(
          await _api.get('/api/orders/$id') as Map<String, dynamic>);

  /// Creates an order with one or more line items. The server snapshots the
  /// client's measurements when none are provided.
  Future<TailoringOrder> create({
    required String clientId,
    required List<NewOrderItem> items,
    String? tailorId,
    String fabric = '',
    int advance = 0,
    String? status,
    DateTime? startDate,
    DateTime? expectedDate,
    String? notes,
  }) async {
    final dynamic res = await _api.post('/api/orders', body: {
      'client_id': clientId,
      'items': items.map((e) => e.toJson()).toList(),
      if (tailorId != null) 'tailor_id': tailorId,
      'fabric': fabric,
      'advance': advance,
      if (status != null) 'status': status,
      if (startDate != null) 'start_date': _dateStr(startDate),
      if (expectedDate != null) 'expected_date': _dateStr(expectedDate),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return TailoringOrder.fromJson(res as Map<String, dynamic>);
  }

  /// Header update (status, tailor, dates, advance, notes, fabric). Line
  /// items are changed only through [addItem] / [correctItem]. Setting status
  /// to 'livre' moves the order to the Historique (server stamps the date).
  Future<TailoringOrder> update(
    String id, {
    String? status,
    String? tailorId,
    String? fabric,
    int? advance,
    DateTime? expectedDate,
    String? notes,
  }) async {
    final dynamic res = await _api.put('/api/orders/$id', body: {
      if (status != null) 'status': status,
      if (tailorId != null) 'tailor_id': tailorId,
      if (fabric != null) 'fabric': fabric,
      if (advance != null) 'advance': advance,
      if (expectedDate != null) 'expected_date': _dateStr(expectedDate),
      if (notes != null) 'notes': notes,
    });
    return TailoringOrder.fromJson(res as Map<String, dynamic>);
  }

  /// Append a new line to an existing order.
  Future<TailoringOrder> addItem(String orderId, NewOrderItem item) async {
    final dynamic res =
        await _api.post('/api/orders/$orderId/items', body: item.toJson());
    return TailoringOrder.fromJson(res as Map<String, dynamic>);
  }

  /// Correct or void a line (append-only; reason mandatory).
  Future<TailoringOrder> correctItem(
    String orderId,
    String itemId, {
    int? newQuantity,
    int? newUnitPrice,
    bool? voided,
    required String reason,
  }) async {
    final dynamic res =
        await _api.post('/api/orders/$orderId/items/$itemId/corrections', body: {
      if (newQuantity != null) 'new_quantity': newQuantity,
      if (newUnitPrice != null) 'new_unit_price': newUnitPrice,
      if (voided != null) 'voided': voided,
      'reason': reason,
    });
    return TailoringOrder.fromJson(res as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _api.delete('/api/orders/$id');
}
