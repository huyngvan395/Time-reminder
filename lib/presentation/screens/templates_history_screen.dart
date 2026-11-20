import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_time_utils.dart';
import '../../domain/entities/history_log.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/reminder_template.dart';
import '../bloc/history/history_cubit.dart';
import '../bloc/settings/settings_cubit.dart';
import '../widgets/glass_container.dart';
import 'create_edit_reminder_sheet.dart';

class TemplatesHistoryScreen extends StatelessWidget {
  const TemplatesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    final s = AppStrings(settings.locale);
    final templates = ReminderTemplate.defaults();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Text(
                s.quickTemplates,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 148,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: templates.length,
                itemBuilder: (context, idx) {
                  final tpl = templates[idx];
                  final cat = settings.categoryById(tpl.categoryId);
                  return Container(
                    width: 210,
                    margin: const EdgeInsets.only(right: 12),
                    child: GlassContainer(
                      useBlur: false,
                      borderRadius: 20,
                      accentTint: cat.color,
                      padding: const EdgeInsets.all(14),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        CreateEditReminderSheet.show(
                          context,
                          fromTemplate: tpl,
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: cat.color.withValues(alpha: 0.2),
                                ),
                                child: Icon(cat.icon, color: cat.color, size: 17),
                              ),
                              const Spacer(),
                              if (tpl.alertMode == AlertMode.strongAlarm)
                                const Icon(
                                  Icons.alarm_on_rounded,
                                  size: 16,
                                  color: AppColors.auroraRose,
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            tpl.title(s.locale),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${tpl.defaultHour.toString().padLeft(2, '0')}:${tpl.defaultMinute.toString().padLeft(2, '0')} • ${cat.label(s.locale)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.historyLog,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        context.read<HistoryCubit>().clearHistory(),
                    child: Text(
                      s.clearHistory,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
          BlocBuilder<HistoryCubit, HistoryState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (state.logs.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 100),
                      child: Text(
                        s.noHistory,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: SliverList.builder(
                  itemCount: state.logs.length,
                  itemBuilder: (context, idx) {
                    final log = state.logs[idx];
                    final (statusColor, statusLabel, icon) = switch (log.status) {
                      HistoryActionStatus.completed => (
                          AppColors.success,
                          s.statusCompleted,
                          Icons.check_circle_rounded,
                        ),
                      HistoryActionStatus.snoozed => (
                          AppColors.auroraViolet,
                          s.statusSnoozed,
                          Icons.snooze_rounded,
                        ),
                      HistoryActionStatus.missed => (
                          AppColors.danger,
                          s.statusMissed,
                          Icons.error_outline_rounded,
                        ),
                      HistoryActionStatus.dismissed => (
                          AppColors.auroraCyan,
                          s.statusDismissed,
                          Icons.alarm_off_rounded,
                        ),
                    };

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassContainer(
                        useBlur: false,
                        borderRadius: 18,
                        accentTint: statusColor,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor.withValues(alpha: 0.18),
                              ),
                              child: Icon(icon, color: statusColor, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.reminderTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    DateTimeUtils.formatDateTime(
                                      log.actionAt,
                                      locale: s.locale,
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: statusColor.withValues(alpha: 0.16),
                              ),
                              child: Text(
                                log.note != null
                                    ? '$statusLabel (${log.note})'
                                    : statusLabel,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
