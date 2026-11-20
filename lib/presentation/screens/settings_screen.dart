import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/reminder.dart';
import '../../services/alarm_scheduler_service.dart';
import '../../services/backup_restore_service.dart';
import '../../services/permission_guard_service.dart';
import '../../services/ringtone_service.dart';
import '../bloc/reminder/reminder_bloc.dart';
import '../bloc/reminder/reminder_event.dart';
import '../bloc/settings/settings_cubit.dart';
import '../widgets/glass_container.dart';
import '../widgets/ringtone_picker_sheet.dart';
import 'full_screen_alarm_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  SystemReliabilityStatus? _status;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _checking = true);
    final status = await PermissionGuardService.instance.checkAll();
    if (mounted) {
      setState(() {
        _status = status;
        _checking = false;
      });
    }
  }

  Future<void> _pickDefaultRingtone(
    AppStrings s,
    String currentDefaultId,
  ) async {
    final picked = await RingtonePickerSheet.show(
      context,
      selectedSoundId: currentDefaultId,
      globalDefaultId: currentDefaultId,
      strings: s,
      allowSystemDefault: false,
    );
    if (picked != null && mounted) {
      await context.read<SettingsCubit>().setDefaultAlarmSound(picked);
    }
  }

  Future<void> _exportBackup(AppStrings s) async {
    try {
      final reminders = context.read<ReminderBloc>().state.reminders;
      await BackupRestoreService.instance.exportRemindersToJson(reminders);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importBackup(AppStrings s) async {
    try {
      final imported =
          await BackupRestoreService.instance.importRemindersFromJson();
      if (imported != null && mounted) {
        context
            .read<ReminderBloc>()
            .add(ImportRemindersBackup(imported, locale: s.locale));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.isVi
                  ? 'Đã khôi phục ${imported.length} nhắc nhở!'
                  : 'Restored ${imported.length} reminders!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  void _previewAlarm(AppStrings s, String globalDefaultSoundId) {
    final now = DateTime.now();
    final demo = Reminder(
      id: 'demo_preview',
      title: s.isVi
          ? 'Báo thức thử nghiệm ChronoGlass'
          : 'ChronoGlass Alarm Preview',
      notes: s.isVi
          ? 'Kiểm tra âm lượng tăng dần, rung liên tục và thử thách tắt báo thức.'
          : 'Verify escalating volume, continuous vibration & dismiss challenge.',
      scheduledAt: now,
      alertMode: AlertMode.strongAlarm,
      dismissChallenge: DismissChallenge.slide,
      alarmSoundId: AppConstants.systemDefaultRingtoneToken,
      createdAt: now,
      updatedAt: now,
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullScreenAlarmScreen(
          reminder: demo,
          strings: s,
          globalDefaultSoundId: globalDefaultSoundId,
          onDismissed: () {},
          onSnoozed: (_) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    final s = AppStrings(settings.locale);
    final defaultRingtoneLabel = RingtoneService.instance
        .resolveRingtone(
          settings.defaultAlarmSoundId,
          globalDefaultId: settings.defaultAlarmSoundId,
        )
        .label(s.locale);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 128),
        physics: const BouncingScrollPhysics(),
        children: [
          Text(
            s.settingsTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),

          // Alarm Reliability & System Permission Guard Card
          GlassContainer(
            useBlur: true,
            borderRadius: 24,
            accentTint: (_status?.allReady ?? false)
                ? AppColors.success
                : AppColors.auroraAmber,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      (_status?.allReady ?? false)
                          ? Icons.verified_user_rounded
                          : Icons.shield_outlined,
                      color: (_status?.allReady ?? false)
                          ? AppColors.success
                          : AppColors.auroraAmber,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.reliabilityTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _refreshStatus,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  s.reliabilitySubtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                if (_checking)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_status != null) ...[
                  _PermRow(
                    title: s.permNotifications,
                    granted: _status!.notificationsGranted,
                    strings: s,
                    onFix: () async {
                      await PermissionGuardService.instance
                          .requestNotificationPermission();
                      _refreshStatus();
                    },
                  ),
                  _PermRow(
                    title: s.permExactAlarm,
                    granted: _status!.exactAlarmGranted,
                    strings: s,
                    onFix: () async {
                      await PermissionGuardService.instance
                          .openExactAlarmSettings();
                    },
                  ),
                  _PermRow(
                    title: s.permOverlay,
                    granted: _status!.overlayGranted,
                    strings: s,
                    onFix: () async {
                      await PermissionGuardService.instance
                          .openOverlaySettings();
                    },
                  ),
                  _PermRow(
                    title: s.permFullScreen,
                    granted: _status!.fullScreenIntentGranted,
                    strings: s,
                    onFix: () async {
                      await PermissionGuardService.instance
                          .openFullScreenIntentSettings();
                    },
                  ),
                  _PermRow(
                    title: s.permBattery,
                    granted: _status!.batteryOptimizationIgnored,
                    strings: s,
                    onFix: () async {
                      await PermissionGuardService.instance
                          .openBatteryOptimizationSettings();
                    },
                  ),
                  if (_status!.isAggressiveOem) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.auroraAmber.withValues(alpha: 0.14),
                      ),
                      child: Text(
                        '${_status!.deviceManufacturer} ${_status!.deviceModel}: ${s.oemGuardHint}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.auroraAmber,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.auroraViolet.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.auroraViolet.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.auroraCyan
                                  .withValues(alpha: 0.22),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => AlarmSchedulerService.instance
                                .openOemAutoStartSettings(),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                s.openAutoStartBtn,
                                maxLines: 1,
                                softWrap: false,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.auroraViolet
                                  .withValues(alpha: 0.24),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => AlarmSchedulerService.instance
                                .openNativeAppSettings(),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                s.openBgLockscreenPermsBtn,
                                maxLines: 1,
                                softWrap: false,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.oemStep1,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          s.oemStep2,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.auroraCyan.withValues(alpha: 0.10),
                      border: Border.all(
                        color: AppColors.auroraCyan.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.power_settings_new_rounded,
                          color: AppColors.auroraCyan,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.scheduledPowerOnTitle,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.auroraCyan,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.scheduledPowerOnDesc,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.35,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Appearance, Sound & Language
          Text(
            s.appearanceSection,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          GlassContainer(
            useBlur: false,
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    settings.isDarkAurora
                        ? s.themeDarkAurora
                        : s.themeCrystalLight,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  secondary: Icon(
                    settings.isDarkAurora
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: AppColors.auroraCyan,
                  ),
                  value: settings.isDarkAurora,
                  onChanged: (v) =>
                      context.read<SettingsCubit>().toggleTheme(v),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.music_note_rounded,
                    color: AppColors.auroraRose,
                  ),
                  title: Text(
                    s.defaultAlarmRingtone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    defaultRingtoneLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.auroraCyan,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      _pickDefaultRingtone(s, settings.defaultAlarmSoundId),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.translate_rounded,
                    color: AppColors.auroraViolet,
                  ),
                  title: Text(
                    s.languageLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 'vi',
                        label: Text('VI', maxLines: 1, softWrap: false),
                      ),
                      ButtonSegment(
                        value: 'en',
                        label: Text('EN', maxLines: 1, softWrap: false),
                      ),
                    ],
                    selected: {settings.locale},
                    onSelectionChanged: (v) =>
                        context.read<SettingsCubit>().setLocale(v.first),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Backup & Restore + Tools
          Text(
            s.backupSection,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          GlassContainer(
            useBlur: false,
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.upload_file_rounded,
                    color: AppColors.auroraCyan,
                  ),
                  title: Text(
                    s.exportJson,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _exportBackup(s),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.download_rounded,
                    color: AppColors.auroraEmerald,
                  ),
                  title: Text(
                    s.importJson,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _importBackup(s),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.sync_rounded,
                    color: AppColors.auroraViolet,
                  ),
                  title: Text(
                    s.rescheduleAll,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    context
                        .read<ReminderBloc>()
                        .add(ResyncAllAlarms(locale: s.locale));
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(s.resyncDone)));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.timer_rounded,
                    color: AppColors.auroraAmber,
                  ),
                  title: Text(
                    s.testAlarm5s,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.play_arrow_rounded),
                  onTap: () async {
                    await AlarmSchedulerService.instance
                        .scheduleQuickTestAlarm(locale: s.locale);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.testAlarm5sScheduled)),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.alarm_on_rounded,
                    color: AppColors.auroraRose,
                  ),
                  title: Text(
                    s.testAlarm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      _previewAlarm(s, settings.defaultAlarmSoundId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  final String title;
  final bool granted;
  final AppStrings strings;
  final VoidCallback onFix;

  const _PermRow({
    required this.title,
    required this.granted,
    required this.strings,
    required this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: granted ? AppColors.success : AppColors.auroraAmber,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          if (granted)
            Text(
              strings.statusReady,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            )
          else
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: onFix,
              child: Text(
                strings.statusActionNeeded,
                maxLines: 1,
                softWrap: false,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
