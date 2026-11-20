import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/datasources/settings_local_source.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/reminder_category.dart';

class SettingsCubit extends Cubit<AppSettings> {
  final SettingsLocalSource _source;

  SettingsCubit(this._source) : super(_source.loadSettings());

  Future<void> toggleTheme(bool isDarkAurora) async {
    final next = state.copyWith(isDarkAurora: isDarkAurora);
    emit(next);
    await _source.saveSettings(next);
  }

  Future<void> setLocale(String locale) async {
    final next = state.copyWith(locale: locale);
    emit(next);
    await _source.saveSettings(next);
  }

  Future<void> setDefaultSnooze(int minutes) async {
    final next = state.copyWith(defaultSnoozeMinutes: minutes);
    emit(next);
    await _source.saveSettings(next);
  }

  Future<void> setDefaultMaxSnooze(int count) async {
    final next = state.copyWith(defaultMaxSnooze: count);
    emit(next);
    await _source.saveSettings(next);
  }

  Future<void> setDefaultAlarmSound(String soundId) async {
    final next = state.copyWith(defaultAlarmSoundId: soundId);
    emit(next);
    await _source.saveSettings(next);
  }

  Future<void> dismissReliabilityBanner() async {
    final next = state.copyWith(onboardingReliabilityDismissed: true);
    emit(next);
    await _source.saveSettings(next);
  }

  Future<void> addCustomCategory(ReminderCategory category) async {
    final updated = [...state.customCategories, category];
    final next = state.copyWith(customCategories: updated);
    emit(next);
    await _source.saveSettings(next);
  }

  Future<void> removeCustomCategory(String id) async {
    final updated = state.customCategories.where((c) => c.id != id).toList();
    final next = state.copyWith(customCategories: updated);
    emit(next);
    await _source.saveSettings(next);
  }
}
