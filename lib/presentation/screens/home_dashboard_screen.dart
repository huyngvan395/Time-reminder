import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../bloc/history/history_cubit.dart';
import '../bloc/reminder/reminder_bloc.dart';
import '../bloc/reminder/reminder_event.dart';
import '../bloc/reminder/reminder_state.dart';
import '../bloc/settings/settings_cubit.dart';
import '../widgets/countdown_hero_card.dart';
import '../widgets/glass_container.dart';
import '../widgets/reminder_card.dart';
import 'create_edit_reminder_sheet.dart';

class HomeDashboardScreen extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const HomeDashboardScreen({super.key, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    final s = AppStrings(settings.locale);

    return BlocBuilder<ReminderBloc, ReminderState>(
      builder: (context, state) {
        final next = state.nextUpcoming;
        final filtered = state.filteredReminders;

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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ChronoGlass',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              s.greeting,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GlassContainer(
                        useBlur: false,
                        borderRadius: 14,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        onTap: onOpenSettings,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: AppColors.auroraCyan,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${state.activeReminders.length}',
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // First-launch Alarm Reliability onboarding banner
              if (!settings.onboardingReliabilityDismissed)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: GlassContainer(
                      useBlur: false,
                      borderRadius: 18,
                      accentTint: AppColors.auroraAmber,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_user_rounded,
                            color: AppColors.auroraAmber,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.reliabilityTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s.reliabilitySubtitle,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              context
                                  .read<SettingsCubit>()
                                  .dismissReliabilityBanner();
                              onOpenSettings();
                            },
                            child: Text(s.statusActionNeeded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Live Ticking Hero Countdown Card (true BackdropFilter)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                  child: CountdownHeroCard(
                    reminder: next,
                    category: next != null
                        ? settings.categoryById(next.categoryId)
                        : null,
                    strings: s,
                    onTap: next == null
                        ? null
                        : () => CreateEditReminderSheet.show(
                              context,
                              existing: next,
                            ),
                    onQuickAdd: () => CreateEditReminderSheet.show(context),
                  ),
                ),
              ),

              // Quick Filter Chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _FilterPill(
                        label: s.filterAll,
                        selected: state.filter == ReminderFilter.all,
                        onTap: () => context
                            .read<ReminderBloc>()
                            .add(const ChangeReminderFilter(ReminderFilter.all)),
                      ),
                      _FilterPill(
                        label: s.filterToday,
                        selected: state.filter == ReminderFilter.today,
                        onTap: () => context.read<ReminderBloc>().add(
                              const ChangeReminderFilter(ReminderFilter.today),
                            ),
                      ),
                      _FilterPill(
                        label: s.filterUpcoming,
                        selected: state.filter == ReminderFilter.upcoming,
                        onTap: () => context.read<ReminderBloc>().add(
                              const ChangeReminderFilter(
                                ReminderFilter.upcoming,
                              ),
                            ),
                      ),
                      _FilterPill(
                        label: s.filterImportant,
                        selected: state.filter == ReminderFilter.important,
                        onTap: () => context.read<ReminderBloc>().add(
                              const ChangeReminderFilter(
                                ReminderFilter.important,
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              if (state.isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.hourglass_empty_rounded,
                            size: 48,
                            color: AppColors.auroraCyan.withValues(alpha: 0.55),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.noUpcoming,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final r = filtered[index];
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.completedSnack)),
                          );
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${s.snoozedSnack} ${r.snoozeIntervalMinutes} ${s.minutesShort}',
                              ),
                            ),
                          );
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

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: selected
                ? const LinearGradient(
                    colors: [AppColors.auroraCyan, AppColors.auroraViolet],
                  )
                : null,
            color: selected
                ? null
                : (isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.white.withValues(alpha: 0.65)),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : AppColors.glassBorder(isDark),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? Colors.white
                  : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
