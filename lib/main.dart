import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'data/datasources/settings_local_source.dart';
import 'data/repositories/reminder_repository_impl.dart';
import 'services/alarm_scheduler_service.dart';
import 'services/ringtone_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  final settingsSource = SettingsLocalSource();
  await settingsSource.init();
  await RingtoneService.instance.init();

  await AlarmSchedulerService.instance.init();

  final repository = ReminderRepositoryImpl();

  runApp(
    ChronoGlassApp(
      settingsSource: settingsSource,
      repository: repository,
    ),
  );
}
