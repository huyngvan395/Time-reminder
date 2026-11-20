import '../../domain/entities/history_log.dart';

class HistoryLogModel extends HistoryLog {
  const HistoryLogModel({
    required super.id,
    required super.reminderId,
    required super.reminderTitle,
    required super.categoryId,
    required super.status,
    required super.scheduledAt,
    required super.actionAt,
    super.note,
  });

  factory HistoryLogModel.fromEntity(HistoryLog log) {
    return HistoryLogModel(
      id: log.id,
      reminderId: log.reminderId,
      reminderTitle: log.reminderTitle,
      categoryId: log.categoryId,
      status: log.status,
      scheduledAt: log.scheduledAt,
      actionAt: log.actionAt,
      note: log.note,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'reminder_id': reminderId,
        'reminder_title': reminderTitle,
        'category_id': categoryId,
        'status': status.index,
        'scheduled_at_ms': scheduledAt.millisecondsSinceEpoch,
        'action_at_ms': actionAt.millisecondsSinceEpoch,
        'note': note,
      };

  factory HistoryLogModel.fromDbMap(Map<String, dynamic> map) {
    return HistoryLogModel(
      id: map['id'] as String,
      reminderId: map['reminder_id'] as String,
      reminderTitle: map['reminder_title'] as String,
      categoryId: (map['category_id'] as String?) ?? 'personal',
      status: HistoryActionStatus.values[(map['status'] as int?) ?? 0],
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(map['scheduled_at_ms'] as int),
      actionAt: DateTime.fromMillisecondsSinceEpoch(map['action_at_ms'] as int),
      note: map['note'] as String?,
    );
  }
}
