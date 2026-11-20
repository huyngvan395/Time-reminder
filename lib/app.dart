import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/settings_local_source.dart';
import 'data/repositories/reminder_repository_impl.dart';
import 'domain/entities/app_settings.dart';
import 'presentation/bloc/history/history_cubit.dart';
import 'presentation/bloc/reminder/reminder_bloc.dart';
import 'presentation/bloc/reminder/reminder_event.dart';
import 'presentation/bloc/settings/settings_cubit.dart';
import 'presentation/screens/main_shell_screen.dart';

class ChronoGlassApp extends StatelessWidget {
  final SettingsLocalSource settingsSource;
  final ReminderRepositoryImpl repository;

  const ChronoGlassApp({
    super.key,
    required this.settingsSource,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SettingsCubit(settingsSource)),
        BlocProvider(
          create: (_) =>
              ReminderBloc(repository: repository)..add(const LoadReminders()),
        ),
        BlocProvider(
          create: (_) => HistoryCubit(repository)..loadHistory(),
        ),
      ],
      child: BlocBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) {
          return MaterialApp(
            title: 'ChronoGlass',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.crystalLight(),
            darkTheme: AppTheme.darkAurora(),
            themeMode:
                settings.isDarkAurora ? ThemeMode.dark : ThemeMode.light,
            locale: Locale(settings.locale),
            supportedLocales: const [Locale('vi'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const MainShellScreen(),
          );
        },
      ),
    );
  }
}
