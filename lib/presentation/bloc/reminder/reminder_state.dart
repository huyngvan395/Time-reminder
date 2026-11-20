import 'package:equatable/equatable.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../domain/entities/reminder.dart';
import 'reminder_event.dart';

class ReminderState extends Equatable {
  final List<Reminder> reminders;
  final ReminderFilter filter;
  final bool isLoading;
  final String? error;

  const ReminderState({
    this.reminders = const [],
    this.filter = ReminderFilter.all,
    this.isLoading = false,
    this.error,
  });

  /// Active, uncompleted reminders sorted chronologically.
  List<Reminder> get activeReminders {
    final list = reminders
        .where((r) => !r.isCompleted && r.isActive)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  /// Next upcoming reminder for the Hero Countdown Card.
  Reminder? get nextUpcoming {
    final now = DateTime.now();
    final future = activeReminders
        .where((r) => r.scheduledAt.isAfter(now.subtract(const Duration(minutes: 1))))
        .toList();
    if (future.isNotEmpty) return future.first;
    return activeReminders.isNotEmpty ? activeReminders.first : null;
  }

  List<Reminder> get filteredReminders {
    final now = DateTime.now();
    final base = reminders.where((r) => !r.isCompleted).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    switch (filter) {
      case ReminderFilter.all:
        return base;
      case ReminderFilter.today:
        return base.where((r) => DateTimeUtils.isSameDay(r.scheduledAt, now)).toList();
      case ReminderFilter.upcoming:
        return base.where((r) => r.scheduledAt.isAfter(now)).toList();
      case ReminderFilter.important:
        return base.where((r) => r.isImportant).toList();
    }
  }

  List<Reminder> remindersForDate(DateTime date) {
    return reminders
        .where((r) => !r.isCompleted && DateTimeUtils.isSameDay(r.scheduledAt, date))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  Map<DateTime, List<Reminder>> get remindersByDateMap {
    final map = <DateTime, List<Reminder>>{};
    for (final r in reminders.where((e) => !e.isCompleted)) {
      final key = DateTimeUtils.dateOnly(r.scheduledAt);
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  ReminderState copyWith({
    List<Reminder>? reminders,
    ReminderFilter? filter,
    bool? isLoading,
    String? error,
  }) {
    return ReminderState(
      reminders: reminders ?? this.reminders,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [reminders, filter, isLoading, error];
}
