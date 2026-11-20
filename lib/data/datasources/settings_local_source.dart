import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/reminder_category.dart';

class SettingsLocalSource {
  Box<dynamic>? _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(AppConstants.settingsBoxName);
  }

  Box<dynamic> get _safeBox {
    if (_box == null) {
      throw StateError('SettingsLocalSource.init() must be called before use.');
    }
    return _box!;
  }

  AppSettings loadSettings() {
    final isDark = _safeBox.get('isDarkAurora', defaultValue: true) as bool;
    final locale = _safeBox.get('locale', defaultValue: 'vi') as String;
    final snoozeMin = _safeBox.get('defaultSnoozeMinutes', defaultValue: 10) as int;
    final maxSnooze = _safeBox.get('defaultMaxSnooze', defaultValue: 3) as int;
    final soundId = _safeBox.get(
      'defaultAlarmSoundId',
      defaultValue: AppConstants.defaultRingtoneId,
    ) as String;
    final onboardDismissed =
        _safeBox.get('onboardingReliabilityDismissed', defaultValue: false) as bool;
    final rawCustomCats =
        _safeBox.get('customCategoriesJson', defaultValue: '[]') as String;

    final customCategories = (jsonDecode(rawCustomCats) as List<dynamic>)
        .map((e) => ReminderCategory.fromJson(e as Map<String, dynamic>))
        .toList();

    return AppSettings(
      isDarkAurora: isDark,
      locale: locale,
      defaultSnoozeMinutes: snoozeMin,
      defaultMaxSnooze: maxSnooze,
      defaultAlarmSoundId: soundId,
      onboardingReliabilityDismissed: onboardDismissed,
      customCategories: customCategories,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _safeBox.putAll({
      'isDarkAurora': settings.isDarkAurora,
      'locale': settings.locale,
      'defaultSnoozeMinutes': settings.defaultSnoozeMinutes,
      'defaultMaxSnooze': settings.defaultMaxSnooze,
      'defaultAlarmSoundId': settings.defaultAlarmSoundId,
      'onboardingReliabilityDismissed': settings.onboardingReliabilityDismissed,
      'customCategoriesJson': jsonEncode(
        settings.customCategories.map((c) => c.toJson()).toList(),
      ),
    });
  }
}
