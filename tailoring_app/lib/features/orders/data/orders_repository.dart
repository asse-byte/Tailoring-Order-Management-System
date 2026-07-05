import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/order.dart';

class OrderFailure implements Exception {
  OrderFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class OrdersRepository {
  OrdersRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  // Streams are replaced by periodic/on-demand futures in REST architecture,
  // but we can expose them as Streams for compatibility with StreamProvider if needed,
  // or return futures. For maximum compatibility with existing providers, we can return streams that periodically poll
  // or simply return a static stream of the loaded data.
  
  Stream<List<TailoringOrder>> watchCustomerOrders(String customerId) {
    return Stream.fromFuture(listOrders(clientId: customerId));
  }

  Stream<List<TailoringOrder>> watchAllOrders() async* {
    yield await listOrders();
    yield* Stream.periodic(const Duration(seconds: 15))
        .asyncMap((_) => listOrders());
  }

  Stream<TailoringOrder?> watchOrder(String orderId) async* {
    yield await getOrder(orderId);
    yield* Stream.periodic(const Duration(seconds: 15))
        .asyncMap((_) => getOrder(orderId));
  }

  // -------- One-off reads --------

  Future<List<TailoringOrder>> listOrders({
    String? status,
    String? clientId,
    int limit = 50,
    int offset = 0,
  }) async {
    final Map<String, String> query = {
      'limit': '$limit',
      'offset': '$offset',
      if (status != null) 'status': status,
      if (clientId != null) 'client_id': clientId,
    };
    final dynamic res = await _api.get('/api/orders', query: query);
    return (res['items'] as List)
        .map((e) => TailoringOrder.fromMap(e['id'] as String, _mapRowToMap(e as Map<String, dynamic>)))
        .toList();
  }

  Future<TailoringOrder?> getOrder(String orderId) async {
    try {
      final dynamic res = await _api.get('/api/orders/$orderId');
      return TailoringOrder.fromMap(orderId, _mapRowToMap(res as Map<String, dynamic>));
    } catch (_) {
      return null;
    }
  }

  // -------- Create / Update --------

  Future<TailoringOrder> createOrder(TailoringOrder order) async {
    try {
      // Map statuses: pending/in_progress -> en_cours, completed -> livre
      String backendStatus = 'en_cours';
      if (order.status == 'completed' || order.status == 'livre') {
        backendStatus = 'livre';
      } else if (order.status == 'pret') {
        backendStatus = 'pret';
      }

      final dateStr = '${order.deliveryDate.year}-${order.deliveryDate.month.toString().padLeft(2, '0')}-${order.deliveryDate.day.toString().padLeft(2, '0')}';
      
      final dynamic res = await _api.post('/api/orders', body: {
        'client_id': order.customerId,
        'garment_type': order.garmentType,
        'fabric': order.fabricDescription,
        'price': order.price?.toInt() ?? 0,
        'advance': 0, // Default advance
        'expected_date': dateStr,
        'notes': order.specialInstructions,
        'status': backendStatus,
        'measurements_snapshot': order.measurementsSnapshot,
      });

      return TailoringOrder.fromMap(res['id'] as String, _mapRowToMap(res as Map<String, dynamic>));
    } catch (e) {
      throw OrderFailure('Impossible de créer la commande: $e');
    }
  }

  Future<void> updateStatus({
    required String orderId,
    required String newStatus,
    required String adminUserId,
    String note = '',
    double? price,
    String? adminNotes,
  }) async {
    // Map status to backend enum: 'en_cours', 'pret', 'livre'
    String backendStatus = 'en_cours';
    if (newStatus == 'completed' || newStatus == 'livre') {
      backendStatus = 'livre';
    } else if (newStatus == 'pret' || newStatus == 'in_progress') {
      backendStatus = 'pret'; // Ready or in_progress can map to pret
    }

    final Map<String, dynamic> body = {
      'status': backendStatus,
    };
    if (price != null) body['price'] = price.toInt();
    if (adminNotes != null) body['notes'] = adminNotes;

    await _api.put('/api/orders/$orderId', body: body);
  }

  Future<void> updatePriceAndNotes({
    required String orderId,
    double? price,
    String? adminNotes,
  }) async {
    final Map<String, dynamic> body = {};
    if (price != null) body['price'] = price.toInt();
    if (adminNotes != null) body['notes'] = adminNotes;
    if (body.isEmpty) return;

    await _api.put('/api/orders/$orderId', body: body);
  }

  Future<void> updateImageUrls({
    required String orderId,
    String? fabricUrl,
    String? styleUrl,
  }) async {
    // No dedicated columns in postgres for fabricPhotoUrl or styleReferencePhotoUrl
    // We can ignore or log
  }

  Future<void> deleteOrder(String orderId) async {
    await _api.delete('/api/orders/$orderId');
  }

  // -------- Image upload --------

  Future<String> uploadOrderImage({
    required File file,
    required String storageFolder,
    required String orderId,
  }) async {
    final String path = '/api/upload';
    final Uri uri = Uri.parse('${ApiClient.baseUrl}$path');
    final String? jwt = await _api.token;
    
    final request = http.MultipartRequest('POST', uri);
    if (jwt != null) {
      request.headers['Authorization'] = 'Bearer $jwt';
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    
    final response = await request.send();
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, 'Échec du téléversement.');
    }
    
    final responseBody = await response.stream.bytesToString();
    final Map<String, dynamic> decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    return decoded['url'] as String;
  }

  // Mappers
  Map<String, dynamic> _mapRowToMap(Map<String, dynamic> row) {
    // Convert backend schema to matching Map structure expected by TailoringOrder.fromMap
    // expected_date -> deliveryDate
    // notes -> specialInstructions
    // fabric -> fabricDescription
    // status: en_cours -> pending, pret -> in_progress, livre -> completed
    String mappedStatus = 'pending';
    if (row['status'] == 'livre') {
      mappedStatus = 'completed';
    } else if (row['status'] == 'pret') {
      mappedStatus = 'in_progress';
    }

    return {
      'customerId': row['client_id'],
      'customerName': row['client_name'] ?? '',
      'garmentType': row['garment_type'],
      'fabricDescription': row['fabric'] ?? '',
      'specialInstructions': row['notes'] ?? '',
      // Map dates as Timestamp strings or Mock compatible format
      'deliveryDate': row['expected_date'] != null 
          ? Timestamp.fromDate(DateTime.parse(row['expected_date'] as String)) 
          : Timestamp.fromDate(DateTime.now()),
      'price': (row['price'] as num?)?.toDouble() ?? 0.0,
      'status': mappedStatus,
      'statusHistory': [],
      'measurementsSnapshot': row['measurements_snapshot'] is String
          ? jsonDecode(row['measurements_snapshot'] as String)
          : row['measurements_snapshot'] ?? {},
      'createdAt': row['created_at'] != null 
          ? Timestamp.fromDate(DateTime.parse(row['created_at'] as String)) 
          : null,
      'updatedAt': row['updated_at'] != null 
          ? Timestamp.fromDate(DateTime.parse(row['updated_at'] as String)) 
          : null,
    };
  }
}
