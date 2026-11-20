import 'package:chronoglass/core/constants/app_constants.dart';
import 'package:chronoglass/core/utils/recurrence_calculator.dart';
import 'package:chronoglass/data/models/reminder_model.dart';
import 'package:chronoglass/domain/entities/checklist_item.dart';
import 'package:chronoglass/domain/entities/reminder.dart';
import 'package:chronoglass/services/ringtone_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecurrenceCalculator', () {
    final now = DateTime(2026, 1, 31, 9, 0);

    test('returns null for one-time reminder', () {
      final r = Reminder(
        id: '1',
        title: 'One-time',
        scheduledAt: now,
        recurrenceType: RecurrenceType.once,
        createdAt: now,
        updatedAt: now,
      );
      expect(RecurrenceCalculator.computeNextOccurrence(r, after: now), isNull);
    });

    test('handles monthly last day of month (Jan 31 -> Feb 28)', () {
      final r = Reminder(
        id: '2',
        title: 'Monthly Bill',
        scheduledAt: DateTime(2026, 1, 31, 9, 0),
        recurrenceType: RecurrenceType.monthly,
        monthlyLastDay: true,
        createdAt: now,
        updatedAt: now,
      );
      final next = RecurrenceCalculator.computeNextOccurrence(
        r,
        after: DateTime(2026, 1, 31, 9, 5),
      );
      expect(next, DateTime(2026, 2, 28, 9, 0));
    });

    test('computes yearly anniversary/age count accurately', () {
      final r = Reminder(
        id: '3',
        title: 'Birthday',
        scheduledAt: DateTime(2026, 10, 12, 8, 30),
        recurrenceType: RecurrenceType.yearly,
        originYear: 1996,
        createdAt: now,
        updatedAt: now,
      );
      expect(RecurrenceCalculator.computeAnniversaryCount(r), 30);
    });

    test('computes custom N hours interval', () {
      final r = Reminder(
        id: '4',
        title: 'Medication',
        scheduledAt: DateTime(2026, 1, 31, 8, 0),
        recurrenceType: RecurrenceType.customInterval,
        customIntervalValue: 6,
        customIntervalUnit: CustomIntervalUnit.hours,
        createdAt: now,
        updatedAt: now,
      );
      final next = RecurrenceCalculator.computeNextOccurrence(
        r,
        after: DateTime(2026, 1, 31, 10, 0),
      );
      expect(next, DateTime(2026, 1, 31, 14, 0));
    });

    test('filters pre-reminders strictly in the future', () {
      final target = DateTime(2026, 1, 31, 10, 0);
      final pre = RecurrenceCalculator.computePreReminderTimestamps(
        target,
        [5, 15, 60, 1440],
        now: DateTime(2026, 1, 31, 9, 30),
      );
      expect(pre, [
        DateTime(2026, 1, 31, 9, 55),
        DateTime(2026, 1, 31, 9, 45),
      ]);
    });
  });

  group('ReminderModel serialization', () {
    test('DB map and JSON backup round-trip preserves all fields', () {
      final now = DateTime(2026, 11, 20, 16, 0);
      final original = ReminderModel(
        id: 'rem_100',
        batchGroupId: 'batch_1',
        title: 'Đóng tiền điện',
        notes: 'Thanh toán qua app ngân hàng',
        scheduledAt: DateTime(2026, 11, 25, 9, 30),
        recurrenceType: RecurrenceType.monthly,
        weeklyDays: const [1, 3, 5],
        monthlyDay: 25,
        monthlyLastDay: false,
        preReminderMinutes: const [15, 60],
        categoryId: 'finance',
        alertMode: AlertMode.strongAlarm,
        dismissChallenge: DismissChallenge.quickMath,
        snoozeIntervalMinutes: 15,
        maxSnoozeCount: 4,
        alarmSoundId: 'crystal_pulse',
        isImportant: true,
        checklist: const [
          ChecklistItem(id: 'c1', title: 'Xem chỉ số điện', isDone: true),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final fromDb = ReminderModel.fromDbMap(original.toDbMap());
      expect(fromDb, original);

      final fromJson = ReminderModel.fromBackupJson(original.toBackupJson());
      expect(fromJson, original);

      // Legacy standard-mode JSON & DB rows automatically upgrade to strongAlarm
      final legacyJson = Map<String, dynamic>.from(original.toBackupJson())
        ..['alertMode'] = 'standard';
      expect(
        ReminderModel.fromBackupJson(legacyJson).alertMode,
        AlertMode.strongAlarm,
      );
      final legacyDb = Map<String, dynamic>.from(original.toDbMap())
        ..['alert_mode'] = 0;
      expect(
        ReminderModel.fromDbMap(legacyDb).alertMode,
        AlertMode.strongAlarm,
      );
    });
  });

  group('RingtoneService resolution', () {
    test('resolves system_default, built-in, legacy, and missing IDs gracefully', () {
      final svc = RingtoneService.instance;
      expect(svc.builtInRingtones.length, 6);

      final defResolved = svc.resolveRingtone(
        AppConstants.systemDefaultRingtoneToken,
        globalDefaultId: 'zen_harp',
      );
      expect(defResolved.id, 'zen_harp');

      final legacyResolved = svc.resolveRingtone('aurora_chime');
      expect(legacyResolved.id, 'aurora_chimes');

      final missingResolved = svc.resolveRingtone(
        'non_existent_custom_id',
        globalDefaultId: 'morning_marimba',
      );
      expect(missingResolved.id, 'morning_marimba');
    });
  });
}
