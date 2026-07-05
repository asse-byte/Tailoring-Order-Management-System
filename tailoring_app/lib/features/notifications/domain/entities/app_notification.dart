import 'package:cloud_firestore/cloud_firestore.dart';

/// In-app notification stored at /notifications/{id}.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    required this.isRead,
    this.orderId,
    this.senderId,
    this.createdAt,
  });

  final String id;
  final String recipientId; // user uid; broadcasts are fanned out per user
  final String title;
  final String body;
  final bool isRead;
  final String? orderId;
  final String? senderId;
  final DateTime? createdAt;

  Map<String, dynamic> toMap({bool forCreate = false}) => <String, dynamic>{
        'notificationId': id,
        'recipientId': recipientId,
        'title': title,
        'body': body,
        'isRead': isRead,
        'orderId': orderId,
        'senderId': senderId,
        'createdAt': forCreate
            ? FieldValue.serverTimestamp()
            : (createdAt != null ? Timestamp.fromDate(createdAt!) : null),
      };

  factory AppNotification.fromMap(String id, Map<String, dynamic> m) {
    return AppNotification(
      id: id,
      recipientId: (m['recipientId'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      body: (m['body'] as String?) ?? '',
      isRead: (m['isRead'] as bool?) ?? false,
      orderId: m['orderId'] as String?,
      senderId: m['senderId'] as String?,
      createdAt: m['createdAt'] is Timestamp
          ? (m['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
