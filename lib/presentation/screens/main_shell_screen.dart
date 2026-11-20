import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/reminder.dart';
import '../../services/alarm_scheduler_service.dart';
import '../bloc/history/history_cubit.dart';
import '../bloc/reminder/reminder_bloc.dart';
import '../bloc/reminder/reminder_event.dart';
import '../bloc/settings/settings_cubit.dart';
import '../widgets/aurora_background.dart';
import '../widgets/floating_glass_nav.dart';
import 'calendar_screen.dart';
import 'create_edit_reminder_sheet.dart';
import 'full_screen_alarm_screen.dart';
import 'home_dashboard_screen.dart';
import 'settings_screen.dart';
import 'templates_history_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with WidgetsBindingObserver {
  int _tabIndex = 0;
  StreamSubscription<NotificationInteractionEvent>? _notifSub;
  Timer? _foregroundWatchdog;
  bool _isAlarmScreenOpen = false;
  final Set<String> _triggeredKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _notifSub = AlarmSchedulerService.instance.onInteraction
        .listen(_handleNotificationEvent);

    // Layer 1: Foreground Precision Watchdog (fires on the exact second while app is open)
    _foregroundWatchdog = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkDueReminders(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending =
          AlarmSchedulerService.instance.consumePendingLaunchEvent();
      if (pending != null) {
        _handleNotificationEvent(pending);
      } else {
        _checkDueReminders();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifSub?.cancel();
    _foregroundWatchdog?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDueReminders();
    }
  }

  void _checkDueReminders() {
    if (!mounted || _isAlarmScreenOpen) return;
    final now = DateTime.now();

    // Check 5-second test alarm first
    final testAt = AlarmSchedulerService.instance.pendingTestAlarmAt;
    if (testAt != null && !testAt.isAfter(now)) {
      AlarmSchedulerService.instance.pendingTestAlarmAt = null;
      _launchTestAlarm();
      return;
    }

    final reminderBloc = context.read<ReminderBloc>();
    if (reminderBloc.state.isLoading) return;

    // Catch due alarms (including recently missed within 12 hours after power-on)
    final catchUpLimit = now.subtract(const Duration(hours: 12));
    for (final r in reminderBloc.state.activeReminders) {
      if (!r.scheduledAt.isAfter(now) && r.scheduledAt.isAfter(catchUpLimit)) {
        final key = '${r.id}_${r.scheduledAt.millisecondsSinceEpoch}';
        if (!_triggeredKeys.contains(key)) {
          _triggeredKeys.add(key);
          _openAlarmScreen(r);
          return;
        }
      }
    }
  }

  void _launchTestAlarm({String? titleOverride}) {
    if (!mounted || _isAlarmScreenOpen) return;
    final settings = context.read<SettingsCubit>().state;
    final s = AppStrings(settings.locale);
    final now = DateTime.now();

    final testReminder = Reminder(
      id: AlarmSchedulerService.testAlarmId,
      title: titleOverride ??
          (s.isVi
              ? 'Báo thức thử nghiệm (5 giây)'
              : '5-Second Alarm Test'),
      notes: s.isVi
          ? 'Đánh thức màn hình khóa, chuông tăng dần và rung liên tục hoạt động thành công!'
          : 'Lockscreen wake-up, escalating ringtone & continuous vibration verified!',
      scheduledAt: now,
      alertMode: AlertMode.strongAlarm,
      dismissChallenge: DismissChallenge.slide,
      alarmSoundId: AppConstants.systemDefaultRingtoneToken,
      createdAt: now,
      updatedAt: now,
    );

    _isAlarmScreenOpen = true;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => FullScreenAlarmScreen(
              reminder: testReminder,
              strings: s,
              globalDefaultSoundId: settings.defaultAlarmSoundId,
              onDismissed: () {},
              onSnoozed: (_) {},
            ),
          ),
        )
        .whenComplete(() {
      _isAlarmScreenOpen = false;
    });
  }

  void _openAlarmScreen(Reminder target) {
    if (!mounted || _isAlarmScreenOpen) return;
    final reminderBloc = context.read<ReminderBloc>();
    final settings = context.read<SettingsCubit>().state;
    final s = AppStrings(settings.locale);

    _isAlarmScreenOpen = true;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => FullScreenAlarmScreen(
              reminder: target,
              strings: s,
              globalDefaultSoundId: settings.defaultAlarmSoundId,
              onDismissed: () {
                reminderBloc.add(CompleteReminder(target, locale: s.locale));
                context.read<HistoryCubit>().loadHistory();
              },
              onSnoozed: (mins) {
                reminderBloc.add(
                  SnoozeReminder(target, minutes: mins, locale: s.locale),
                );
                context.read<HistoryCubit>().loadHistory();
              },
            ),
          ),
        )
        .whenComplete(() {
      _isAlarmScreenOpen = false;
    });
  }

  void _handleNotificationEvent(NotificationInteractionEvent event) {
    if (!mounted) return;

    if (event.reminderId == AlarmSchedulerService.testAlarmId) {
      AlarmSchedulerService.instance.pendingTestAlarmAt = null;
      _launchTestAlarm(titleOverride: event.titleOverride);
      return;
    }

    final reminderBloc = context.read<ReminderBloc>();
    final settings = context.read<SettingsCubit>().state;
    final s = AppStrings(settings.locale);

    Reminder? target;
    for (final r in reminderBloc.state.reminders) {
      if (r.id == event.reminderId) {
        target = r;
        break;
      }
    }

    // If reminders haven't finished loading on cold boot yet, retry shortly
    if (target == null) {
      if (reminderBloc.state.isLoading) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _handleNotificationEvent(event);
        });
      }
      return;
    }

    if (event.actionId == AppConstants.actionComplete) {
      reminderBloc.add(CompleteReminder(target, locale: s.locale));
      context.read<HistoryCubit>().loadHistory();
      return;
    }

    if (event.actionId == AppConstants.actionSnooze10) {
      reminderBloc.add(
        SnoozeReminder(
          target,
          minutes: target.snoozeIntervalMinutes,
          locale: s.locale,
        ),
      );
      context.read<HistoryCubit>().loadHistory();
      return;
    }

    final key = '${target.id}_${target.scheduledAt.millisecondsSinceEpoch}';
    _triggeredKeys.add(key);
    _openAlarmScreen(target);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    final s = AppStrings(settings.locale);

    return Scaffold(
      extendBody: true,
      body: AuroraBackground(
        isDark: settings.isDarkAurora,
        child: IndexedStack(
          index: _tabIndex,
          children: [
            HomeDashboardScreen(
              onOpenSettings: () => setState(() => _tabIndex = 3),
            ),
            const CalendarScreen(),
            const TemplatesHistoryScreen(),
            const SettingsScreen(),
          ],
        ),
      ),
      floatingActionButton: _tabIndex < 3
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.auroraCyan, AppColors.auroraViolet],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.auroraCyan.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FloatingActionButton(
                elevation: 0,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  CreateEditReminderSheet.show(context);
                },
                child: const Icon(Icons.add_rounded, size: 30),
              ),
            )
          : null,
      bottomNavigationBar: FloatingGlassNav(
        currentIndex: _tabIndex,
        strings: s,
        onTap: (i) => setState(() => _tabIndex = i),
      ),
    );
  }
}
