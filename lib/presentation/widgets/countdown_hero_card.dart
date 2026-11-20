import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/utils/recurrence_calculator.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/reminder_category.dart';
import 'glass_container.dart';

/// Top-level Hero Card with real-time ticking countdown & true BackdropFilter blur.
class CountdownHeroCard extends StatefulWidget {
  final Reminder? reminder;
  final ReminderCategory? category;
  final AppStrings strings;
  final VoidCallback? onTap;
  final VoidCallback? onQuickAdd;

  const CountdownHeroCard({
    super.key,
    required this.reminder,
    required this.category,
    required this.strings,
    this.onTap,
    this.onQuickAdd,
  });

  @override
  State<CountdownHeroCard> createState() => _CountdownHeroCardState();
}

class _CountdownHeroCardState extends State<CountdownHeroCard> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final reminder = widget.reminder;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (reminder == null) {
      return GlassContainer(
        useBlur: true,
        borderRadius: 24,
        padding: const EdgeInsets.all(22),
        accentTint: AppColors.auroraCyan,
        onTap: widget.onQuickAdd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.auroraCyan.withValues(alpha: 0.18),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.auroraCyan,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  s.nextUp,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.auroraCyan
                        : const Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              s.noUpcoming,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              s.noUpcomingSub,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    final catColor = widget.category?.color ?? AppColors.auroraCyan;
    final countdownText =
        DateTimeUtils.formatCountdown(reminder.scheduledAt, _now, s);
    final yearsCount = RecurrenceCalculator.computeAnniversaryCount(reminder);

    return GlassContainer(
      useBlur: true,
      borderRadius: 24,
      padding: const EdgeInsets.all(22),
      accentTint: catColor,
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: catColor.withValues(alpha: 0.2),
                    border: Border.all(color: catColor.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.category?.icon ?? Icons.alarm_rounded,
                        size: 14,
                        color: catColor,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.category?.label(s.locale) ?? s.nextUp,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: catColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            yearsCount != null
                ? '${reminder.title} ($yearsCount ${s.isVi ? 'năm' : 'yrs'})'
                : reminder.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            countdownText,
            style: AppTheme.tabularDigits(
              TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.auroraCyan : const Color(0xFF0284C7),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 15,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                DateTimeUtils.formatDateTime(
                  reminder.scheduledAt,
                  locale: s.locale,
                ),
                style: AppTheme.tabularDigits(
                  TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              if (reminder.preReminderMinutes.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.bolt_rounded,
                  size: 15,
                  color: AppColors.auroraAmber,
                ),
                const SizedBox(width: 2),
                Text(
                  '-${DateTimeUtils.formatPreReminderOffset(reminder.preReminderMinutes.first, s)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.auroraAmber,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
