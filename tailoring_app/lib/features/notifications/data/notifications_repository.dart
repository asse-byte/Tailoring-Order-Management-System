import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/data/mock_database.dart';
import '../domain/entities/app_notification.dart';

class NotificationsRepository {
  NotificationsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  final Uuid _uuid = const Uuid();

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      firestore.collection(AppConstants.notificationsCollection);

  /// Stream notifications for the current user, newest first.
  Stream<List<AppNotification>> watchForUser(String uid) {
    if (MockDatabase.useMock) {
      return Stream.value(MockDatabase.instance.getUserNotifications(uid));
    }
    return _ref
        .where('recipientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppNotification.fromMap(d.id, d.data()))
            .toList(growable: false));
  }

  /// Send a notification to a single user.
  Future<AppNotification> sendToUser({
    required String recipientId,
    required String title,
    required String body,
    required String senderId,
    String? orderId,
  }) async {
    if (MockDatabase.useMock) {
      return await MockDatabase.instance.sendNotification(
        recipientId: recipientId,
        title: title,
        body: body,
        senderId: senderId,
        orderId: orderId,
      );
    }
    final String id = _uuid.v4();
    final AppNotification n = AppNotification(
      id: id,
      recipientId: recipientId,
      title: title,
      body: body,
      isRead: false,
      senderId: senderId,
      orderId: orderId,
    );
    await _ref.doc(id).set(n.toMap(forCreate: true));
    return n;
  }

  /// Fan out a broadcast to every recipient id provided.
  /// Uses a batched write (max 500 ops per batch).
  Future<int> broadcast({
    required List<String> recipientIds,
    required String title,
    required String body,
    required String senderId,
    String? orderId,
  }) async {
    if (MockDatabase.useMock) {
      return await MockDatabase.instance.broadcast(
        recipientIds: recipientIds,
        title: title,
        body: body,
        senderId: senderId,
        orderId: orderId,
      );
    }
    int written = 0;
    const int chunkSize = 450;
    for (int i = 0; i < recipientIds.length; i += chunkSize) {
      final List<String> chunk = recipientIds.sublist(
          i, (i + chunkSize).clamp(0, recipientIds.length));
      final WriteBatch batch = firestore.batch();
      for (final String uid in chunk) {
        final String id = _uuid.v4();
        final AppNotification n = AppNotification(
          id: id,
          recipientId: uid,
          title: title,
          body: body,
          isRead: false,
          senderId: senderId,
          orderId: orderId,
        );
        batch.set(_ref.doc(id), n.toMap(forCreate: true));
      }
      await batch.commit();
      written += chunk.length;
    }
    return written;
  }

  Future<void> markRead(String id) async {
    if (MockDatabase.useMock) {
      await MockDatabase.instance.markNotificationRead(id);
      return;
    }
    await _ref.doc(id).update(<String, dynamic>{'isRead': true});
  }

  Future<void> markAllRead(String uid) async {
    if (MockDatabase.useMock) {
      await MockDatabase.instance.markAllNotificationsRead(uid);
      return;
    }
    final QuerySnapshot<Map<String, dynamic>> snap = await _ref
        .where('recipientId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();
    final WriteBatch batch = firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, <String, dynamic>{'isRead': true});
    }
    if (snap.docs.isNotEmpty) await batch.commit();
  }

  Future<void> delete(String id) async {
    if (MockDatabase.useMock) {
      await MockDatabase.instance.deleteNotification(id);
      return;
    }
    await _ref.doc(id).delete();
  }
}
