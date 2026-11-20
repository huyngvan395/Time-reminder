import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/recurrence_calculator.dart';
import '../../../domain/entities/history_log.dart';
import '../../../domain/entities/reminder.dart';
import '../../../domain/repositories/reminder_repository.dart';
import '../../../services/alarm_scheduler_service.dart';
import 'reminder_event.dart';
import 'reminder_state.dart';

class ReminderBloc extends Bloc<ReminderEvent, ReminderState> {
  final ReminderRepository _repository;
  final AlarmSchedulerService _scheduler;
  final _uuid = const Uuid();

  ReminderBloc({
    required ReminderRepository repository,
    AlarmSchedulerService? scheduler,
  })  : _repository = repository,
        _scheduler = scheduler ?? AlarmSchedulerService.instance,
        super(const ReminderState(isLoading: true)) {
    on<LoadReminders>(_onLoad);
    on<SaveReminder>(_onSave);
    on<SaveBatchReminders>(_onSaveBatch);
    on<DeleteReminder>(_onDelete);
    on<ToggleReminderActive>(_onToggleActive);
    on<CompleteReminder>(_onComplete);
    on<SnoozeReminder>(_onSnooze);
    on<ToggleChecklistItem>(_onToggleChecklist);
    on<ChangeReminderFilter>(_onChangeFilter);
    on<ResyncAllAlarms>(_onResyncAll);
    on<ImportRemindersBackup>(_onImportBackup);
  }

  Future<void> _safeSchedule(Reminder reminder, String locale) async {
    try {
      await _scheduler.scheduleReminder(reminder, locale: locale);
    } catch (e) {
      debugPrint('Alarm schedule warning (UI state preserved): $e');
    }
  }

  Future<void> _safeCancel(Reminder reminder) async {
    try {
      await _scheduler.cancelReminder(reminder);
    } catch (e) {
      debugPrint('Alarm cancel warning: $e');
    }
  }

  Future<void> _emitFreshList(Emitter<ReminderState> emit) async {
    final list = await _repository.getAllReminders();
    emit(
      state.copyWith(
        reminders: List<Reminder>.of(list),
        isLoading: false,
        revision: state.revision + 1,
      ),
    );
  }

