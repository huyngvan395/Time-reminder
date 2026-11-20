import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/models/reminder_model.dart';
import '../domain/entities/reminder.dart';

class BackupRestoreService {
  BackupRestoreService._();
  static final BackupRestoreService instance = BackupRestoreService._();

  Future<String> exportRemindersToJson(List<Reminder> reminders) async {
    final payload = {
      'app': 'ChronoGlass',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'count': reminders.length,
      'reminders': reminders
          .map((r) => ReminderModel.fromEntity(r).toBackupJson())
          .toList(),
    };

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/chronoglass_backup_$timestamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'ChronoGlass Backup',
      text: 'ChronoGlass reminders backup (${reminders.length} items)',
    );
    return file.path;
  }

  Future<List<Reminder>?> importRemindersFromJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return null;

    final file = File(result.files.single.path!);
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = decoded['reminders'] as List<dynamic>?;
    if (list == null) {
      throw const FormatException('Invalid ChronoGlass backup file');
    }

    return list
        .map((item) => ReminderModel.fromBackupJson(item as Map<String, dynamic>))
        .toList();
  }
}
