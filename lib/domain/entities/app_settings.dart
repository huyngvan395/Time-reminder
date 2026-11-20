import 'package:equatable/equatable.dart';
import 'reminder_category.dart';

class AppSettings extends Equatable {
  final bool isDarkAurora;
  final String locale; // 'vi' or 'en'
  final int defaultSnoozeMinutes;
  final int defaultMaxSnooze;
  final String defaultAlarmSoundId;
  final bool onboardingReliabilityDismissed;
  final List<ReminderCategory> customCategories;

  const AppSettings({
    this.isDarkAurora = true,
    this.locale = 'vi',
    this.defaultSnoozeMinutes = 10,
    this.defaultMaxSnooze = 3,
    this.defaultAlarmSoundId = 'morning_marimba',
    this.onboardingReliabilityDismissed = false,
    this.customCategories = const [],
  });

  List<ReminderCategory> get allCategories => [
        ...ReminderCategory.defaults(),
        ...customCategories,
      ];

  ReminderCategory categoryById(String id) {
    return allCategories.firstWhere(
      (c) => c.id == id,
      orElse: () => ReminderCategory.defaults().last,
    );
  }

  AppSettings copyWith({
    bool? isDarkAurora,
    String? locale,
    int? defaultSnoozeMinutes,
    int? defaultMaxSnooze,
    String? defaultAlarmSoundId,
    bool? onboardingReliabilityDismissed,
    List<ReminderCategory>? customCategories,
  }) {
    return AppSettings(
      isDarkAurora: isDarkAurora ?? this.isDarkAurora,
      locale: locale ?? this.locale,
      defaultSnoozeMinutes: defaultSnoozeMinutes ?? this.defaultSnoozeMinutes,
      defaultMaxSnooze: defaultMaxSnooze ?? this.defaultMaxSnooze,
      defaultAlarmSoundId: defaultAlarmSoundId ?? this.defaultAlarmSoundId,
      onboardingReliabilityDismissed:
          onboardingReliabilityDismissed ?? this.onboardingReliabilityDismissed,
      customCategories: customCategories ?? this.customCategories,
    );
  }

  @override
  List<Object?> get props => [
        isDarkAurora,
        locale,
        defaultSnoozeMinutes,
        defaultMaxSnooze,
        defaultAlarmSoundId,
        onboardingReliabilityDismissed,
        customCategories,
      ];
}
