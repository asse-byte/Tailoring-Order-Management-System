import '../../../core/network/api_client.dart';

/// One recorded salary disbursement (effective view: corrections applied).
class SalaryPayment {
  final String id;
  final String staffId;
  final String period; // 'YYYY-MM' (mensuel) | 'YYYY-Www' (hebdo)
  final String kind; // 'mensuel' | 'hebdo'
  final int amount;
  final bool voided;
  final bool corrected;
  final String paidAt;
  final String? note;

  const SalaryPayment({
    required this.id,
    required this.staffId,
    required this.period,
    required this.kind,
    required this.amount,
    required this.voided,
    required this.corrected,
    required this.paidAt,
    this.note,
  });

  factory SalaryPayment.fromJson(Map<String, dynamic> json) => SalaryPayment(
        id: json['id'] as String,
        staffId: json['staff_id'] as String,
        period: json['period'] as String,
        kind: json['kind'] as String,
        amount: json['amount'] as int? ?? 0,
        voided: json['voided'] as bool? ?? false,
        corrected: json['corrected'] as bool? ?? false,
        paidAt: json['paid_at'] as String? ?? '',
        note: json['note'] as String?,
      );
}

class SalaryPaymentsRepository {
  SalaryPaymentsRepository({ApiClient? client})
      : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<SalaryPayment>> forStaffYear(String staffId, int year) async {
    final dynamic res =
        await _api.get('/api/salary-payments?staff_id=$staffId&year=$year');
    return (res['items'] as List)
        .map((e) => SalaryPayment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SalaryPayment> record({
    required String staffId,
    required String period,
    required String kind,
    required int amount,
    String? paidAt,
    String? note,
  }) async {
    final dynamic res = await _api.post('/api/salary-payments', body: {
      'staff_id': staffId,
      'period': period,
      'kind': kind,
      'amount': amount,
      if (paidAt != null) 'paid_at': paidAt,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return SalaryPayment.fromJson(res as Map<String, dynamic>);
  }

  Future<void> correct(
    String id, {
    int? newAmount,
    bool? voided,
    required String reason,
  }) async {
    await _api.post('/api/salary-payments/$id/corrections', body: {
      if (newAmount != null) 'new_amount': newAmount,
      if (voided != null) 'voided': voided,
      'reason': reason,
    });
  }
}
