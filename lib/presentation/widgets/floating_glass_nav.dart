import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'glass_container.dart';

/// Floating frosted glass bottom navigation bar with BackdropFilter blur.
class FloatingGlassNav extends StatelessWidget {
  final int currentIndex;
  final AppStrings strings;
  final ValueChanged<int> onTap;

  const FloatingGlassNav({
    super.key,
    required this.currentIndex,
    required this.strings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.dashboard_rounded, strings.navHome),
      (Icons.calendar_month_rounded, strings.navCalendar),
      (Icons.history_rounded, strings.navTemplates),
      (Icons.tune_rounded, strings.navSettings),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GlassContainer(
          useBlur: true,
          blurSigma: 16,
          borderRadius: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == currentIndex;
              final (icon, label) = items[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: selected
                          ? LinearGradient(
                              colors: [
                                AppColors.auroraCyan
                                    .withValues(alpha: isDark ? 0.28 : 0.22),
                                AppColors.auroraViolet
                                    .withValues(alpha: isDark ? 0.24 : 0.18),
                              ],
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 22,
                          color: selected
                              ? (isDark
                                  ? AppColors.auroraCyan
                                  : const Color(0xFF0284C7))
                              : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                        ),
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? (isDark
                                        ? Colors.white
                                        : const Color(0xFF0284C7))
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
