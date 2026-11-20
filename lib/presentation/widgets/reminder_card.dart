import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/utils/recurrence_calculator.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/reminder_category.dart';
import 'glass_container.dart';

/// High-performance 60fps list item card (uses gradient glass WITHOUT per-item BackdropFilter).
/// Supports swipe-right to Complete and swipe-left to Snooze.
class ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final ReminderCategory category;
  final AppStrings strings;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onComplete;
  final VoidCallback onSnooze;
  final ValueChanged<String>? onToggleChecklistItem;

  const ReminderCard({
    super.key,
    required this.reminder,
    required this.category,
    required this.strings,
    required this.onTap,
    required this.onToggleActive,
    required this.onComplete,
    required this.onSnooze,
    this.onToggleChecklistItem,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final yearsCount = RecurrenceCalculator.computeAnniversaryCount(reminder);
    final doneTasks = reminder.checklist.where((c) => c.isDone).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('dismiss_${reminder.id}'),
        confirmDismiss: (direction) async {
          HapticFeedback.mediumImpact();
          if (direction == DismissDirection.startToEnd) {
            onComplete();
          } else {
            onSnooze();
          }
          return false;
        },
        background: _SwipeBg(
          alignment: Alignment.centerLeft,
          color: AppColors.success,
          icon: Icons.check_circle_rounded,
          label: strings.swipeComplete,
        ),
        secondaryBackground: _SwipeBg(
          alignment: Alignment.centerRight,
          color: AppColors.auroraViolet,
          icon: Icons.snooze_rounded,
          label: strings.swipeSnooze,
        ),
        child: Opacity(
          opacity: reminder.isActive ? 1.0 : 0.55,
          child: GlassContainer(
            useBlur: false, // Crucial 60fps rule for scrolling ListView items!
            borderRadius: 20,
            accentTint: reminder.alertMode == AlertMode.strongAlarm
                ? AppColors.auroraRose
                : category.color,
            padding: const EdgeInsets.all(16),
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: category.color.withValues(alpha: 0.18),
                        border: Border.all(
                          color: category.color.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(category.icon, color: category.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  yearsCount != null
                                      ? '${reminder.title} • $yearsCount ${strings.isVi ? 'tuổi/năm' : 'yrs'}'
                                      : reminder.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (reminder.isImportant)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: AppColors.auroraAmber,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                DateTimeUtils.formatTime(reminder.scheduledAt),
                                style: AppTheme.tabularDigits(
                                  TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: reminder.alertMode ==
                                            AlertMode.strongAlarm
                                        ? AppColors.auroraRose
                                        : (isDark
                                            ? AppColors.auroraCyan
                                            : const Color(0xFF0284C7)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  DateTimeUtils.formatDate(
                                    reminder.scheduledAt,
                                    locale: strings.locale,
                                  ),
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.tabularDigits(
                                    TextStyle(
                                      fontSize: 12.5,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              if (reminder.recurrenceType !=
                                  RecurrenceType.once) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.repeat_rounded,
                                  size: 14,
                                  color: isDark
                                      ? AppColors.auroraViolet
                                      : const Color(0xFF6366F1),
                                ),
                              ],
                              if (reminder.alertMode ==
                                  AlertMode.strongAlarm) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.alarm_on_rounded,
                                  size: 14,
                                  color: AppColors.auroraRose,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: reminder.isActive,
                      activeTrackColor: category.color.withValues(alpha: 0.65),
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        onToggleActive(v);
                      },
                    ),
                  ],
                ),
                if (reminder.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    reminder.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                  ),
                ],
                if (reminder.checklist.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...reminder.checklist.take(3).map(
                            (item) => GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onToggleChecklistItem?.call(item.id);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: (item.isDone
                                          ? AppColors.success
                                          : Colors.white)
                                      .withValues(alpha: isDark ? 0.10 : 0.50),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item.isDone
                                          ? Icons.check_box_rounded
                                          : Icons.check_box_outline_blank_rounded,
                                      size: 14,
                                      color: item.isDone
                                          ? AppColors.success
                                          : (isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        decoration: item.isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      if (reminder.checklist.length > 3)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          child: Text(
                            '$doneTasks/${reminder.checklist.length}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  const _SwipeBg({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.22),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
