import 'dart:convert';
import '../../domain/entities/checklist_item.dart';
import '../../domain/entities/reminder.dart';

class ReminderModel extends Reminder {
  const ReminderModel({
    required super.id,
    super.batchGroupId,
    required super.title,
    super.notes,
    required super.scheduledAt,
    super.recurrenceType,
    super.weeklyDays,
    super.monthlyDay,
    super.monthlyLastDay,
    super.originYear,
    super.customIntervalValue,
    super.customIntervalUnit,
    super.preReminderMinutes,
    super.categoryId,
    super.alertMode,
    super.dismissChallenge,
    super.snoozeIntervalMinutes,
    super.maxSnoozeCount,
    super.currentSnoozeCount,
    super.alarmSoundId,
    super.isImportant,
    super.isActive,
    super.isCompleted,
    super.checklist,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ReminderModel.fromEntity(Reminder r) {
    return ReminderModel(
      id: r.id,
      batchGroupId: r.batchGroupId,
      title: r.title,
      notes: r.notes,
      scheduledAt: r.scheduledAt,
      recurrenceType: r.recurrenceType,
      weeklyDays: r.weeklyDays,
      monthlyDay: r.monthlyDay,
      monthlyLastDay: r.monthlyLastDay,
      originYear: r.originYear,
      customIntervalValue: r.customIntervalValue,
      customIntervalUnit: r.customIntervalUnit,
      preReminderMinutes: r.preReminderMinutes,
      categoryId: r.categoryId,
      alertMode: r.alertMode,
      dismissChallenge: r.dismissChallenge,
      snoozeIntervalMinutes: r.snoozeIntervalMinutes,
      maxSnoozeCount: r.maxSnoozeCount,
      currentSnoozeCount: r.currentSnoozeCount,
      alarmSoundId: r.alarmSoundId,
      isImportant: r.isImportant,
      isActive: r.isActive,
      isCompleted: r.isCompleted,
      checklist: r.checklist,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'batch_group_id': batchGroupId,
      'title': title,
      'notes': notes,
      'scheduled_at_ms': scheduledAt.millisecondsSinceEpoch,
      'recurrence_type': recurrenceType.index,
      'weekly_days_json': jsonEncode(weeklyDays),
      'monthly_day': monthlyDay,
      'monthly_last_day': monthlyLastDay ? 1 : 0,
      'origin_year': originYear,
      'custom_interval_value': customIntervalValue,
      'custom_interval_unit': customIntervalUnit.index,
      'pre_reminders_json': jsonEncode(preReminderMinutes),
      'category_id': categoryId,
      'alert_mode': alertMode.index,
      'dismiss_challenge': dismissChallenge.index,
      'snooze_interval_minutes': snoozeIntervalMinutes,
      'max_snooze_count': maxSnoozeCount,
      'current_snooze_count': currentSnoozeCount,
      'alarm_sound_id': alarmSoundId,
      'is_important': isImportant ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'is_completed': isCompleted ? 1 : 0,
      'checklist_json': jsonEncode(checklist.map((e) => e.toJson()).toList()),
      'created_at_ms': createdAt.millisecondsSinceEpoch,
      'updated_at_ms': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ReminderModel.fromDbMap(Map<String, dynamic> map) {
    final weeklyRaw = jsonDecode((map['weekly_days_json'] as String?) ?? '[]') as List<dynamic>;
    final preRaw = jsonDecode((map['pre_reminders_json'] as String?) ?? '[]') as List<dynamic>;
    final checklistRaw = jsonDecode((map['checklist_json'] as String?) ?? '[]') as List<dynamic>;

    return ReminderModel(
      id: map['id'] as String,
      batchGroupId: map['batch_group_id'] as String?,
      title: map['title'] as String,
      notes: (map['notes'] as String?) ?? '',
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(map['scheduled_at_ms'] as int),
      recurrenceType: RecurrenceType.values[(map['recurrence_type'] as int?) ?? 0],
      weeklyDays: weeklyRaw.map((e) => e as int).toList(),
      monthlyDay: map['monthly_day'] as int?,
      monthlyLastDay: (map['monthly_last_day'] as int? ?? 0) == 1,
      originYear: map['origin_year'] as int?,
      customIntervalValue: map['custom_interval_value'] as int?,
      customIntervalUnit: CustomIntervalUnit.values[(map['custom_interval_unit'] as int?) ?? 0],
      preReminderMinutes: preRaw.map((e) => e as int).toList(),
      categoryId: (map['category_id'] as String?) ?? 'personal',
      alertMode: AlertMode.strongAlarm,
      dismissChallenge: DismissChallenge.values[(map['dismiss_challenge'] as int?) ?? 0],
      snoozeIntervalMinutes: (map['snooze_interval_minutes'] as int?) ?? 10,
      maxSnoozeCount: (map['max_snooze_count'] as int?) ?? 3,
      currentSnoozeCount: (map['current_snooze_count'] as int?) ?? 0,
      alarmSoundId: (map['alarm_sound_id'] as String?) ?? 'system_default',
      isImportant: (map['is_important'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      checklist: checklistRaw
          .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at_ms'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at_ms'] as int),
    );
  }

  Map<String, dynamic> toBackupJson() => {
        'id': id,
        'batchGroupId': batchGroupId,
        'title': title,
        'notes': notes,
        'scheduledAt': scheduledAt.toIso8601String(),
        'recurrenceType': recurrenceType.name,
        'weeklyDays': weeklyDays,
        'monthlyDay': monthlyDay,
        'monthlyLastDay': monthlyLastDay,
        'originYear': originYear,
        'customIntervalValue': customIntervalValue,
        'customIntervalUnit': customIntervalUnit.name,
        'preReminderMinutes': preReminderMinutes,
        'categoryId': categoryId,
        'alertMode': alertMode.name,
        'dismissChallenge': dismissChallenge.name,
        'snoozeIntervalMinutes': snoozeIntervalMinutes,
        'maxSnoozeCount': maxSnoozeCount,
        'currentSnoozeCount': currentSnoozeCount,
        'alarmSoundId': alarmSoundId,
        'isImportant': isImportant,
        'isActive': isActive,
        'isCompleted': isCompleted,
        'checklist': checklist.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ReminderModel.fromBackupJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String,
      batchGroupId: json['batchGroupId'] as String?,
      title: json['title'] as String,
      notes: (json['notes'] as String?) ?? '',
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      recurrenceType: RecurrenceType.values.firstWhere(
        (e) => e.name == json['recurrenceType'],
        orElse: () => RecurrenceType.once,
      ),
      weeklyDays: ((json['weeklyDays'] as List<dynamic>?) ?? [])
          .map((e) => e as int)
          .toList(),
      monthlyDay: json['monthlyDay'] as int?,
      monthlyLastDay: json['monthlyLastDay'] as bool? ?? false,
      originYear: json['originYear'] as int?,
      customIntervalValue: json['customIntervalValue'] as int?,
      customIntervalUnit: CustomIntervalUnit.values.firstWhere(
        (e) => e.name == json['customIntervalUnit'],
        orElse: () => CustomIntervalUnit.days,
      ),
      preReminderMinutes: ((json['preReminderMinutes'] as List<dynamic>?) ?? [])
          .map((e) => e as int)
          .toList(),
      categoryId: (json['categoryId'] as String?) ?? 'personal',
      alertMode: AlertMode.strongAlarm,
      dismissChallenge: DismissChallenge.values.firstWhere(
        (e) => e.name == json['dismissChallenge'],
        orElse: () => DismissChallenge.slide,
      ),
      snoozeIntervalMinutes: (json['snoozeIntervalMinutes'] as int?) ?? 10,
      maxSnoozeCount: (json['maxSnoozeCount'] as int?) ?? 3,
      currentSnoozeCount: (json['currentSnoozeCount'] as int?) ?? 0,
      alarmSoundId: (json['alarmSoundId'] as String?) ?? 'aurora_chime',
      isImportant: json['isImportant'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      isCompleted: json['isCompleted'] as bool? ?? false,
      checklist: ((json['checklist'] as List<dynamic>?) ?? [])
          .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
