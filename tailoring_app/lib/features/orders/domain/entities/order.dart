import '../../../../core/constants/app_constants.dart';

/// One line of an order: a garment type, its quantity and unit price.
/// Mirrors a row of the API's order_items_effective view.
class OrderItemLine {
  const OrderItemLine({
    required this.id,
    required this.garmentType,
    required this.quantity,
    required this.unitPrice,
    required this.voided,
    required this.corrected,
    required this.lineTotal,
  });

  final String id;
  final String garmentType;
  final int quantity;
  final int unitPrice;
  final bool voided;
  final bool corrected;
  final int lineTotal;

  factory OrderItemLine.fromJson(Map<String, dynamic> m) => OrderItemLine(
        id: m['id'] as String,
        garmentType: (m['garment_type'] as String?) ?? '',
        quantity: (m['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: (m['unit_price'] as num?)?.toInt() ?? 0,
        voided: (m['voided'] as bool?) ?? false,
        corrected: (m['corrected'] as bool?) ?? false,
        lineTotal: (m['line_total'] as num?)?.toInt() ?? 0,
      );
}

/// A tailoring order, aligned 1:1 with the API rows (backend/orders).
/// Money is FCFA stored as int. Status flows en_attente → en_cours →
/// termine → livre; 'livre' rows ARE the Historique. The [total] is derived
/// server-side from the (append-only) line [items].
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
    required this.items,
    required this.total,
    required this.advance,
    required this.status,
    this.tailorId,
    this.tailorName,
    this.startDate,
    this.expectedDate,
    this.deliveredDate,
    this.createdAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String clientPhone;

  /// Header garment type (first line) — kept for compact list display.
  final String garmentType;
  final String fabric;
  final String notes;
  final Map<String, dynamic> measurementsSnapshot;
  final List<OrderItemLine> items;
  final int total;
  final int advance;
  final String status;
  final String? tailorId;
  final String? tailorName;
  final DateTime? startDate;
  final DateTime? expectedDate;
  final DateTime? deliveredDate;
  final DateTime? createdAt;

  bool get isEnAttente => status == AppConstants.statusEnAttente;
  bool get isEnCours => status == AppConstants.statusEnCours;
  bool get isTermine => status == AppConstants.statusTermine;
  bool get isLivre => status == AppConstants.statusLivre;

  String get statusLabel => AppConstants.statusLabel(status);

  /// Live (non-voided) lines — what is shown and summed.
  List<OrderItemLine> get activeItems =>
      items.where((i) => !i.voided).toList();

  int get reste => total - advance;

  factory TailoringOrder.fromJson(Map<String, dynamic> m) {
    DateTime? parseDate(dynamic v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

    final dynamic snapshot = m['measurements_snapshot'];
    final dynamic rawItems = m['items'];
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
      items: rawItems is List
          ? rawItems
              .map((e) => OrderItemLine.fromJson(e as Map<String, dynamic>))
              .toList()
          : <OrderItemLine>[],
      total: (m['total'] as num?)?.toInt() ?? 0,
      advance: (m['advance'] as num?)?.toInt() ?? 0,
      status: (m['status'] as String?) ?? AppConstants.statusEnAttente,
      tailorId: m['tailor_id'] as String?,
      tailorName: m['tailor_name'] as String?,
      startDate: parseDate(m['start_date']),
      expectedDate: parseDate(m['expected_date']),
      deliveredDate: parseDate(m['delivered_date']),
      createdAt: parseDate(m['created_at']),
    );
  }
}
