/// A shop client — a plain record managed by the staff (not an app user).
class Client {
  const Client({
    required this.id,
    required this.fullName,
    required this.phone,
    this.address,
    required this.gender,
    this.createdAt,
  });

  final String id;
  final String fullName;
  final String phone;
  final String? address;
  final String gender; // 'homme' or 'femme'
  final DateTime? createdAt;

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: json['id'] as String,
        fullName: (json['full_name'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
        address: json['address'] as String?,
        gender: (json['gender'] as String?) ?? 'homme',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}

/// Lightweight order line for the client's history section.
class ClientOrderSummary {
  const ClientOrderSummary({
    required this.id,
    required this.garmentType,
    required this.status,
    required this.total,
    this.createdAt,
    this.expectedDate,
  });

  final String id;
  final String garmentType;
  final String status; // en_attente | en_cours | termine | livre
  final int total;
  final DateTime? createdAt;
  final DateTime? expectedDate;

  factory ClientOrderSummary.fromJson(Map<String, dynamic> json) =>
      ClientOrderSummary(
        id: json['id'] as String,
        garmentType: (json['garment_type'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'en_attente',
        // New orders carry a derived `total`; fall back to legacy `price`.
        total: (json['total'] as num?)?.toInt() ??
            (json['price'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        expectedDate: json['expected_date'] != null
            ? DateTime.tryParse(json['expected_date'] as String)
            : null,
      );
}
