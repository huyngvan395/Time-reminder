import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_time_utils.dart';
import '../bloc/history/history_cubit.dart';
import '../bloc/reminder/reminder_bloc.dart';
import '../bloc/reminder/reminder_event.dart';
import '../bloc/reminder/reminder_state.dart';
import '../bloc/settings/settings_cubit.dart';
import '../widgets/glass_calendar_picker.dart';
import '../widgets/reminder_card.dart';
import 'create_edit_reminder_sheet.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDay = DateTimeUtils.dateOnly(DateTime.now());
  bool _weeklyMode = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    final s = AppStrings(settings.locale);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ReminderBloc, ReminderState>(
      builder: (context, state) {
        final badgeCounts = state.remindersByDateMap
            .map((key, value) => MapEntry(key, value.length));
        final dayReminders = state.remindersForDate(_selectedDay);

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
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.calendarTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Dynamic-width Glass Segmented Toggle — never wraps "Tháng" onto 2 lines
                      IntrinsicWidth(
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.72),
                            border: Border.all(
                              color: AppColors.glassBorder(isDark),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SegmentTab(
                                label: s.monthView,
                                selected: !_weeklyMode,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _weeklyMode = false);
                                },
                              ),
                              _SegmentTab(
                                label: s.weekView,
                                selected: _weeklyMode,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _weeklyMode = true);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GlassCalendarPicker(
                    focusedMonth: _focusedMonth,
                    selectedDates: {_selectedDay},
                    weeklyMode: _weeklyMode,
                    badgeCounts: badgeCounts,
                    strings: s,
                    onDateTapped: (d) => setState(() {
                      _selectedDay = DateTimeUtils.dateOnly(d);
                      _focusedMonth = DateTime(d.year, d.month, 1);
                    }),
                    onMonthChanged: (m) => setState(() => _focusedMonth = m),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          DateTimeUtils.formatDate(
                            _selectedDay,
                            locale: s.locale,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.auroraCyan.withValues(alpha: 0.2),
                        ),
                        child: Text(
                          '${dayReminders.length}',
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.auroraCyan,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => CreateEditReminderSheet.show(
                          context,
                          initialDate: DateTime(
                            _selectedDay.year,
                            _selectedDay.month,
                            _selectedDay.day,
                            9,
                            0,
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          s.isVi ? 'Thêm ngày này' : 'Add on date',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (dayReminders.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available_rounded,
                          size: 36,
                          color: AppColors.auroraCyan.withValues(alpha: 0.45),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.noRemindersOnDay,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 128),
                  sliver: SliverList.builder(
                    itemCount: dayReminders.length,
                    itemBuilder: (context, idx) {
                      final r = dayReminders[idx];
                      final cat = settings.categoryById(r.categoryId);
                      return ReminderCard(
                        reminder: r,
                        category: cat,
                        strings: s,
                        onTap: () => CreateEditReminderSheet.show(
                          context,
                          existing: r,
                        ),
                        onToggleActive: (active) => context
                            .read<ReminderBloc>()
                            .add(ToggleReminderActive(r, active,
                                locale: s.locale)),
                        onComplete: () {
                          context.read<ReminderBloc>().add(
                                CompleteReminder(r, locale: s.locale),
                              );
                          context.read<HistoryCubit>().loadHistory();
                        },
                        onSnooze: () {
                          context.read<ReminderBloc>().add(
                                SnoozeReminder(
                                  r,
                                  minutes: r.snoozeIntervalMinutes,
                                  locale: s.locale,
                                ),
                              );
                          context.read<HistoryCubit>().loadHistory();
                        },
                        onToggleChecklistItem: (itemId) => context
                            .read<ReminderBloc>()
                            .add(ToggleChecklistItem(r, itemId)),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: selected
              ? const LinearGradient(
                  colors: [AppColors.auroraCyan, AppColors.auroraViolet],
                )
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected
                ? Colors.white
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}
