import 'package:equatable/equatable.dart';
import '../../../domain/entities/reminder.dart';

enum ReminderFilter { all, today, upcoming, important }

abstract class ReminderEvent extends Equatable {
  const ReminderEvent();

  @override
  List<Object?> get props => [];
}

class LoadReminders extends ReminderEvent {
  const LoadReminders();
}

class SaveReminder extends ReminderEvent {
  final Reminder reminder;
  final String locale;
  const SaveReminder(this.reminder, {this.locale = 'vi'});

  @override
  List<Object?> get props => [reminder, locale];
}

class SaveBatchReminders extends ReminderEvent {
  final List<Reminder> reminders;
  final String locale;
  const SaveBatchReminders(this.reminders, {this.locale = 'vi'});

  @override
  List<Object?> get props => [reminders, locale];
}

class DeleteReminder extends ReminderEvent {
  final Reminder reminder;
  const DeleteReminder(this.reminder);

  @override
  List<Object?> get props => [reminder];
}

class ToggleReminderActive extends ReminderEvent {
  final Reminder reminder;
  final bool isActive;
  final String locale;
  const ToggleReminderActive(this.reminder, this.isActive, {this.locale = 'vi'});

  @override
  List<Object?> get props => [reminder, isActive, locale];
}

class CompleteReminder extends ReminderEvent {
  final Reminder reminder;
  final String locale;
  const CompleteReminder(this.reminder, {this.locale = 'vi'});

  @override
  List<Object?> get props => [reminder, locale];
}

class SnoozeReminder extends ReminderEvent {
  final Reminder reminder;
  final int minutes;
  final String locale;
  const SnoozeReminder(this.reminder, {required this.minutes, this.locale = 'vi'});

  @override
  List<Object?> get props => [reminder, minutes, locale];
}

class ToggleChecklistItem extends ReminderEvent {
  final Reminder reminder;
  final String itemId;
  const ToggleChecklistItem(this.reminder, this.itemId);

  @override
  List<Object?> get props => [reminder, itemId];
}

class ChangeReminderFilter extends ReminderEvent {
  final ReminderFilter filter;
  const ChangeReminderFilter(this.filter);

  @override
  List<Object?> get props => [filter];
}

class ResyncAllAlarms extends ReminderEvent {
  final String locale;
  const ResyncAllAlarms({this.locale = 'vi'});

  @override
  List<Object?> get props => [locale];
}

class ImportRemindersBackup extends ReminderEvent {
  final List<Reminder> reminders;
  final String locale;
  const ImportRemindersBackup(this.reminders, {this.locale = 'vi'});

  @override
  List<Object?> get props => [reminders, locale];
}
