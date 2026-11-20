import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/recurrence_calculator.dart';
import '../../../domain/entities/history_log.dart';
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

  Future<void> _onLoad(LoadReminders event, Emitter<ReminderState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final list = await _repository.getAllReminders();
      emit(state.copyWith(reminders: list, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onSave(SaveReminder event, Emitter<ReminderState> emit) async {
    await _repository.upsertReminder(event.reminder);
    await _scheduler.scheduleReminder(event.reminder, locale: event.locale);
    final list = await _repository.getAllReminders();
    emit(state.copyWith(reminders: list));
  }

  Future<void> _onSaveBatch(
    SaveBatchReminders event,
    Emitter<ReminderState> emit,
  ) async {
    await _repository.upsertBatchReminders(event.reminders);
    for (final r in event.reminders) {
      await _scheduler.scheduleReminder(r, locale: event.locale);
    }
    final list = await _repository.getAllReminders();
    emit(state.copyWith(reminders: list));
  }

  Future<void> _onDelete(
    DeleteReminder event,
    Emitter<ReminderState> emit,
  ) async {
    await _scheduler.cancelReminder(event.reminder);
    await _repository.deleteReminder(event.reminder.id);
    final list = await _repository.getAllReminders();
    emit(state.copyWith(reminders: list));
  }

  Future<void> _onToggleActive(
    ToggleReminderActive event,
    Emitter<ReminderState> emit,
  ) async {
    final updated = event.reminder.copyWith(
      isActive: event.isActive,
      updatedAt: DateTime.now(),
    );
    await _repository.upsertReminder(updated);
    if (event.isActive) {
      await _scheduler.scheduleReminder(updated, locale: event.locale);
    } else {
      await _scheduler.cancelReminder(updated);
    }
    final list = await _repository.getAllReminders();
    emit(state.copyWith(reminders: list));
  }

  Future<void> _onComplete(
    CompleteReminder event,
    Emitter<ReminderState> emit,
  ) async {
    final now = DateTime.now();
    await _scheduler.cancelReminder(event.reminder);

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
      // Advance recurring reminder and reset snooze counter & checklist
      final advanced = event.reminder.copyWith(
        scheduledAt: nextDate,
        currentSnoozeCount: 0,
        isCompleted: false,
        isActive: true,
        checklist: event.reminder.checklist
            .map((c) => c.copyWith(isDone: false))
            .toList(),
        updatedAt: now,
      );
      await _repository.upsertReminder(advanced);
      await _scheduler.scheduleReminder(advanced, locale: event.locale);
    } else {
      // Auto-archive one-time reminder after completion
      final archived = event.reminder.copyWith(
        isCompleted: true,
        isActive: false,
        updatedAt: now,
      );
      await _repository.upsertReminder(archived);
    }

    final list = await _repository.getAllReminders();
    emit(state.copyWith(reminders: list));
  }

  Future<void> _onSnooze(
    SnoozeReminder event,
    Emitter<ReminderState> emit,
  ) async {
    final now = DateTime.now();
    final snoozedAt = now.add(Duration(minutes: event.minutes));

    final updated = event.reminder.copyWith(
      scheduledAt: snoozedAt,
      currentSnoozeCount: event.reminder.currentSnoozeCount + 1,
      isActive: true,
      isCompleted: false,
      updatedAt: now,
    );

    await _repository.upsertReminder(updated);
    await _scheduler.scheduleReminder(updated, locale: event.locale);

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

    final list = await _repository.getAllReminders();
    emit(state.copyWith(reminders: list));
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
    final list = await _repository.getAllReminders();
    emit(state.copyWith(reminders: list));
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
    await _scheduler.rescheduleAllActive(list, locale: event.locale);
    emit(state.copyWith(reminders: list));
  }

  Future<void> _onImportBackup(
    ImportRemindersBackup event,
    Emitter<ReminderState> emit,
  ) async {
    await _repository.replaceAllReminders(event.reminders);
    await _scheduler.rescheduleAllActive(event.reminders, locale: event.locale);
    final list = await _repository.getAllReminders();
    emit(state.copyWith(reminders: list));
  }
}
