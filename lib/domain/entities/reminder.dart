import 'package:equatable/equatable.dart';
import 'checklist_item.dart';

enum RecurrenceType { once, weekly, monthly, yearly, customInterval }

enum CustomIntervalUnit { days, hours }

enum AlertMode { standard, strongAlarm }

enum DismissChallenge { slide, hold3Sec, quickMath }

class Reminder extends Equatable {
  final String id;
  final String? batchGroupId;
  final String title;
  final String notes;
  final DateTime scheduledAt;
  final RecurrenceType recurrenceType;
  final List<int> weeklyDays; // 1 = Mon .. 7 = Sun
  final int? monthlyDay;
  final bool monthlyLastDay;
  final int? originYear; // For yearly birthday/anniversary age counter
  final int? customIntervalValue;
  final CustomIntervalUnit customIntervalUnit;
  final List<int> preReminderMinutes;
  final String categoryId;
  final AlertMode alertMode;
  final DismissChallenge dismissChallenge;
  final int snoozeIntervalMinutes;
  final int maxSnoozeCount;
  final int currentSnoozeCount;
  final String alarmSoundId;
  final bool isImportant;
  final bool isActive;
  final bool isCompleted;
  final List<ChecklistItem> checklist;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Reminder({
    required this.id,
    this.batchGroupId,
    required this.title,
    this.notes = '',
    required this.scheduledAt,
    this.recurrenceType = RecurrenceType.once,
    this.weeklyDays = const [],
    this.monthlyDay,
    this.monthlyLastDay = false,
    this.originYear,
    this.customIntervalValue,
    this.customIntervalUnit = CustomIntervalUnit.days,
    this.preReminderMinutes = const [],
    this.categoryId = 'personal',
    this.alertMode = AlertMode.strongAlarm,
    this.dismissChallenge = DismissChallenge.slide,
    this.snoozeIntervalMinutes = 10,
    this.maxSnoozeCount = 3,
    this.currentSnoozeCount = 0,
    this.alarmSoundId = 'system_default',
    this.isImportant = false,
    this.isActive = true,
    this.isCompleted = false,
    this.checklist = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get notificationId => id.hashCode & 0x7FFFFFFF;

  int preReminderNotificationId(int index) =>
      ((id.hashCode ^ (index + 1) * 31) & 0x7FFFFFFF);

  bool get canSnooze => currentSnoozeCount < maxSnoozeCount;

  Reminder copyWith({
    String? id,
    String? batchGroupId,
    String? title,
    String? notes,
    DateTime? scheduledAt,
    RecurrenceType? recurrenceType,
    List<int>? weeklyDays,
    int? monthlyDay,
    bool? monthlyLastDay,
    int? originYear,
    int? customIntervalValue,
    CustomIntervalUnit? customIntervalUnit,
    List<int>? preReminderMinutes,
    String? categoryId,
    AlertMode? alertMode,
    DismissChallenge? dismissChallenge,
    int? snoozeIntervalMinutes,
    int? maxSnoozeCount,
    int? currentSnoozeCount,
    String? alarmSoundId,
    bool? isImportant,
    bool? isActive,
    bool? isCompleted,
    List<ChecklistItem>? checklist,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      batchGroupId: batchGroupId ?? this.batchGroupId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      weeklyDays: weeklyDays ?? this.weeklyDays,
      monthlyDay: monthlyDay ?? this.monthlyDay,
      monthlyLastDay: monthlyLastDay ?? this.monthlyLastDay,
      originYear: originYear ?? this.originYear,
      customIntervalValue: customIntervalValue ?? this.customIntervalValue,
      customIntervalUnit: customIntervalUnit ?? this.customIntervalUnit,
      preReminderMinutes: preReminderMinutes ?? this.preReminderMinutes,
      categoryId: categoryId ?? this.categoryId,
      alertMode: alertMode ?? this.alertMode,
      dismissChallenge: dismissChallenge ?? this.dismissChallenge,
      snoozeIntervalMinutes:
          snoozeIntervalMinutes ?? this.snoozeIntervalMinutes,
      maxSnoozeCount: maxSnoozeCount ?? this.maxSnoozeCount,
      currentSnoozeCount: currentSnoozeCount ?? this.currentSnoozeCount,
      alarmSoundId: alarmSoundId ?? this.alarmSoundId,
      isImportant: isImportant ?? this.isImportant,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      checklist: checklist ?? this.checklist,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        batchGroupId,
        title,
        notes,
        scheduledAt,
        recurrenceType,
        weeklyDays,
        monthlyDay,
        monthlyLastDay,
        originYear,
        customIntervalValue,
        customIntervalUnit,
        preReminderMinutes,
        categoryId,
        alertMode,
        dismissChallenge,
        snoozeIntervalMinutes,
        maxSnoozeCount,
        currentSnoozeCount,
        alarmSoundId,
        isImportant,
        isActive,
        isCompleted,
        checklist,
        createdAt,
        updatedAt,
      ];
}
