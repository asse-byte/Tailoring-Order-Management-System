import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/data/local_database.dart';
import '../domain/entities/order.dart';

/// One queued offline order, with copies of any picked images stored
/// in the app documents directory so they survive picker-cache cleanup.
class OutboxEntry {
  OutboxEntry({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.order,
    required this.createdAt,
    this.fabricPhotoPath,
    this.stylePhotoPath,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String customerId;
  final String customerName;
  final TailoringOrder order;
  final DateTime createdAt;
  final String? fabricPhotoPath;
  final String? stylePhotoPath;
  final int attempts;
  final String? lastError;
}

/// Persists offline orders + their picked images.
class OrdersOutbox {
  OrdersOutbox({LocalDatabase? db}) : _db = db ?? LocalDatabase.instance;

  final LocalDatabase _db;
  final Uuid _uuid = const Uuid();

  /// Copies the picked images into a permanent location, then records
  /// the order in the outbox table.
  Future<OutboxEntry> enqueue({
    required TailoringOrder order,
    File? fabricPhoto,
    File? stylePhoto,
  }) async {
    final db = await _db.open();
    final String id = _uuid.v4();

    final String? fabricPath = fabricPhoto == null
        ? null
        : await _persistImage(id, 'fabric', fabricPhoto);
    final String? stylePath = stylePhoto == null
        ? null
        : await _persistImage(id, 'style', stylePhoto);

    // Reuse the order's `toMap()` shape, minus FieldValue server timestamps.
    final Map<String, dynamic> payload = <String, dynamic>{
      'orderId': id,
      'customerId': order.customerId,
      'customerName': order.customerName,
      'garmentType': order.garmentType,
      'fabricDescription': order.fabricDescription,
      'specialInstructions': order.specialInstructions,
      'deliveryDate': order.deliveryDate.toIso8601String(),
      'status': order.status,
      'price': order.price,
      'adminNotes': order.adminNotes,
      'measurementsSnapshot': order.measurementsSnapshot,
      'statusHistory': order.statusHistory
          .map((e) => <String, dynamic>{
                'status': e.status,
                'changedAt': e.changedAt.toIso8601String(),
                'changedBy': e.changedBy,
                'note': e.note,
              })
          .toList(growable: false),
    };

    await db.insert(
      'outbox_orders',
      <String, Object?>{
        'id': id,
        'customer_id': order.customerId,
        'customer_name': order.customerName,
        'payload': jsonEncode(payload),
        'fabric_photo_path': fabricPath,
        'style_photo_path': stylePath,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'attempts': 0,
        'last_error': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return OutboxEntry(
      id: id,
      customerId: order.customerId,
      customerName: order.customerName,
      order: order.copyWith(),
      createdAt: DateTime.now(),
      fabricPhotoPath: fabricPath,
      stylePhotoPath: stylePath,
    );
  }

  Future<List<OutboxEntry>> all() async {
    final db = await _db.open();
    final List<Map<String, Object?>> rows = await db.query(
      'outbox_orders',
      orderBy: 'created_at ASC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<int> count() async {
    final db = await _db.open();
    final List<Map<String, Object?>> rows =
        await db.rawQuery('SELECT COUNT(*) AS c FROM outbox_orders');
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<int> countForCustomer(String customerId) async {
    final db = await _db.open();
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM outbox_orders WHERE customer_id = ?',
      <Object?>[customerId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> markAttempt(String id, {String? error}) async {
    final db = await _db.open();
    await db.rawUpdate(
      'UPDATE outbox_orders SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      <Object?>[error, id],
    );
  }

  Future<void> remove(String id) async {
    final db = await _db.open();
    final OutboxEntry? entry = await _findById(id);
    await db.delete('outbox_orders', where: 'id = ?', whereArgs: <Object?>[id]);
    // Best-effort cleanup of persisted images.
    for (final String? path in <String?>[
      entry?.fabricPhotoPath,
      entry?.stylePhotoPath,
    ]) {
      if (path == null) continue;
      try {
        final File f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {/* ignore */}
    }
  }

  // ---------- helpers ----------

  Future<OutboxEntry?> _findById(String id) async {
    final db = await _db.open();
    final List<Map<String, Object?>> rows = await db.query(
      'outbox_orders',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  OutboxEntry _fromRow(Map<String, Object?> row) {
    final Map<String, dynamic> payload =
        jsonDecode(row['payload'] as String) as Map<String, dynamic>;
    final List<StatusEvent> history =
        ((payload['statusHistory'] as List<dynamic>?) ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map((m) => StatusEvent(
                  status:
                      (m['status'] as String?) ?? AppConstants.statusPending,
                  changedAt: DateTime.parse(m['changedAt'] as String),
                  changedBy: (m['changedBy'] as String?) ?? '',
                  note: (m['note'] as String?) ?? '',
                ))
            .toList(growable: false);

    final TailoringOrder order = TailoringOrder(
      id: row['id'] as String,
      customerId: row['customer_id'] as String,
      customerName: row['customer_name'] as String,
      garmentType: (payload['garmentType'] as String?) ?? '',
      fabricDescription: (payload['fabricDescription'] as String?) ?? '',
      specialInstructions: (payload['specialInstructions'] as String?) ?? '',
      deliveryDate: DateTime.parse(payload['deliveryDate'] as String),
      price: (payload['price'] as num?)?.toDouble(),
      status: (payload['status'] as String?) ?? AppConstants.statusPending,
      statusHistory: history,
      adminNotes: (payload['adminNotes'] as String?) ?? '',
      measurementsSnapshot: Map<String, dynamic>.from(
          payload['measurementsSnapshot'] as Map<String, dynamic>? ??
              <String, dynamic>{}),
    );

    return OutboxEntry(
      id: row['id'] as String,
      customerId: row['customer_id'] as String,
      customerName: row['customer_name'] as String,
      order: order,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      fabricPhotoPath: row['fabric_photo_path'] as String?,
      stylePhotoPath: row['style_photo_path'] as String?,
      attempts: (row['attempts'] as int?) ?? 0,
      lastError: row['last_error'] as String?,
    );
  }

  Future<String> _persistImage(
      String entryId, String label, File source) async {
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(base.path, 'outbox', entryId));
    if (!await dir.exists()) await dir.create(recursive: true);
    final String ext = p.extension(source.path);
    final String dest = p.join(dir.path, '$label$ext');
    await source.copy(dest);
    return dest;
  }
}
