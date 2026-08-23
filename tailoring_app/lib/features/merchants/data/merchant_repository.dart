import '../../../core/network/api_client.dart';
import '../domain/merchant_models.dart';

class MerchantRepository {
  MerchantRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  // ---- Suppliers catalog ----
  Future<List<Supplier>> listSuppliers({String? search}) async {
    final query = search != null && search.isNotEmpty ? '?search=$search' : '';
    final dynamic res = await _api.get('/api/suppliers$query');
    return (res['items'] as List)
        .map((e) => Supplier.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Supplier> createSupplier({
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    final dynamic res = await _api.post('/api/suppliers', body: {
      'name': name,
      'phone': phone ?? '',
      'address': address ?? '',
      'notes': notes ?? '',
    });
    return Supplier.fromJson(res as Map<String, dynamic>);
  }

  Future<Supplier> updateSupplier(
    String id, {
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    final dynamic res = await _api.put('/api/suppliers/$id', body: {
      'name': name,
      'phone': phone ?? '',
      'address': address ?? '',
      'notes': notes ?? '',
    });
    return Supplier.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deleteSupplier(String id) async {
    await _api.delete('/api/suppliers/$id');
  }

  // ---- Supplier Purchases ----
  Future<List<SupplierPurchase>> listSupplierPurchases({
    String? supplierId,
    String? from,
    String? to,
  }) async {
    final params = <String>[];
    if (supplierId != null && supplierId.isNotEmpty) {
      params.add('supplier_id=$supplierId');
    }
    if (from != null && from.isNotEmpty) params.add('from=$from');
    if (to != null && to.isNotEmpty) params.add('to=$to');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final dynamic res = await _api.get('/api/suppliers/purchases$query');
    return (res['items'] as List)
        .map((e) => SupplierPurchase.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SupplierPurchase> createSupplierPurchase({
    String? supplierId,
    String? supplierName,
    required String description,
    required int totalAmount,
    required int advanceAmount,
    String? purchaseDate,
  }) async {
    final dynamic res = await _api.post('/api/suppliers/purchases', body: {
      if (supplierId != null) 'supplier_id': supplierId,
      if (supplierName != null) 'supplier_name': supplierName,
      'description': description,
      'total_amount': totalAmount,
      'advance_amount': advanceAmount,
      if (purchaseDate != null) 'purchase_date': purchaseDate,
    });
    return SupplierPurchase.fromJson(res as Map<String, dynamic>);
  }

  Future<SupplierPurchase> updateSupplierPurchase(
    String id, {
    String? supplierId,
    String? supplierName,
    required String description,
    required int totalAmount,
    required int advanceAmount,
    String? purchaseDate,
  }) async {
    final dynamic res = await _api.put('/api/suppliers/purchases/$id', body: {
      if (supplierId != null) 'supplier_id': supplierId,
      if (supplierName != null) 'supplier_name': supplierName,
      'description': description,
      'total_amount': totalAmount,
      'advance_amount': advanceAmount,
      if (purchaseDate != null) 'purchase_date': purchaseDate,
    });
    return SupplierPurchase.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deleteSupplierPurchase(String id) async {
    await _api.delete('/api/suppliers/purchases/$id');
  }

  Future<List<SupplierPayment>> listSupplierPayments(String purchaseId) async {
    final dynamic res =
        await _api.get('/api/suppliers/purchases/$purchaseId/payments');
    return (res['items'] as List)
        .map((e) => SupplierPayment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SupplierPayment> recordSupplierPayment({
    required String purchaseId,
    required int amount,
    String? paidAt,
    String? note,
  }) async {
    final dynamic res =
        await _api.post('/api/suppliers/purchases/$purchaseId/payments', body: {
      'amount': amount,
      if (paidAt != null) 'paid_at': paidAt,
      if (note != null) 'note': note,
    });
    return SupplierPayment.fromJson(res as Map<String, dynamic>);
  }

  // ---- Wholesale Orders ----
  Future<List<WholesaleOrder>> listWholesaleOrders({
    String? status,
    String? merchant,
    String? from,
    String? to,
  }) async {
    final params = <String>[];
    if (status != null && status.isNotEmpty) params.add('status=$status');
    if (merchant != null && merchant.isNotEmpty) {
      params.add('merchant=$merchant');
    }
    if (from != null && from.isNotEmpty) params.add('from=$from');
    if (to != null && to.isNotEmpty) params.add('to=$to');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final dynamic res = await _api.get('/api/wholesale/orders$query');
    return (res['items'] as List)
        .map((e) => WholesaleOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WholesaleOrder> createWholesaleOrder({
    required String merchantName,
    String? merchantPhone,
    required List<WholesaleOrderItem> items,
    required int totalAmount,
    required int advanceAmount,
    String? orderDate,
    String? notes,
  }) async {
    final dynamic res = await _api.post('/api/wholesale/orders', body: {
      'merchant_name': merchantName,
      'merchant_phone': merchantPhone ?? '',
      'items': items.map((i) => i.toJson()).toList(),
      'total_amount': totalAmount,
      'advance_amount': advanceAmount,
      if (orderDate != null) 'order_date': orderDate,
      if (notes != null) 'notes': notes,
    });
    return WholesaleOrder.fromJson(res as Map<String, dynamic>);
  }

  Future<WholesaleOrder> updateWholesaleOrder(
    String id, {
    String? merchantName,
    String? merchantPhone,
    List<WholesaleOrderItem>? items,
    int? totalAmount,
    int? advanceAmount,
    String? orderDate,
    String? status,
    String? notes,
  }) async {
    final dynamic res = await _api.put('/api/wholesale/orders/$id', body: {
      if (merchantName != null) 'merchant_name': merchantName,
      if (merchantPhone != null) 'merchant_phone': merchantPhone,
      if (items != null) 'items': items.map((i) => i.toJson()).toList(),
      if (totalAmount != null) 'total_amount': totalAmount,
      if (advanceAmount != null) 'advance_amount': advanceAmount,
      if (orderDate != null) 'order_date': orderDate,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
    });
    return WholesaleOrder.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deleteWholesaleOrder(String id) async {
    await _api.delete('/api/wholesale/orders/$id');
  }

  Future<List<WholesalePayment>> listWholesalePayments(String orderId) async {
    final dynamic res =
        await _api.get('/api/wholesale/orders/$orderId/payments');
    return (res['items'] as List)
        .map((e) => WholesalePayment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WholesalePayment> recordWholesalePayment({
    required String orderId,
    required int amount,
    String? paidAt,
    String? note,
  }) async {
    final dynamic res =
        await _api.post('/api/wholesale/orders/$orderId/payments', body: {
      'amount': amount,
      if (paidAt != null) 'paid_at': paidAt,
      if (note != null) 'note': note,
    });
    return WholesalePayment.fromJson(res as Map<String, dynamic>);
  }
}
