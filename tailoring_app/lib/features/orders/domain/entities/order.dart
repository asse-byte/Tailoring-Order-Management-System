import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';

/// Represents one entry in an order's status history timeline.
class StatusEvent {
  const StatusEvent({
    required this.status,
    required this.changedAt,
    required this.changedBy,
    this.note = '',
  });

  final String status;
  final DateTime changedAt;
  final String changedBy;
  final String note;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'status': status,
        'changedAt': Timestamp.fromDate(changedAt),
        'changedBy': changedBy,
        'note': note,
      };

  factory StatusEvent.fromMap(Map<String, dynamic> m) {
    final dynamic ts = m['changedAt'];
    return StatusEvent(
      status: (m['status'] as String?) ?? AppConstants.statusPending,
      changedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      changedBy: (m['changedBy'] as String?) ?? '',
      note: (m['note'] as String?) ?? '',
    );
  }
}

/// A tailoring order document.
class TailoringOrder {
  const TailoringOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.garmentType,
    required this.fabricDescription,
    required this.specialInstructions,
    required this.deliveryDate,
    required this.status,
    required this.statusHistory,
    required this.measurementsSnapshot,
    this.fabricPhotoUrl,
    this.styleReferencePhotoUrl,
    this.price,
    this.adminNotes = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String garmentType;
  final String fabricDescription;
  final String? fabricPhotoUrl;
  final String? styleReferencePhotoUrl;
  final String specialInstructions;
  final DateTime deliveryDate;
  final double? price;
  final String status;
  final List<StatusEvent> statusHistory;
  final String adminNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> measurementsSnapshot;

  bool get isPending => status == AppConstants.statusPending;
  bool get isInProgress => status == AppConstants.statusInProgress;
  bool get isCompleted => status == AppConstants.statusCompleted;
  bool get isCancelled => status == AppConstants.statusCancelled;

  TailoringOrder copyWith({
    String? garmentType,
    String? fabricDescription,
    String? fabricPhotoUrl,
    String? styleReferencePhotoUrl,
    String? specialInstructions,
    DateTime? deliveryDate,
    double? price,
    String? status,
    List<StatusEvent>? statusHistory,
    String? adminNotes,
    DateTime? updatedAt,
    Map<String, dynamic>? measurementsSnapshot,
  }) {
    return TailoringOrder(
      id: id,
      customerId: customerId,
      customerName: customerName,
      garmentType: garmentType ?? this.garmentType,
      fabricDescription: fabricDescription ?? this.fabricDescription,
      fabricPhotoUrl: fabricPhotoUrl ?? this.fabricPhotoUrl,
      styleReferencePhotoUrl:
          styleReferencePhotoUrl ?? this.styleReferencePhotoUrl,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      price: price ?? this.price,
      status: status ?? this.status,
      statusHistory: statusHistory ?? this.statusHistory,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      measurementsSnapshot: measurementsSnapshot ?? this.measurementsSnapshot,
    );
  }

  Map<String, dynamic> toMap({bool forCreate = false}) {
    return <String, dynamic>{
      'orderId': id,
      'customerId': customerId,
      'customerName': customerName,
      'garmentType': garmentType,
      'fabricDescription': fabricDescription,
      'fabricPhotoUrl': fabricPhotoUrl,
      'styleReferencePhotoUrl': styleReferencePhotoUrl,
      'specialInstructions': specialInstructions,
      'deliveryDate': Timestamp.fromDate(deliveryDate),
      'price': price,
      'status': status,
      'statusHistory':
          statusHistory.map((e) => e.toMap()).toList(growable: false),
      'adminNotes': adminNotes,
      'measurementsSnapshot': measurementsSnapshot,
      'createdAt': forCreate
          ? FieldValue.serverTimestamp()
          : (createdAt != null ? Timestamp.fromDate(createdAt!) : null),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory TailoringOrder.fromMap(String id, Map<String, dynamic> m) {
    DateTime parseDate(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.now();

    final List<dynamic> raw =
        (m['statusHistory'] as List<dynamic>?) ?? <dynamic>[];
    final List<StatusEvent> history = raw
        .whereType<Map<String, dynamic>>()
        .map(StatusEvent.fromMap)
        .toList(growable: false);

    return TailoringOrder(
      id: id,
      customerId: (m['customerId'] as String?) ?? '',
      customerName: (m['customerName'] as String?) ?? '',
      garmentType: (m['garmentType'] as String?) ?? '',
      fabricDescription: (m['fabricDescription'] as String?) ?? '',
      fabricPhotoUrl: m['fabricPhotoUrl'] as String?,
      styleReferencePhotoUrl: m['styleReferencePhotoUrl'] as String?,
      specialInstructions: (m['specialInstructions'] as String?) ?? '',
      deliveryDate: parseDate(m['deliveryDate']),
      price: (m['price'] as num?)?.toDouble(),
      status: (m['status'] as String?) ?? AppConstants.statusPending,
      statusHistory: history,
      adminNotes: (m['adminNotes'] as String?) ?? '',
      createdAt: m['createdAt'] is Timestamp
          ? (m['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: m['updatedAt'] is Timestamp
          ? (m['updatedAt'] as Timestamp).toDate()
          : null,
      measurementsSnapshot: Map<String, dynamic>.from(
          m['measurementsSnapshot'] ?? <String, dynamic>{}),
    );
  }
}
