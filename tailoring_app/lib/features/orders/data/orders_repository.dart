import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/data/mock_database.dart';
import '../domain/entities/order.dart';

class OrderFailure implements Exception {
  OrderFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Repository for order CRUD + image uploads.
class OrdersRepository {
  OrdersRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore,
        _storage = storage;

  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;
  final Uuid _uuid = const Uuid();

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      firestore.collection(AppConstants.ordersCollection);

  // -------- Streams --------

  /// Stream of orders for a single customer, newest first.
  Stream<List<TailoringOrder>> watchCustomerOrders(String customerId) {
    if (MockDatabase.useMock) {
      return Stream.value(MockDatabase.instance.getCustomerOrders(customerId));
    }
    return _orders
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TailoringOrder.fromMap(d.id, d.data()))
            .toList(growable: false));
  }

  /// Stream of all orders (admin), newest first.
  Stream<List<TailoringOrder>> watchAllOrders() {
    if (MockDatabase.useMock) {
      return Stream.value(MockDatabase.instance.getAllOrders());
    }
    return _orders.orderBy('createdAt', descending: true).snapshots().map(
        (snap) => snap.docs
            .map((d) => TailoringOrder.fromMap(d.id, d.data()))
            .toList(growable: false));
  }

  Stream<TailoringOrder?> watchOrder(String orderId) {
    if (MockDatabase.useMock) {
      return Stream.value(MockDatabase.instance.getOrder(orderId));
    }
    return _orders
        .doc(orderId)
        .snapshots()
        .map((d) => d.exists ? TailoringOrder.fromMap(d.id, d.data()!) : null);
  }

  // -------- One-off reads --------

  Future<TailoringOrder?> getOrder(String orderId) async {
    if (MockDatabase.useMock) {
      return MockDatabase.instance.getOrder(orderId);
    }
    final doc = await _orders.doc(orderId).get();
    if (!doc.exists) return null;
    return TailoringOrder.fromMap(doc.id, doc.data()!);
  }

  // -------- Create / Update --------

  /// Creates a new order. The provided [order] should have an empty `id`
  /// or a fresh UUID — the Firestore doc id will be set to that value.
  Future<TailoringOrder> createOrder(TailoringOrder order) async {
    if (MockDatabase.useMock) {
      return await MockDatabase.instance.createOrder(order);
    }
    try {
      final String id = order.id.isEmpty ? _uuid.v4() : order.id;
      final TailoringOrder withId = TailoringOrder(
        id: id,
        customerId: order.customerId,
        customerName: order.customerName,
        garmentType: order.garmentType,
        fabricDescription: order.fabricDescription,
        fabricPhotoUrl: order.fabricPhotoUrl,
        styleReferencePhotoUrl: order.styleReferencePhotoUrl,
        specialInstructions: order.specialInstructions,
        deliveryDate: order.deliveryDate,
        price: order.price,
        status: order.status,
        statusHistory: order.statusHistory,
        adminNotes: order.adminNotes,
        measurementsSnapshot: order.measurementsSnapshot,
      );
      await _orders.doc(id).set(withId.toMap(forCreate: true));
      return withId;
    } catch (e) {
      throw OrderFailure('Could not create order: $e');
    }
  }

  /// Admin: update status (appends a StatusEvent) and optionally price/notes.
  Future<void> updateStatus({
    required String orderId,
    required String newStatus,
    required String adminUserId,
    String note = '',
    double? price,
    String? adminNotes,
  }) async {
    if (MockDatabase.useMock) {
      await MockDatabase.instance.updateOrderStatus(
        orderId: orderId,
        newStatus: newStatus,
        adminUserId: adminUserId,
        note: note,
        price: price,
        adminNotes: adminNotes,
      );
      return;
    }
    final StatusEvent event = StatusEvent(
      status: newStatus,
      changedAt: DateTime.now(),
      changedBy: adminUserId,
      note: note,
    );
    final Map<String, dynamic> updates = <String, dynamic>{
      'status': newStatus,
      'statusHistory':
          FieldValue.arrayUnion(<Map<String, dynamic>>[event.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (price != null) updates['price'] = price;
    if (adminNotes != null) updates['adminNotes'] = adminNotes;
    await _orders.doc(orderId).update(updates);
  }

  Future<void> updatePriceAndNotes({
    required String orderId,
    double? price,
    String? adminNotes,
  }) async {
    if (MockDatabase.useMock) {
      await MockDatabase.instance.updateOrderPriceAndNotes(
        orderId: orderId,
        price: price,
        adminNotes: adminNotes,
      );
      return;
    }
    final Map<String, dynamic> updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (price != null) updates['price'] = price;
    if (adminNotes != null) updates['adminNotes'] = adminNotes;
    if (updates.length == 1) return;
    await _orders.doc(orderId).update(updates);
  }

  /// Patches just the image URL fields on an order (used after async uploads).
  Future<void> updateImageUrls({
    required String orderId,
    String? fabricUrl,
    String? styleUrl,
  }) async {
    if (MockDatabase.useMock) {
      await MockDatabase.instance.updateOrderImageUrls(
        orderId: orderId,
        fabricUrl: fabricUrl,
        styleUrl: styleUrl,
      );
      return;
    }
    final Map<String, dynamic> updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (fabricUrl != null) updates['fabricPhotoUrl'] = fabricUrl;
    if (styleUrl != null) updates['styleReferencePhotoUrl'] = styleUrl;
    if (updates.length == 1) return;
    await _orders.doc(orderId).update(updates);
  }

  Future<void> deleteOrder(String orderId) async {
    if (MockDatabase.useMock) {
      await MockDatabase.instance.deleteOrder(orderId);
      return;
    }
    await _orders.doc(orderId).delete();
  }

  // -------- Image upload --------

  Future<String> uploadOrderImage({
    required File file,
    required String storageFolder,
    required String orderId,
  }) async {
    if (MockDatabase.useMock) {
      return 'https://via.placeholder.com/300';
    }
    final String name = '${_uuid.v4()}_${file.path.split('/').last}';
    final Reference ref = storage.ref().child('$storageFolder/$orderId/$name');
    final TaskSnapshot snap = await ref.putFile(file);
    return snap.ref.getDownloadURL();
  }
}
