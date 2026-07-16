import '../../../core/network/api_client.dart';
import '../domain/client.dart';

/// REST repository for /api/clients (both roles have full access).
class ClientsRepository {
  ClientsRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<Client>> list({
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    final dynamic res = await _api.get('/api/clients', query: <String, String>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'limit': '$limit',
      'offset': '$offset',
    });
    return (res['items'] as List)
        .map((e) => Client.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Client> getById(String id) async =>
      Client.fromJson(await _api.get('/api/clients/$id') as Map<String, dynamic>);

  Future<Client> create({
    required String fullName,
    required String phone,
    String? address,
    required String gender,
  }) async {
    final dynamic res = await _api.post('/api/clients', body: {
      'full_name': fullName,
      'phone': phone,
      'address': address,
      'gender': gender,
    });
    return Client.fromJson(res as Map<String, dynamic>);
  }

  Future<Client> update(
    String id, {
    required String fullName,
    required String phone,
    String? address,
    required String gender,
  }) async {
    final dynamic res = await _api.put('/api/clients/$id', body: {
      'full_name': fullName,
      'phone': phone,
      'address': address,
      'gender': gender,
    });
    return Client.fromJson(res as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getCustomGarments() async {
    final dynamic res = await _api.get('/api/clients/settings/custom-garments');
    return res as Map<String, dynamic>;
  }

  Future<void> saveCustomGarments(Map<String, dynamic> custom) =>
      _api.put('/api/clients/settings/custom-garments', body: custom);

  Future<void> remove(String id) => _api.delete('/api/clients/$id');

  // ---- measurements: garmentType → (field → value) ----

  Future<Map<String, Map<String, num>>> measurements(String clientId) async {
    final dynamic res = await _api.get('/api/clients/$clientId/measurements');
    final Map<String, Map<String, num>> out = <String, Map<String, num>>{};
    for (final dynamic item in res['items'] as List) {
      final Map<String, dynamic> measures =
          (item['measures'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      out[item['garment_type'] as String] = measures.map(
          (k, v) => MapEntry(k, (v as num?) ?? 0));
    }
    return out;
  }

  Future<void> saveMeasurements(
    String clientId,
    String garmentType,
    Map<String, num> measures,
  ) =>
      _api.put(
        '/api/clients/$clientId/measurements/${Uri.encodeComponent(garmentType)}',
        body: {'measures': measures},
      );

  Future<void> deleteMeasurements(String clientId, String garmentType) =>
      _api.delete(
          '/api/clients/$clientId/measurements/${Uri.encodeComponent(garmentType)}');

  // ---- order history for the client detail screen ----

  Future<List<ClientOrderSummary>> orders(
    String clientId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final dynamic res = await _api.get(
      '/api/clients/$clientId/orders',
      query: <String, String>{'limit': '$limit', 'offset': '$offset'},
    );
    return (res['items'] as List)
        .map((e) => ClientOrderSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
