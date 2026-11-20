import 'package:equatable/equatable.dart';

enum HistoryActionStatus { completed, snoozed, missed, dismissed }

class HistoryLog extends Equatable {
  final String id;
  final String reminderId;
  final String reminderTitle;
  final String categoryId;
  final HistoryActionStatus status;
  final DateTime scheduledAt;
  final DateTime actionAt;
  final String? note;

  const HistoryLog({
    required this.id,
    required this.reminderId,
    required this.reminderTitle,
    required this.categoryId,
    required this.status,
    required this.scheduledAt,
    required this.actionAt,
    this.note,
  });

  @override
  List<Object?> get props => [
        id,
        reminderId,
        reminderTitle,
        categoryId,
        status,
        scheduledAt,
        actionAt,
        note,
      ];
}
