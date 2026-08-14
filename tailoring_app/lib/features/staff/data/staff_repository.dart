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
  final int? weeklySalary;
  final String payFrequency; // 'mensuel' | 'hebdo'

  const StaffPayInfo({
    required this.staffId,
    required this.fullName,
    required this.phone,
    required this.type,
    required this.active,
    this.pieceRate,
    this.monthlySalary,
    this.salaryDueDay,
    this.weeklySalary,
    this.payFrequency = 'mensuel',
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
      weeklySalary: json['weekly_salary'] as int?,
      payFrequency: json['pay_frequency'] as String? ?? 'mensuel',
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
  final bool voided;
  final bool corrected;
  final String? correctedBy;
  final String? correctedByName;
  final String? correctedAt;
  final String? correctionReason;

  const WeeklyDetailEntry({
    required this.id,
    required this.entryDate,
    required this.garmentType,
    required this.piecesCount,
    required this.pieceRate,
    required this.amount,
    this.clientName,
    this.orderId,
    this.voided = false,
    this.corrected = false,
    this.correctedBy,
    this.correctedByName,
    this.correctedAt,
    this.correctionReason,
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
        voided: json['voided'] as bool? ?? false,
        corrected: json['corrected'] as bool? ?? false,
        correctedBy: json['corrected_by'] as String?,
        correctedByName: json['corrected_by_name'] as String?,
        correctedAt: json['corrected_at'] as String?,
        correctionReason: json['correction_reason'] as String?,
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

/// A tailor's total for one month — used for the "who worked most" ranking.
class TailorMonthlyRank {
  final String tailorId;
  final String tailorName;
  final bool active;
  final int piecesTotal;
  final int amountTotal;
  final int daysWorked;

  const TailorMonthlyRank({
    required this.tailorId,
    required this.tailorName,
    required this.active,
    required this.piecesTotal,
    required this.amountTotal,
    required this.daysWorked,
  });

  factory TailorMonthlyRank.fromJson(Map<String, dynamic> json) =>
      TailorMonthlyRank(
        tailorId: json['tailor_id'] as String,
        tailorName: json['tailor_name'] as String? ?? '',
        active: json['active'] as bool? ?? true,
        piecesTotal: json['pieces_total'] as int? ?? 0,
        amountTotal: json['amount_total'] as int? ?? 0,
        daysWorked: json['days_worked'] as int? ?? 0,
      );
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

  /// Full hard-delete of a staff member (manager only). Wage/salary history is
  /// preserved server-side via name snapshots (migration 012).
  Future<void> deleteStaff(String id) async {
    await _api.delete('/api/staff/$id');
  }

  Future<void> updatePay(
    String staffId, {
    int? pieceRate,
    int? monthlySalary,
    int? salaryDueDay,
    int? weeklySalary,
    String? payFrequency,
  }) async {
    // Send null for fields that don't apply to the staff type. In particular
    // salary_due_day has a DB CHECK (BETWEEN 1 AND 31): 0 is rejected, null
    // is allowed, so couturiers (no monthly salary) must send null here.
    await _api.put('/api/staff-pay/$staffId', body: {
      'piece_rate': pieceRate,
      'monthly_salary': monthlySalary,
      'salary_due_day': salaryDueDay,
      'weekly_salary': weeklySalary,
      'pay_frequency': payFrequency,
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
    String? customClientName,
  }) async {
    // pieceRate is optional: when null the server falls back to the tailor's
    // configured rate, then the shop default. garmentType/orderId/customClientName are the
    // descriptive fields.
    final dynamic res = await _api.post('/api/tailor-entries', body: {
      'tailor_id': tailorId,
      'entry_date': entryDate,
      'pieces_count': piecesCount,
      if (pieceRate != null) 'piece_rate': pieceRate,
      if (garmentType != null && garmentType.isNotEmpty) 'garment_type': garmentType,
      if (orderId != null) 'order_id': orderId,
      if (customClientName != null && customClientName.isNotEmpty) 'custom_client_name': customClientName,
    });
    return TailorEntry.fromJson(res as Map<String, dynamic>);
  }

  /// The detailed week for one tailor (entries grouped Mon→Sun in the UI).
  Future<WeeklyDetail> weeklyDetail(String weekId, String tailorId) async {
    final dynamic res = await _api.get(
        '/api/tailor-entries/weekly-detail?week_id=$weekId&tailor_id=$tailorId');
    return WeeklyDetail.fromJson(res as Map<String, dynamic>);
  }

  /// Append-only correction of a daily entry. Any of quantity, garment type
  /// (model), client name or price-per-piece may be changed; [voided] cancels the entry
  /// (counts 0). Omitted fields keep their current value. Reason is mandatory.
  Future<void> correctTailorEntry(
    String entryId, {
    int? newPieces,
    int? newPieceRate,
    String? newGarmentType,
    String? newCustomClientName,
    String? newOrderId,
    bool? voided,
    required String reason,
  }) async {
    await _api.post('/api/tailor-entries/$entryId/corrections', body: {
      if (newPieces != null) 'new_pieces': newPieces,
      if (newPieceRate != null) 'new_piece_rate': newPieceRate,
      if (newGarmentType != null) 'new_garment_type': newGarmentType,
      if (newCustomClientName != null) 'new_custom_client_name': newCustomClientName,
      if (newOrderId != null) 'new_order_id': newOrderId,
      if (voided != null) 'voided': voided,
      'reason': reason,
    });
  }

  Future<List<WeeklyTailorSummary>> listWeeklyTotals(String weekId) async {
    final dynamic res = await _api.get('/api/tailor-entries/weekly?week_id=$weekId');
    return (res['items'] as List)
        .map((e) => WeeklyTailorSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Per-tailor totals for [month] ('YYYY-MM'), ranked highest-first.
  Future<List<TailorMonthlyRank>> monthlyRanking(String month) async {
    final dynamic res =
        await _api.get('/api/tailor-entries/monthly?month=$month');
    return (res['items'] as List)
        .map((e) => TailorMonthlyRank.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Lifetime performance + settlement for one staff member.
  /// The secretary receives the piece-work side only; the salary fields come
  /// back null for her because the server strips them (see staff.js).
  Future<StaffAllTimeSummary> allTimeSummary(String staffId) async {
    final dynamic res = await _api.get('/api/staff/$staffId/all-time-summary');
    return StaffAllTimeSummary.fromJson(res as Map<String, dynamic>);
  }
}

/// One row of the per-model breakdown ("Veste: 12 pièces, 60 000 FCFA").
class GarmentTally {
  final String garmentType;
  final int pieces;
  final int amount;

  const GarmentTally({
    required this.garmentType,
    required this.pieces,
    required this.amount,
  });

  factory GarmentTally.fromJson(Map<String, dynamic> j) => GarmentTally(
        garmentType: j['garment_type'] as String? ?? 'Non précisé',
        pieces: j['pieces'] as int? ?? 0,
        amount: j['amount'] as int? ?? 0,
      );
}

/// All-time sheet for a tailor or a monthly employee.
///
/// [salaryPaidTotal] and [netBalance] are null when the caller is the
/// secretary (the server never sends them to her), and [netBalance] is also
/// null for monthly staff, who have no piece work to net a payment against.
class StaffAllTimeSummary {
  final String staffId;
  final String fullName;
  final String type;
  final int piecesTotal;
  final int earnedTotal;
  final int daysWorked;
  final String? firstEntryDate;
  final String? lastEntryDate;
  final List<GarmentTally> byGarment;
  final int? salaryPaidTotal;
  final int? netBalance;

  const StaffAllTimeSummary({
    required this.staffId,
    required this.fullName,
    required this.type,
    required this.piecesTotal,
    required this.earnedTotal,
    required this.daysWorked,
    required this.byGarment,
    this.firstEntryDate,
    this.lastEntryDate,
    this.salaryPaidTotal,
    this.netBalance,
  });

  bool get showsMoneyOwed => salaryPaidTotal != null && netBalance != null;

  factory StaffAllTimeSummary.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> s =
        (j['staff'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return StaffAllTimeSummary(
      staffId: s['id'] as String? ?? '',
      fullName: s['full_name'] as String? ?? '',
      type: s['type'] as String? ?? 'couturier',
      piecesTotal: j['pieces_total'] as int? ?? 0,
      earnedTotal: j['earned_total'] as int? ?? 0,
      daysWorked: j['days_worked'] as int? ?? 0,
      firstEntryDate: j['first_entry_date'] as String?,
      lastEntryDate: j['last_entry_date'] as String?,
      byGarment: ((j['by_garment'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) => GarmentTally.fromJson(e as Map<String, dynamic>))
          .toList(),
      salaryPaidTotal: j['salary_paid_total'] as int?,
      netBalance: j['net_balance'] as int?,
    );
  }
}
