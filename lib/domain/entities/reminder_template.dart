import 'package:equatable/equatable.dart';
import 'reminder.dart';

class ReminderTemplate extends Equatable {
  final String id;
  final String titleVi;
  final String titleEn;
  final String notesVi;
  final String notesEn;
  final String categoryId;
  final RecurrenceType recurrenceType;
  final AlertMode alertMode;
  final DismissChallenge dismissChallenge;
  final List<int> preReminderMinutes;
  final int defaultHour;
  final int defaultMinute;
  final bool isImportant;

  const ReminderTemplate({
    required this.id,
    required this.titleVi,
    required this.titleEn,
    required this.notesVi,
    required this.notesEn,
    required this.categoryId,
    required this.recurrenceType,
    required this.alertMode,
    this.dismissChallenge = DismissChallenge.slide,
    this.preReminderMinutes = const [15],
    required this.defaultHour,
    required this.defaultMinute,
    this.isImportant = false,
  });

  String title(String locale) => locale == 'vi' ? titleVi : titleEn;
  String notes(String locale) => locale == 'vi' ? notesVi : notesEn;

  static List<ReminderTemplate> defaults() => const [
        ReminderTemplate(
          id: 'tpl_utility',
          titleVi: 'Đóng tiền điện / nước',
          titleEn: 'Pay Electricity & Water Bill',
          notesVi: 'Kiểm tra hóa đơn và thanh toán trước hạn để tránh phí phạt.',
          notesEn: 'Review monthly utility invoice and pay before due date.',
          categoryId: 'finance',
          recurrenceType: RecurrenceType.monthly,
          alertMode: AlertMode.strongAlarm,
          dismissChallenge: DismissChallenge.slide,
          preReminderMinutes: [1440, 60],
          defaultHour: 9,
          defaultMinute: 0,
          isImportant: true,
        ),
        ReminderTemplate(
          id: 'tpl_medicine',
          titleVi: 'Uống thuốc đúng giờ',
          titleEn: 'Take Medication',
          notesVi: 'Uống cùng một cốc nước ấm sau bữa ăn.',
          notesEn: 'Take prescribed dose with warm water after meal.',
          categoryId: 'health',
          recurrenceType: RecurrenceType.customInterval,
          alertMode: AlertMode.strongAlarm,
          dismissChallenge: DismissChallenge.hold3Sec,
          preReminderMinutes: [5],
          defaultHour: 8,
          defaultMinute: 0,
          isImportant: true,
        ),
        ReminderTemplate(
          id: 'tpl_meeting',
          titleVi: 'Họp định kỳ tuần',
          titleEn: 'Weekly Team Sync',
          notesVi: 'Chuẩn bị báo cáo tiến độ và các hạng mục cần trao đổi.',
          notesEn: 'Prepare sprint progress notes and blockers.',
          categoryId: 'work',
          recurrenceType: RecurrenceType.weekly,
          alertMode: AlertMode.strongAlarm,
          dismissChallenge: DismissChallenge.slide,
          preReminderMinutes: [15],
          defaultHour: 9,
          defaultMinute: 30,
          isImportant: false,
        ),
        ReminderTemplate(
          id: 'tpl_birthday',
          titleVi: 'Sinh nhật người thân',
          titleEn: 'Family / Friend Birthday',
          notesVi: 'Gửi lời chúc và chuẩn bị quà sớm.',
          notesEn: 'Send birthday wishes and prepare gift ahead of time.',
          categoryId: 'event',
          recurrenceType: RecurrenceType.yearly,
          alertMode: AlertMode.strongAlarm,
          dismissChallenge: DismissChallenge.slide,
          preReminderMinutes: [1440],
          defaultHour: 8,
          defaultMinute: 30,
          isImportant: true,
        ),
        ReminderTemplate(
          id: 'tpl_focus',
          titleVi: 'Ôn tập / Học ngoại ngữ',
          titleEn: 'Deep Study Session',
          notesVi: '45 phút tập trung cao độ, không xao nhãng.',
          notesEn: '45 minutes of focused study without distractions.',
          categoryId: 'study',
          recurrenceType: RecurrenceType.weekly,
          alertMode: AlertMode.strongAlarm,
          dismissChallenge: DismissChallenge.slide,
          preReminderMinutes: [10],
          defaultHour: 20,
          defaultMinute: 0,
        ),
      ];

  @override
  List<Object?> get props => [
        id,
        titleVi,
        titleEn,
        categoryId,
        recurrenceType,
        alertMode,
        defaultHour,
        defaultMinute,
      ];
}
