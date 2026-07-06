import '../../../../core/constants/app_constants.dart';

/// A tailoring order, aligned 1:1 with the API rows (backend/orders).
/// Money is FCFA stored as int. Status: en_cours → pret → livre;
/// 'livre' rows ARE the Historique.
class TailoringOrder {
  const TailoringOrder({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.garmentType,
    required this.fabric,
    required this.notes,
    required this.measurementsSnapshot,
    required this.price,
    required this.advance,
    required this.status,
    required this.startDate,
    this.expectedDate,
    this.deliveredDate,
    this.createdAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String garmentType;
  final String fabric;
  final String notes;
  final Map<String, dynamic> measurementsSnapshot;
  final int price;
  final int advance;
  final String status;
  final DateTime? startDate;
  final DateTime? expectedDate;
  final DateTime? deliveredDate;
  final DateTime? createdAt;

  bool get isEnCours => status == AppConstants.statusEnCours;
  bool get isPret => status == AppConstants.statusPret;
  bool get isLivre => status == AppConstants.statusLivre;

  int get reste => price - advance;

  factory TailoringOrder.fromJson(Map<String, dynamic> m) {
    DateTime? parseDate(dynamic v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

    final dynamic snapshot = m['measurements_snapshot'];
    return TailoringOrder(
      id: m['id'] as String,
      clientId: (m['client_id'] as String?) ?? '',
      clientName: (m['client_name'] as String?) ?? '',
      clientPhone: (m['client_phone'] as String?) ?? '',
      garmentType: (m['garment_type'] as String?) ?? '',
      fabric: (m['fabric'] as String?) ?? '',
      notes: (m['notes'] as String?) ?? '',
      measurementsSnapshot: snapshot is Map
          ? Map<String, dynamic>.from(snapshot)
          : <String, dynamic>{},
      price: (m['price'] as num?)?.toInt() ?? 0,
      advance: (m['advance'] as num?)?.toInt() ?? 0,
      status: (m['status'] as String?) ?? AppConstants.statusEnCours,
      startDate: parseDate(m['start_date']),
      expectedDate: parseDate(m['expected_date']),
      deliveredDate: parseDate(m['delivered_date']),
      createdAt: parseDate(m['created_at']),
    );
  }
}
