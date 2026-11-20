import 'package:sqflite/sqflite.dart';
import '../../domain/entities/history_log.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/local_database.dart';
import '../models/history_log_model.dart';
import '../models/reminder_model.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  final LocalDatabase _localDb;

  ReminderRepositoryImpl({LocalDatabase? localDb})
      : _localDb = localDb ?? LocalDatabase.instance;

  @override
  Future<List<Reminder>> getAllReminders() async {
    final db = await _localDb.database;
    final rows = await db.query(
      'reminders',
      orderBy: 'is_completed ASC, scheduled_at_ms ASC',
    );
    return rows.map(ReminderModel.fromDbMap).toList();
  }

  @override
  Future<Reminder?> getReminderById(String id) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ReminderModel.fromDbMap(rows.first);
  }

  @override
  Future<void> upsertReminder(Reminder reminder) async {
    final db = await _localDb.database;
    final model = ReminderModel.fromEntity(reminder);
    await db.insert(
      'reminders',
      model.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> upsertBatchReminders(List<Reminder> reminders) async {
    final db = await _localDb.database;
    final batch = db.batch();
    for (final reminder in reminders) {
      batch.insert(
        'reminders',
        ReminderModel.fromEntity(reminder).toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> deleteReminder(String id) async {
    final db = await _localDb.database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<HistoryLog>> getHistoryLogs() async {
    final db = await _localDb.database;
    final rows = await db.query(
      'history_logs',
      orderBy: 'action_at_ms DESC',
      limit: 200,
    );
    return rows.map(HistoryLogModel.fromDbMap).toList();
  }

  @override
  Future<void> addHistoryLog(HistoryLog log) async {
    final db = await _localDb.database;
    await db.insert(
      'history_logs',
      HistoryLogModel.fromEntity(log).toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clearHistoryLogs() async {
    final db = await _localDb.database;
    await db.delete('history_logs');
  }

  @override
  Future<void> replaceAllReminders(List<Reminder> reminders) async {
    final db = await _localDb.database;
    await db.transaction((txn) async {
      await txn.delete('reminders');
      for (final r in reminders) {
        await txn.insert(
          'reminders',
          ReminderModel.fromEntity(r).toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
