import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_time_utils.dart';
import 'glass_container.dart';

/// Interactive Glass Calendar Picker supporting:
/// - Monthly or Weekly view
/// - Glowing dot badges indicating scheduled reminders per day
/// - Single-date selection OR Multi-date batch selection
class GlassCalendarPicker extends StatefulWidget {
  final DateTime focusedMonth;
  final Set<DateTime> selectedDates;
  final bool multiSelect;
  final bool weeklyMode;
  final Map<DateTime, int> badgeCounts;
  final AppStrings strings;
  final ValueChanged<DateTime> onDateTapped;
  final ValueChanged<DateTime> onMonthChanged;

  const GlassCalendarPicker({
    super.key,
    required this.focusedMonth,
    required this.selectedDates,
    required this.strings,
    required this.onDateTapped,
    required this.onMonthChanged,
    this.multiSelect = false,
    this.weeklyMode = false,
    this.badgeCounts = const {},
  });

  @override
  State<GlassCalendarPicker> createState() => _GlassCalendarPickerState();
}

class _GlassCalendarPickerState extends State<GlassCalendarPicker> {
  bool _isSelected(DateTime d) {
    return widget.selectedDates.any((s) => DateTimeUtils.isSameDay(s, d));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTimeUtils.dateOnly(DateTime.now());
    final focused = widget.focusedMonth;

    final List<DateTime?> cells = [];
    if (widget.weeklyMode) {
      final anchor = widget.selectedDates.isNotEmpty
          ? widget.selectedDates.first
          : today;
      final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
      for (int i = 0; i < 7; i++) {
        cells.add(DateTime(monday.year, monday.month, monday.day + i));
      }
    } else {
      final firstOfMonth = DateTime(focused.year, focused.month, 1);
      final leadingBlanks = firstOfMonth.weekday - 1; // Mon = 1
      final totalDays = DateTimeUtils.daysInMonth(focused.year, focused.month);
      for (int i = 0; i < leadingBlanks; i++) {
        cells.add(null);
      }
      for (int day = 1; day <= totalDays; day++) {
        cells.add(DateTime(focused.year, focused.month, day));
      }
    }

    return GlassContainer(
      useBlur: false,
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  widget.onMonthChanged(
                    DateTime(focused.year, focused.month - 1, 1),
                  );
                },
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  DateTimeUtils.formatMonthYear(
                    focused,
                    locale: widget.strings.locale,
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  widget.onMonthChanged(
                    DateTime(focused.year, focused.month + 1, 1),
                  );
                },
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: widget.strings.weekdayShort
                .map(
                  (d) => Expanded(
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final day = cells[index];
              if (day == null) return const SizedBox.shrink();

              final selected = _isSelected(day);
              final isToday = DateTimeUtils.isSameDay(day, today);
              final count = widget.badgeCounts[DateTimeUtils.dateOnly(day)] ?? 0;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onDateTapped(day);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: selected
                        ? const LinearGradient(
                            colors: [
                              AppColors.auroraCyan,
                              AppColors.auroraViolet,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    border: isToday && !selected
                        ? Border.all(
                            color: AppColors.auroraCyan.withValues(alpha: 0.75),
                            width: 1.3,
                          )
                        : null,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.auroraCyan.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: AppTheme.tabularDigits(
                          TextStyle(
                            fontSize: 14,
                            fontWeight: selected || isToday
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (count > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            count.clamp(1, 3),
                            (dotIdx) => Container(
                              width: 4.5,
                              height: 4.5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? Colors.white
                                    : (dotIdx == 0
                                        ? AppColors.auroraCyan
                                        : dotIdx == 1
                                            ? AppColors.auroraViolet
                                            : AppColors.auroraRose),
                                boxShadow: [
                                  BoxShadow(
                                    color: (selected
                                            ? Colors.white
                                            : AppColors.auroraCyan)
                                        .withValues(alpha: 0.7),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 4.5),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
