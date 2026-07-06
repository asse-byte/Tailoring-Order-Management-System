import '../../../core/network/api_client.dart';
import '../domain/entities/order.dart';

/// REST repository for /api/orders. Statuses and money use the API values
/// directly (en_cours/pret/livre, FCFA ints) — no legacy mapping.
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

  /// Creates an order. The server snapshots the client's measurements when
  /// none are provided — the reference used at cutting time.
  Future<TailoringOrder> create({
    required String clientId,
    required String garmentType,
    String fabric = '',
    int price = 0,
    int advance = 0,
    DateTime? startDate,
    DateTime? expectedDate,
    String? notes,
  }) async {
    final dynamic res = await _api.post('/api/orders', body: {
      'client_id': clientId,
      'garment_type': garmentType,
      'fabric': fabric,
      'price': price,
      'advance': advance,
      if (startDate != null) 'start_date': _dateStr(startDate),
      if (expectedDate != null) 'expected_date': _dateStr(expectedDate),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return TailoringOrder.fromJson(res as Map<String, dynamic>);
  }

  /// Partial update: only the provided fields change. Setting status to
  /// 'livre' moves the order to the Historique (server stamps the date).
  Future<TailoringOrder> update(
    String id, {
    String? status,
    String? garmentType,
    String? fabric,
    int? price,
    int? advance,
    DateTime? expectedDate,
    String? notes,
  }) async {
    final dynamic res = await _api.put('/api/orders/$id', body: {
      if (status != null) 'status': status,
      if (garmentType != null) 'garment_type': garmentType,
      if (fabric != null) 'fabric': fabric,
      if (price != null) 'price': price,
      if (advance != null) 'advance': advance,
      if (expectedDate != null) 'expected_date': _dateStr(expectedDate),
      if (notes != null) 'notes': notes,
    });
    return TailoringOrder.fromJson(res as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _api.delete('/api/orders/$id');
}
