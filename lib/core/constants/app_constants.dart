import '../../domain/entities/ringtone_item.dart';

/// Core application constants for ChronoGlass.
class AppConstants {
  AppConstants._();

  static const String appName = 'ChronoGlass';
  static const String dbName = 'chronoglass.db';
  static const int dbVersion = 1;
  static const String settingsBoxName = 'chronoglass_settings';
  static const String ringtonesBoxName = 'chronoglass_ringtones';

  static const String defaultRingtoneId = 'morning_marimba';
  static const String systemDefaultRingtoneToken = 'system_default';

  // Notification channels
  static const String standardChannelId = 'chronoglass_standard_channel';
  static const String standardChannelName = 'ChronoGlass Reminders';
  static const String standardChannelDesc =
      'Standard heads-up reminder notifications with quick actions';

  static const String strongAlarmChannelId = 'chronoglass_strong_alarm_channel';
  static const String strongAlarmChannelName = 'ChronoGlass Strong Alarms';
  static const String strongAlarmChannelDesc =
      'High-priority full-screen lockscreen alarms with sound and vibration';

  static const String preReminderChannelId = 'chronoglass_pre_reminder_channel';
  static const String preReminderChannelName = 'ChronoGlass Pre-Reminders';
  static const String preReminderChannelDesc =
      'Early alerts before upcoming scheduled reminders';

  // Notification action IDs
  static const String actionComplete = 'action_complete';
  static const String actionSnooze10 = 'action_snooze_10';
  static const String actionDismiss = 'action_dismiss';

  // 6 Popular Built-in Polyphonic Alarm Ringtones (assets/sounds/)
  static const List<RingtoneItem> builtInRingtones = [
    RingtoneItem(
      id: 'morning_marimba',
      nameVi: 'Ban mai Marimba',
      nameEn: 'Morning Marimba',
      descriptionVi: 'Giai điệu marimba ấm áp, tươi vui chuẩn điện thoại hiện đại',
      descriptionEn: 'Warm upbeat marimba arpeggio',
      assetPath: 'sounds/morning_marimba.wav',
    ),
    RingtoneItem(
      id: 'aurora_chimes',
      nameVi: 'Chuông gió Cực Quang',
      nameEn: 'Aurora Chimes',
      descriptionVi: 'Hợp âm chuông pha lê trong trẻo, đánh thức nhẹ nhàng',
      descriptionEn: 'Gentle ascending crystalline bell chords',
      assetPath: 'sounds/aurora_chimes.wav',
    ),
    RingtoneItem(
      id: 'radar_pulse',
      nameVi: 'Radar Kinh Điển',
      nameEn: 'Classic Radar',
      descriptionVi: 'Nhịp điện tử rõ ràng, dứt khoát giúp tỉnh táo ngay',
      descriptionEn: 'Crisp rhythmic digital wake-up pulse',
      assetPath: 'sounds/radar_pulse.wav',
    ),
    RingtoneItem(
      id: 'daybreak_synth',
      nameVi: 'Bình minh Điện Tử',
      nameEn: 'Daybreak Synth',
      descriptionVi: 'Giai điệu synth hiện đại tràn đầy năng lượng buổi sáng',
      descriptionEn: 'Uplifting modern synth melody',
      assetPath: 'sounds/daybreak_synth.wav',
    ),
    RingtoneItem(
      id: 'zen_harp',
      nameVi: 'Đàn Hạc Thư Giãn',
      nameEn: 'Zen Harp',
      descriptionVi: 'Tiếng đàn hạc êm dịu cho các nhắc nhở nhẹ nhàng',
      descriptionEn: 'Soft harmonic harp progression',
      assetPath: 'sounds/zen_harp.wav',
    ),
    RingtoneItem(
      id: 'urgent_alarm',
      nameVi: 'Báo Thức Khẩn Cấp',
      nameEn: 'Urgent Wake-Up',
      descriptionVi: 'Tín hiệu đa âm mạnh mẽ dành cho người ngủ say',
      descriptionEn: 'High-energy multi-tone wake-up signal',
      assetPath: 'sounds/urgent_alarm.wav',
    ),
  ];

  // Snooze presets in minutes
  static const List<int> snoozePresets = [5, 10, 15, 30];

  // Pre-reminder presets in minutes
  static const List<int> preReminderPresets = [5, 15, 60, 1440];
}