  Future<void> _onLoad(LoadReminders event, Emitter<ReminderState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _emitFreshList(emit);
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onSave(SaveReminder event, Emitter<ReminderState> emit) async {
    final normalized = event.reminder.copyWith(alertMode: AlertMode.strongAlarm);
    await _repository.upsertReminder(normalized);
    await _safeSchedule(normalized, event.locale);
    await _emitFreshList(emit);
  }

  Future<void> _onSaveBatch(
    SaveBatchReminders event,
    Emitter<ReminderState> emit,
  ) async {
    final normalizedList = event.reminders
        .map((r) => r.copyWith(alertMode: AlertMode.strongAlarm))
        .toList();
    await _repository.upsertBatchReminders(normalizedList);
    for (final r in normalizedList) {
      await _safeSchedule(r, event.locale);
    }
    await _emitFreshList(emit);
  }

  Future<void> _onDelete(
    DeleteReminder event,
    Emitter<ReminderState> emit,
  ) async {
    await _safeCancel(event.reminder);
    await _repository.deleteReminder(event.reminder.id);
    await _emitFreshList(emit);
  }

  Future<void> _onToggleActive(
    ToggleReminderActive event,
    Emitter<ReminderState> emit,
  ) async {
    final updated = event.reminder.copyWith(
      isActive: event.isActive,
      alertMode: AlertMode.strongAlarm,
      updatedAt: DateTime.now(),
    );
    await _repository.upsertReminder(updated);
    if (event.isActive) {
      await _safeSchedule(updated, event.locale);
    } else {
      await _safeCancel(updated);
    }
    await _emitFreshList(emit);
  }

  Future<void> _onComplete(
    CompleteReminder event,
    Emitter<ReminderState> emit,
  ) async {
    final now = DateTime.now();
    await _safeCancel(event.reminder);

    await _repository.addHistoryLog(
      HistoryLog(
        id: _uuid.v4(),
        reminderId: event.reminder.id,
        reminderTitle: event.reminder.title,
        categoryId: event.reminder.categoryId,
        status: HistoryActionStatus.completed,
        scheduledAt: event.reminder.scheduledAt,
        actionAt: now,
      ),
    );

    final nextDate = RecurrenceCalculator.computeNextOccurrence(
      event.reminder,
      after: now,
    );

    if (nextDate != null) {
      final advanced = event.reminder.copyWith(
        scheduledAt: nextDate,
        alertMode: AlertMode.strongAlarm,
        currentSnoozeCount: 0,
        isCompleted: false,
        isActive: true,
        checklist: event.reminder.checklist
            .map((c) => c.copyWith(isDone: false))
            .toList(),
        updatedAt: now,
      );
      await _repository.upsertReminder(advanced);
      await _safeSchedule(advanced, event.locale);
    } else {
      final archived = event.reminder.copyWith(
        isCompleted: true,
        isActive: false,
        updatedAt: now,
      );
      await _repository.upsertReminder(archived);
    }

    await _emitFreshList(emit);
  }

  Future<void> _onSnooze(
    SnoozeReminder event,
    Emitter<ReminderState> emit,
  ) async {
    final now = DateTime.now();
    final snoozedAt = now.add(Duration(minutes: event.minutes));

    final updated = event.reminder.copyWith(
      scheduledAt: snoozedAt,
      alertMode: AlertMode.strongAlarm,
      currentSnoozeCount: event.reminder.currentSnoozeCount + 1,
      isActive: true,
      isCompleted: false,
      updatedAt: now,
    );

    await _repository.upsertReminder(updated);
    await _safeSchedule(updated, event.locale);

    await _repository.addHistoryLog(
      HistoryLog(
        id: _uuid.v4(),
        reminderId: event.reminder.id,
        reminderTitle: event.reminder.title,
        categoryId: event.reminder.categoryId,
        status: HistoryActionStatus.snoozed,
        scheduledAt: event.reminder.scheduledAt,
        actionAt: now,
        note: '+${event.minutes}m',
      ),
    );

    await _emitFreshList(emit);
  }

  Future<void> _onToggleChecklist(
    ToggleChecklistItem event,
    Emitter<ReminderState> emit,
  ) async {
    final updatedChecklist = event.reminder.checklist.map((item) {
      if (item.id == event.itemId) {
        return item.copyWith(isDone: !item.isDone);
      }
      return item;
    }).toList();

    final updated = event.reminder.copyWith(
      checklist: updatedChecklist,
      updatedAt: DateTime.now(),
    );
    await _repository.upsertReminder(updated);
    await _emitFreshList(emit);
  }

  void _onChangeFilter(
    ChangeReminderFilter event,
    Emitter<ReminderState> emit,
  ) {
    emit(state.copyWith(filter: event.filter));
  }

  Future<void> _onResyncAll(
    ResyncAllAlarms event,
    Emitter<ReminderState> emit,
  ) async {
    final list = await _repository.getAllReminders();
    try {
      await _scheduler.rescheduleAllActive(list, locale: event.locale);
    } catch (e) {
      debugPrint('Resync warning: $e');
    }
    await _emitFreshList(emit);
  }

  Future<void> _onImportBackup(
    ImportRemindersBackup event,
    Emitter<ReminderState> emit,
  ) async {
    final normalized = event.reminders
        .map((r) => r.copyWith(alertMode: AlertMode.strongAlarm))
        .toList();
    await _repository.replaceAllReminders(normalized);
    try {
      await _scheduler.rescheduleAllActive(normalized, locale: event.locale);
    } catch (e) {
      debugPrint('Import reschedule warning: $e');
    }
    await _emitFreshList(emit);
  }
}
