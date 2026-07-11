import '../../../core/network/api_client.dart';

class Appointment {
  final String id;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String scheduledAt; // ISO timestamp
  final String reason;

  /// 'manual' (a real appointment row) or 'order' (an order's delivery date,
  /// surfaced automatically and read-only).
  final String source;
  final String? orderId;

  const Appointment({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.scheduledAt,
    required this.reason,
    this.source = 'manual',
    this.orderId,
  });

  bool get isFromOrder => source == 'order';

  DateTime? get scheduledDate => DateTime.tryParse(scheduledAt);

  /// Days from today (date-only) to the appointment; negative = past.
  int? get daysUntil {
    final d = scheduledDate;
    if (d == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    return target.difference(today).inDays;
  }

  /// Upcoming and 3 days or less away — shown in a warning colour.
  bool get isSoon {
    final d = daysUntil;
    return d != null && d >= 0 && d <= 3;
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      clientName: json['client_name'] as String? ?? '',
      clientPhone: json['client_phone'] as String? ?? '',
      scheduledAt: json['scheduled_at'] as String,
      reason: json['reason'] as String? ?? '',
      source: json['source'] as String? ?? 'manual',
      orderId: json['order_id'] as String?,
    );
  }
}

class AppointmentsRepository {
  AppointmentsRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<Appointment>> list() async {
    final dynamic res = await _api.get('/api/appointments');
    return (res['items'] as List)
        .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Appointment> create({
    required String clientId,
    required String scheduledAt,
    required String reason,
  }) async {
    final dynamic res = await _api.post('/api/appointments', body: {
      'client_id': clientId,
      'scheduled_at': scheduledAt,
      'reason': reason,
    });
    return Appointment.fromJson(res as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _api.delete('/api/appointments/$id');
}
