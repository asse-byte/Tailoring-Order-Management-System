import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../constants/app_constants.dart';

/// Single sqflite database for the app. Currently used by the offline
/// outbox; the schema is open for future read-side caches.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  Future<Database> open() async {
    if (_db != null) return _db!;
    final String dir = (await getApplicationDocumentsDirectory()).path;
    final String path = p.join(dir, AppConstants.localDbName);
    _db = await openDatabase(
      path,
      version: AppConstants.localDbVersion,
      onCreate: (db, version) async {
        await db.execute(_createOutboxOrders);
      },
      onUpgrade: (db, oldV, newV) async {
        // Reserved for future migrations.
      },
    );
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static const String _createOutboxOrders = '''
    CREATE TABLE IF NOT EXISTS outbox_orders (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      customer_name TEXT NOT NULL,
      payload TEXT NOT NULL,
      fabric_photo_path TEXT,
      style_photo_path TEXT,
      created_at INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT
    );
  ''';
}
