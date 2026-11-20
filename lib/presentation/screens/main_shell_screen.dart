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

class _MainShellScreenState extends State<MainShellScreen> {
  int _tabIndex = 0;
  StreamSubscription<NotificationInteractionEvent>? _notifSub;

  @override
  void initState() {
    super.initState();
    _notifSub = AlarmSchedulerService.instance.onInteraction
        .listen(_handleNotificationEvent);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending =
          AlarmSchedulerService.instance.consumePendingLaunchEvent();
      if (pending != null) {
        _handleNotificationEvent(pending);
      }
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  void _handleNotificationEvent(NotificationInteractionEvent event) {
    if (!mounted) return;
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
    if (target == null) return;

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

    if (event.isStrongAlarm || target.alertMode == AlertMode.strongAlarm) {
      final r = target;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => FullScreenAlarmScreen(
            reminder: r,
            strings: s,
            globalDefaultSoundId: settings.defaultAlarmSoundId,
            onDismissed: () {
              reminderBloc.add(CompleteReminder(r, locale: s.locale));
              context.read<HistoryCubit>().loadHistory();
            },
            onSnoozed: (mins) {
              reminderBloc.add(SnoozeReminder(r, minutes: mins, locale: s.locale));
              context.read<HistoryCubit>().loadHistory();
            },
          ),
        ),
      );
    } else {
      CreateEditReminderSheet.show(context, existing: target);
    }
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
