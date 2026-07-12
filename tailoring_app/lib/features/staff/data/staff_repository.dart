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
  final String garmentType;
  final String? orderId;
  final String? clientName;

  const TailorEntry({
    required this.id,
    required this.tailorId,
    required this.tailorName,
    required this.entryDate,
    required this.piecesCount,
    required this.pieceRate,
    required this.amount,
    this.garmentType = '',
    this.orderId,
    this.clientName,
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
      garmentType: json['garment_type'] as String? ?? '',
      orderId: json['order_id'] as String?,
      clientName: json['client_name'] as String?,
    );
  }
}

/// One line of a tailor's weekly detail (item 6): what was sewn, for whom.
class WeeklyDetailEntry {
  final String id;
  final String entryDate;
  final String garmentType;
  final int piecesCount;
  final int pieceRate;
  final int amount;
  final String? clientName;
  final String? orderId;

  const WeeklyDetailEntry({
    required this.id,
    required this.entryDate,
    required this.garmentType,
    required this.piecesCount,
    required this.pieceRate,
    required this.amount,
    this.clientName,
    this.orderId,
  });

  factory WeeklyDetailEntry.fromJson(Map<String, dynamic> json) =>
      WeeklyDetailEntry(
        id: json['id'] as String,
        entryDate: json['entry_date'] as String,
        garmentType: json['garment_type'] as String? ?? '',
        piecesCount: json['pieces_count'] as int? ?? 0,
        pieceRate: json['piece_rate'] as int? ?? 0,
        amount: json['amount'] as int? ?? 0,
        clientName: json['client_name'] as String?,
        orderId: json['order_id'] as String?,
      );
}

/// A tailor's full week, its entries and the weekly total.
class WeeklyDetail {
  final String weekId;
  final String tailorId;
  final List<WeeklyDetailEntry> items;
  final int total;

  const WeeklyDetail({
    required this.weekId,
    required this.tailorId,
    required this.items,
    required this.total,
  });

  factory WeeklyDetail.fromJson(Map<String, dynamic> json) => WeeklyDetail(
        weekId: json['week_id'] as String? ?? '',
        tailorId: json['tailor_id'] as String? ?? '',
        items: (json['items'] as List? ?? [])
            .map((e) => WeeklyDetailEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
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
    int? pieceRate,
    int? monthlySalary,
    int? salaryDueDay,
  }) async {
    // Send null for fields that don't apply to the staff type. In particular
    // salary_due_day has a DB CHECK (BETWEEN 1 AND 31): 0 is rejected, null
    // is allowed, so couturiers (no monthly salary) must send null here.
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
    int? pieceRate,
    String? garmentType,
    String? orderId,
  }) async {
    // pieceRate is optional: when null the server falls back to the tailor's
    // configured rate, then the shop default. garmentType/orderId are the
    // item-6 descriptive fields (client name is derived from the order).
    final dynamic res = await _api.post('/api/tailor-entries', body: {
      'tailor_id': tailorId,
      'entry_date': entryDate,
      'pieces_count': piecesCount,
      if (pieceRate != null) 'piece_rate': pieceRate,
      if (garmentType != null && garmentType.isNotEmpty) 'garment_type': garmentType,
      if (orderId != null) 'order_id': orderId,
    });
    return TailorEntry.fromJson(res as Map<String, dynamic>);
  }

  /// The detailed week for one tailor (entries grouped Mon→Sun in the UI).
  Future<WeeklyDetail> weeklyDetail(String weekId, String tailorId) async {
    final dynamic res = await _api.get(
        '/api/tailor-entries/weekly-detail?week_id=$weekId&tailor_id=$tailorId');
    return WeeklyDetail.fromJson(res as Map<String, dynamic>);
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
