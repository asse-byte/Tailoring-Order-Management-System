import 'package:cloud_firestore/cloud_firestore.dart';

/// Body measurements stored at /measurements/{userId}.
class Measurements {
  const Measurements({
    required this.userId,
    this.chest,
    this.waist,
    this.hips,
    this.shoulder,
    this.sleeveLength,
    this.height,
    this.notes = '',
    this.updatedAt,
  });

  factory Measurements.empty(String userId) => Measurements(userId: userId);

  final String userId;
  final double? chest;
  final double? waist;
  final double? hips;
  final double? shoulder;
  final double? sleeveLength;
  final double? height;
  final String notes;
  final DateTime? updatedAt;

  bool get isEmpty =>
      chest == null &&
      waist == null &&
      hips == null &&
      shoulder == null &&
      sleeveLength == null &&
      height == null;

  Measurements copyWith({
    double? chest,
    double? waist,
    double? hips,
    double? shoulder,
    double? sleeveLength,
    double? height,
    String? notes,
  }) {
    return Measurements(
      userId: userId,
      chest: chest ?? this.chest,
      waist: waist ?? this.waist,
      hips: hips ?? this.hips,
      shoulder: shoulder ?? this.shoulder,
      sleeveLength: sleeveLength ?? this.sleeveLength,
      height: height ?? this.height,
      notes: notes ?? this.notes,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'measurementId': userId,
        'userId': userId,
        'chest': chest,
        'waist': waist,
        'hips': hips,
        'shoulder': shoulder,
        'sleeveLength': sleeveLength,
        'height': height,
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Snapshot embedded inside an order document.
  Map<String, dynamic> toSnapshot() => <String, dynamic>{
        'chest': chest,
        'waist': waist,
        'hips': hips,
        'shoulder': shoulder,
        'sleeveLength': sleeveLength,
        'height': height,
        'notes': notes,
      };

  factory Measurements.fromMap(String userId, Map<String, dynamic> m) {
    double? toDouble(dynamic v) => (v as num?)?.toDouble();
    return Measurements(
      userId: userId,
      chest: toDouble(m['chest']),
      waist: toDouble(m['waist']),
      hips: toDouble(m['hips']),
      shoulder: toDouble(m['shoulder']),
      sleeveLength: toDouble(m['sleeveLength']),
      height: toDouble(m['height']),
      notes: (m['notes'] as String?) ?? '',
      updatedAt: m['updatedAt'] is Timestamp
          ? (m['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
