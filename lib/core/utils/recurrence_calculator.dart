import '../../domain/entities/reminder.dart';
import 'date_time_utils.dart';

/// Pure, timezone-safe recurrence & pre-reminder calculator.
class RecurrenceCalculator {
  RecurrenceCalculator._();

  /// Computes the next occurrence strictly after [reference] for a recurring reminder.
  /// Returns `null` for one-time reminders.
  static DateTime? computeNextOccurrence(Reminder reminder, {DateTime? after}) {
    final ref = after ?? DateTime.now();
    final base = reminder.scheduledAt;

    switch (reminder.recurrenceType) {
      case RecurrenceType.once:
        return null;

      case RecurrenceType.weekly:
        final days = reminder.weeklyDays.isEmpty
            ? [base.weekday]
            : (List<int>.from(reminder.weeklyDays)..sort());
        DateTime candidate = DateTime(
          ref.year,
          ref.month,
          ref.day,
          base.hour,
          base.minute,
        );
        for (int i = 0; i <= 7; i++) {
          final check = candidate.add(Duration(days: i));
          if (days.contains(check.weekday) && check.isAfter(ref)) {
            return check;
          }
        }
        return candidate.add(const Duration(days: 7));

      case RecurrenceType.monthly:
        int year = ref.year;
        int month = ref.month;
        for (int i = 0; i < 24; i++) {
          final maxDay = DateTimeUtils.daysInMonth(year, month);
          final targetDay = reminder.monthlyLastDay
              ? maxDay
              : (reminder.monthlyDay ?? base.day).clamp(1, maxDay);
          final candidate = DateTime(year, month, targetDay, base.hour, base.minute);
          if (candidate.isAfter(ref)) return candidate;
          month += 1;
          if (month > 12) {
            month = 1;
            year += 1;
          }
        }
        return null;

      case RecurrenceType.yearly:
        int year = ref.year;
        for (int i = 0; i < 5; i++) {
          final maxDay = DateTimeUtils.daysInMonth(year, base.month);
          final targetDay = base.day.clamp(1, maxDay);
          final candidate = DateTime(year, base.month, targetDay, base.hour, base.minute);
          if (candidate.isAfter(ref)) return candidate;
          year += 1;
        }
        return null;

      case RecurrenceType.customInterval:
        final value = (reminder.customIntervalValue ?? 1).clamp(1, 3650);
        final step = reminder.customIntervalUnit == CustomIntervalUnit.hours
            ? Duration(hours: value)
            : Duration(days: value);
        DateTime candidate = base;
        if (!candidate.isAfter(ref)) {
          final diffMs = ref.difference(candidate).inMilliseconds;
          final stepMs = step.inMilliseconds;
          final jumps = (diffMs ~/ stepMs) + 1;
          candidate = candidate.add(Duration(milliseconds: jumps * stepMs));
        }
        return candidate;
    }
  }

  /// Computes all pre-reminder timestamps that are still in the future.
  static List<DateTime> computePreReminderTimestamps(
    DateTime mainTrigger,
    List<int> preReminderMinutes, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final result = <DateTime>[];
    for (final mins in preReminderMinutes) {
      if (mins <= 0) continue;
      final trigger = mainTrigger.subtract(Duration(minutes: mins));
      if (trigger.isAfter(current)) {
        result.add(trigger);
      }
    }
    return result;
  }

  /// Calculates age or anniversary year count if [originYear] is set.
  static int? computeAnniversaryCount(Reminder reminder, {DateTime? atDate}) {
    if (reminder.recurrenceType != RecurrenceType.yearly ||
        reminder.originYear == null) {
      return null;
    }
    final targetYear = (atDate ?? reminder.scheduledAt).year;
    final years = targetYear - reminder.originYear!;
    return years >= 0 ? years : null;
  }
}
