import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';

/// Indexed SQLite persistence for thousands of scheduled reminders & audit logs.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final fullPath = join(dbPath, AppConstants.dbName);
    _db = await openDatabase(
      fullPath,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        batch_group_id TEXT,
        title TEXT NOT NULL,
        notes TEXT,
        scheduled_at_ms INTEGER NOT NULL,
        recurrence_type INTEGER NOT NULL,
        weekly_days_json TEXT,
        monthly_day INTEGER,
        monthly_last_day INTEGER NOT NULL DEFAULT 0,
        origin_year INTEGER,
        custom_interval_value INTEGER,
        custom_interval_unit INTEGER NOT NULL DEFAULT 0,
        pre_reminders_json TEXT,
        category_id TEXT NOT NULL,
        alert_mode INTEGER NOT NULL DEFAULT 0,
        dismiss_challenge INTEGER NOT NULL DEFAULT 0,
        snooze_interval_minutes INTEGER NOT NULL DEFAULT 10,
        max_snooze_count INTEGER NOT NULL DEFAULT 3,
        current_snooze_count INTEGER NOT NULL DEFAULT 0,
        alarm_sound_id TEXT NOT NULL DEFAULT 'aurora_chime',
        is_important INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_completed INTEGER NOT NULL DEFAULT 0,
        checklist_json TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_reminders_schedule ON reminders (is_active, is_completed, scheduled_at_ms)',
    );
    await db.execute(
      'CREATE INDEX idx_reminders_category ON reminders (category_id)',
    );

    await db.execute('''
      CREATE TABLE history_logs (
        id TEXT PRIMARY KEY,
        reminder_id TEXT NOT NULL,
        reminder_title TEXT NOT NULL,
        category_id TEXT NOT NULL,
        status INTEGER NOT NULL,
        scheduled_at_ms INTEGER NOT NULL,
        action_at_ms INTEGER NOT NULL,
        note TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_history_action_at ON history_logs (action_at_ms DESC)',
    );
  }
}
