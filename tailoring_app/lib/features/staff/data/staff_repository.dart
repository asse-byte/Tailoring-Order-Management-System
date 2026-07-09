import '../../../core/network/api_client.dart';

class StaffContact {
  final String id;
  final String fullName;
  final String phone;
  final String type; // 'couturier' | 'autre'
  final bool active;
  final String? joinedAt;

  const StaffContact({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.type,
    required this.active,
    this.joinedAt,
  });

  factory StaffContact.fromJson(Map<String, dynamic> json) {
    return StaffContact(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String? ?? '',
      type: json['type'] as String,
      active: json['active'] as bool? ?? true,
      joinedAt: json['joined_at'] as String?,
    );
  }
}

class StaffPayInfo {
  final String staffId;
  final String fullName;
  final String phone;
  final String type;
  final bool active;
  final int? pieceRate;
  final int? monthlySalary;
  final int? salaryDueDay;

  const StaffPayInfo({
    required this.staffId,
    required this.fullName,
    required this.phone,
    required this.type,
    required this.active,
    this.pieceRate,
    this.monthlySalary,
    this.salaryDueDay,
  });

  factory StaffPayInfo.fromJson(Map<String, dynamic> json) {
    return StaffPayInfo(
      staffId: json['staff_id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String? ?? '',
      type: json['type'] as String,
      active: json['active'] as bool? ?? true,
      pieceRate: json['piece_rate'] as int?,
      monthlySalary: json['monthly_salary'] as int?,
      salaryDueDay: json['salary_due_day'] as int?,
    );
  }
}

class TailorEntry {
  final String id;
  final String tailorId;
  final String tailorName;
  final String entryDate;
  final int piecesCount;
  final int pieceRate;
  final int amount;

  const TailorEntry({
    required this.id,
    required this.tailorId,
    required this.tailorName,
    required this.entryDate,
    required this.piecesCount,
    required this.pieceRate,
    required this.amount,
  });

  factory TailorEntry.fromJson(Map<String, dynamic> json) {
    return TailorEntry(
      id: json['id'] as String,
      tailorId: json['tailor_id'] as String,
      tailorName: json['tailor_name'] as String? ?? '',
      entryDate: json['entry_date'] as String,
      piecesCount: json['pieces_count'] as int,
      pieceRate: json['piece_rate'] as int? ?? 0,
      amount: json['amount'] as int? ?? 0,
    );
  }
}

class WeeklyTailorSummary {
  final String weekId;
  final String tailorId;
  final String tailorName;
  final int piecesTotal;
  final int amountTotal;
  final int daysWorked;

  const WeeklyTailorSummary({
    required this.weekId,
    required this.tailorId,
    required this.tailorName,
    required this.piecesTotal,
    required this.amountTotal,
    required this.daysWorked,
  });

  factory WeeklyTailorSummary.fromJson(Map<String, dynamic> json) {
    return WeeklyTailorSummary(
      weekId: json['week_id'] as String? ?? '',
      tailorId: json['tailor_id'] as String,
      tailorName: json['tailor_name'] as String? ?? '',
      piecesTotal: json['pieces_total'] as int? ?? 0,
      amountTotal: json['amount_total'] as int? ?? 0,
      daysWorked: json['days_worked'] as int? ?? 0,
    );
  }
}

class StaffRepository {
  StaffRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<StaffContact>> listContacts() async {
    final dynamic res = await _api.get('/api/staff');
    return (res['items'] as List)
        .map((e) => StaffContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<StaffPayInfo>> listPayInfo() async {
    final dynamic res = await _api.get('/api/staff-pay');
    return (res['items'] as List)
        .map((e) => StaffPayInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StaffContact> createStaff({
    required String fullName,
    required String phone,
    required String type,
  }) async {
    final dynamic res = await _api.post('/api/staff', body: {
      'full_name': fullName,
      'phone': phone,
      'type': type,
    });
    return StaffContact.fromJson(res as Map<String, dynamic>);
  }

  Future<StaffContact> updateStaff(
    String id, {
    required String fullName,
    required String phone,
    required String type,
    required bool active,
  }) async {
    final dynamic res = await _api.put('/api/staff/$id', body: {
      'full_name': fullName,
      'phone': phone,
      'type': type,
      'active': active,
    });
    return StaffContact.fromJson(res as Map<String, dynamic>);
  }

  Future<void> updatePay(
    String staffId, {
    required int pieceRate,
    required int monthlySalary,
    required int salaryDueDay,
  }) async {
    await _api.put('/api/staff-pay/$staffId', body: {
      'piece_rate': pieceRate,
      'monthly_salary': monthlySalary,
      'salary_due_day': salaryDueDay,
    });
  }

  Future<List<TailorEntry>> listTailorEntries() async {
    final dynamic res = await _api.get('/api/tailor-entries');
    return (res['items'] as List)
        .map((e) => TailorEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TailorEntry> createTailorEntry({
    required String tailorId,
    required String entryDate,
    required int piecesCount,
  }) async {
    final dynamic res = await _api.post('/api/tailor-entries', body: {
      'tailor_id': tailorId,
      'entry_date': entryDate,
      'pieces_count': piecesCount,
    });
    return TailorEntry.fromJson(res as Map<String, dynamic>);
  }

  Future<void> correctTailorEntry(
    String entryId, {
    required int newPieces,
    required String reason,
  }) async {
    await _api.post('/api/tailor-entries/$entryId/corrections', body: {
      'new_pieces': newPieces,
      'reason': reason,
    });
  }

  Future<List<WeeklyTailorSummary>> listWeeklyTotals(String weekId) async {
    final dynamic res = await _api.get('/api/tailor-entries/weekly?week_id=$weekId');
    return (res['items'] as List)
        .map((e) => WeeklyTailorSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
