import '../entities/history_log.dart';
import '../entities/reminder.dart';

abstract class ReminderRepository {
  Future<List<Reminder>> getAllReminders();
  Future<Reminder?> getReminderById(String id);
  Future<void> upsertReminder(Reminder reminder);
  Future<void> upsertBatchReminders(List<Reminder> reminders);
  Future<void> deleteReminder(String id);
  Future<List<HistoryLog>> getHistoryLogs();
  Future<void> addHistoryLog(HistoryLog log);
  Future<void> clearHistoryLogs();
  Future<void> replaceAllReminders(List<Reminder> reminders);
}
