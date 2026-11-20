import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_time_utils.dart';
import '../../domain/entities/checklist_item.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/reminder_category.dart';
import '../../domain/entities/reminder_template.dart';
import '../../services/ringtone_service.dart';
import '../bloc/reminder/reminder_bloc.dart';
import '../bloc/reminder/reminder_event.dart';
import '../bloc/settings/settings_cubit.dart';
import '../widgets/glass_calendar_picker.dart';
import '../widgets/glass_container.dart';
import '../widgets/ringtone_picker_sheet.dart';
import '../widgets/wheel_time_picker.dart';

class CreateEditReminderSheet extends StatefulWidget {
  final Reminder? existing;
  final ReminderTemplate? fromTemplate;
  final DateTime? initialDate;

  const CreateEditReminderSheet({
    super.key,
    this.existing,
    this.fromTemplate,
    this.initialDate,
  });

  static Future<void> show(
    BuildContext context, {
    Reminder? existing,
    ReminderTemplate? fromTemplate,
    DateTime? initialDate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateEditReminderSheet(
        existing: existing,
        fromTemplate: fromTemplate,
        initialDate: initialDate,
      ),
    );
  }

  @override
  State<CreateEditReminderSheet> createState() =>
      _CreateEditReminderSheetState();
}

class _CreateEditReminderSheetState extends State<CreateEditReminderSheet> {
  final _uuid = const Uuid();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  final TextEditingController _subtaskController = TextEditingController();
  final TextEditingController _originYearController = TextEditingController();
  final TextEditingController _customIntervalController =
      TextEditingController(text: '2');
  final TextEditingController _customPreMinController = TextEditingController();

  late DateTime _focusedMonth;
  late Set<DateTime> _selectedDates;
  bool _multiDateMode = false;
  late int _hour;
  late int _minute;
  late RecurrenceType _recurrenceType;
  late Set<int> _weeklyDays;
  bool _monthlyLastDay = false;
  CustomIntervalUnit _customIntervalUnit = CustomIntervalUnit.days;
  late Set<int> _preReminderMinutes;
  late String _categoryId;
  late DismissChallenge _dismissChallenge;
  late int _snoozeIntervalMinutes;
  late int _maxSnoozeCount;
  late String _alarmSoundId;
  late bool _isImportant;
  late List<ChecklistItem> _checklist;

  String? _validationError;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsCubit>().state;
    final e = widget.existing;
    final t = widget.fromTemplate;
    final now = DateTime.now();
    final defaultDt =
        widget.initialDate ?? now.add(const Duration(minutes: 30));

    _titleController = TextEditingController(
      text: e?.title ?? (t?.title(settings.locale) ?? ''),
    );
    _notesController = TextEditingController(
      text: e?.notes ?? (t?.notes(settings.locale) ?? ''),
    );

    final startDt = e?.scheduledAt ??
        (t != null
            ? DateTime(
                defaultDt.year,
                defaultDt.month,
                defaultDt.day,
                t.defaultHour,
                t.defaultMinute,
              )
            : defaultDt);

    _focusedMonth = DateTime(startDt.year, startDt.month, 1);
    _selectedDates = {DateTimeUtils.dateOnly(startDt)};
    _hour = startDt.hour;
    _minute = startDt.minute;

    _recurrenceType =
        e?.recurrenceType ?? t?.recurrenceType ?? RecurrenceType.once;
    _weeklyDays = (e?.weeklyDays.isNotEmpty ?? false)
        ? e!.weeklyDays.toSet()
        : {startDt.weekday};
    _monthlyLastDay = e?.monthlyLastDay ?? false;
    if (e?.originYear != null) {
      _originYearController.text = e!.originYear.toString();
    }
    if (e?.customIntervalValue != null) {
      _customIntervalController.text = e!.customIntervalValue.toString();
    }
    _customIntervalUnit = e?.customIntervalUnit ?? CustomIntervalUnit.days;
    _preReminderMinutes =
        (e?.preReminderMinutes ?? t?.preReminderMinutes ?? const <int>[])
            .toSet();
    _categoryId = e?.categoryId ?? t?.categoryId ?? 'personal';
    _dismissChallenge =
        e?.dismissChallenge ?? t?.dismissChallenge ?? DismissChallenge.slide;
    _snoozeIntervalMinutes =
        e?.snoozeIntervalMinutes ?? settings.defaultSnoozeMinutes;
    _maxSnoozeCount = e?.maxSnoozeCount ?? settings.defaultMaxSnooze;
    _alarmSoundId =
        e?.alarmSoundId ?? AppConstants.systemDefaultRingtoneToken;
    _isImportant = e?.isImportant ?? t?.isImportant ?? false;
    _checklist = List<ChecklistItem>.from(e?.checklist ?? const []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _subtaskController.dispose();
    _originYearController.dispose();
    _customIntervalController.dispose();
    _customPreMinController.dispose();
    super.dispose();
  }

  void _onDateTapped(DateTime day) {
    final normalized = DateTimeUtils.dateOnly(day);
    setState(() {
      if (_multiDateMode && widget.existing == null) {
        if (_selectedDates.contains(normalized)) {
          if (_selectedDates.length > 1) {
            _selectedDates.remove(normalized);
          }
        } else {
          _selectedDates.add(normalized);
        }
      } else {
        _selectedDates = {normalized};
      }
      _validationError = null;
    });
  }

  void _addSubtask() {
    final text = _subtaskController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _checklist.add(ChecklistItem(id: _uuid.v4(), title: text));
      _subtaskController.clear();
    });
  }

  Future<void> _openRingtonePicker(AppStrings s, String globalDefaultId) async {
    final picked = await RingtonePickerSheet.show(
      context,
      selectedSoundId: _alarmSoundId,
      globalDefaultId: globalDefaultId,
      strings: s,
      allowSystemDefault: true,
    );
    if (picked != null && mounted) {
      setState(() => _alarmSoundId = picked);
    }
  }

  Future<void> _showAddCustomTagDialog(AppStrings s) async {
    final nameCtrl = TextEditingController();
    Color chosenColor = AppColors.auroraCyan;
    final palette = [
      AppColors.auroraCyan,
      AppColors.auroraViolet,
      AppColors.auroraRose,
      AppColors.auroraEmerald,
      AppColors.auroraAmber,
      AppColors.catPersonal,
    ];

    final created = await showDialog<ReminderCategory>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            s.addCustomTag,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: s.isVi ? 'Tên thẻ màu...' : 'Tag name...',
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: palette.map((c) {
                  final sel = c.toARGB32() == chosenColor.toARGB32();
                  return GestureDetector(
                    onTap: () => setDialogState(() => chosenColor = c),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c,
                        border: sel
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel, maxLines: 1, softWrap: false),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(
                  ctx,
                  ReminderCategory(
                    id: 'custom_${_uuid.v4().substring(0, 6)}',
                    nameVi: name,
                    nameEn: name,
                    colorValue: chosenColor.toARGB32(),
                    iconCodePoint: Icons.label_rounded.codePoint,
                    isCustom: true,
                  ),
                );
              },
              child: Text(s.save, maxLines: 1, softWrap: false),
            ),
          ],
        ),
      ),
    );

    if (created != null && mounted) {
      await context.read<SettingsCubit>().addCustomCategory(created);
      setState(() => _categoryId = created.id);
    }
  }

  void _save(AppStrings s) {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _validationError = s.titleRequiredError);
      return;
    }

    final now = DateTime.now();
    final sortedDates = _selectedDates.toList()..sort();
    final currentMinuteFloor =
        DateTime(now.year, now.month, now.day, now.hour, now.minute);
    final scheduledList = sortedDates.map((d) {
      final candidate = DateTime(d.year, d.month, d.day, _hour, _minute);
      // If user selects the current minute on today's date, schedule 3 seconds ahead so it fires immediately
      if (candidate.isAtSameMomentAs(currentMinuteFloor)) {
        return now.add(const Duration(seconds: 3));
      }
      return candidate;
    }).toList();

    if (scheduledList.every((dt) => !dt.isAfter(now))) {
      setState(() => _validationError = s.pastDateError);
      return;
    }

    final originYear = int.tryParse(_originYearController.text.trim());
    final customIntervalVal =
        int.tryParse(_customIntervalController.text.trim()) ?? 1;
    final preList = _preReminderMinutes.toList()..sort();

    if (widget.existing != null || scheduledList.length == 1) {
      final dt = scheduledList.first;
      final reminder = Reminder(
        id: widget.existing?.id ?? _uuid.v4(),
        batchGroupId: widget.existing?.batchGroupId,
        title: title,
        notes: _notesController.text.trim(),
        scheduledAt: dt,
        recurrenceType: _recurrenceType,
        weeklyDays: _weeklyDays.toList()..sort(),
        monthlyDay: dt.day,
        monthlyLastDay: _monthlyLastDay,
        originYear: originYear,
        customIntervalValue: customIntervalVal,
        customIntervalUnit: _customIntervalUnit,
        preReminderMinutes: preList,
        categoryId: _categoryId,
        alertMode: AlertMode.strongAlarm,
        dismissChallenge: _dismissChallenge,
        snoozeIntervalMinutes: _snoozeIntervalMinutes,
        maxSnoozeCount: _maxSnoozeCount,
        currentSnoozeCount: widget.existing?.currentSnoozeCount ?? 0,
        alarmSoundId: _alarmSoundId,
        isImportant: _isImportant,
        isActive: true,
        isCompleted: false,
        checklist: _checklist,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );
      context
          .read<ReminderBloc>()
          .add(SaveReminder(reminder, locale: s.locale));
    } else {
      final batchId = _uuid.v4();
      final batch = scheduledList
          .where((dt) => dt.isAfter(now))
          .map(
            (dt) => Reminder(
              id: _uuid.v4(),
              batchGroupId: batchId,
              title: title,
              notes: _notesController.text.trim(),
              scheduledAt: dt,
              recurrenceType: _recurrenceType,
              weeklyDays: _weeklyDays.toList()..sort(),
              monthlyDay: dt.day,
              monthlyLastDay: _monthlyLastDay,
              originYear: originYear,
              customIntervalValue: customIntervalVal,
              customIntervalUnit: _customIntervalUnit,
              preReminderMinutes: preList,
              categoryId: _categoryId,
              alertMode: AlertMode.strongAlarm,
              dismissChallenge: _dismissChallenge,
              snoozeIntervalMinutes: _snoozeIntervalMinutes,
              maxSnoozeCount: _maxSnoozeCount,
              alarmSoundId: _alarmSoundId,
              isImportant: _isImportant,
              isActive: true,
              isCompleted: false,
              checklist: _checklist
                  .map((c) => c.copyWith(id: _uuid.v4()))
                  .toList(),
              createdAt: now,
              updatedAt: now,
            ),
          )
          .toList();

      context
          .read<ReminderBloc>()
          .add(SaveBatchReminders(batch, locale: s.locale));
    }

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    final s = AppStrings(settings.locale);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final selectedRingtoneName = RingtoneService.instance.displayNameForId(
      _alarmSoundId,
      globalDefaultId: settings.defaultAlarmSoundId,
      locale: s.locale,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.6,
          maxChildSize: 0.96,
          builder: (context, scrollController) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    color: isDark
                        ? const Color(0xEB0E1529)
                        : const Color(0xF2F8FAFC),
                    border: Border(
                      top: BorderSide(color: AppColors.glassBorder(isDark)),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.existing == null
                                    ? s.newReminder
                                    : s.editReminder,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (widget.existing != null)
                              IconButton(
                                onPressed: () {
                                  context
                                      .read<ReminderBloc>()
                                      .add(DeleteReminder(widget.existing!));
                                  Navigator.pop(context);
                                },
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.danger,
                                ),
                              ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      if (_validationError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: AppColors.danger.withValues(alpha: 0.16),
                              border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              _validationError!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                          children: [
                            TextField(
                              controller: _titleController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                labelText: s.titleLabel,
                                hintText: s.titleHint,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _notesController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: s.notesLabel,
                                hintText: s.notesHint,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Exact Date & Multi-Date Toggle
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.selectDate,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (widget.existing == null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        s.multiDateMode,
                                        maxLines: 1,
                                        softWrap: false,
                                        style: const TextStyle(fontSize: 12.5),
                                      ),
                                      const SizedBox(width: 4),
                                      Switch.adaptive(
                                        value: _multiDateMode,
                                        activeTrackColor: AppColors.auroraCyan,
                                        onChanged: (v) {
                                          setState(() {
                                            _multiDateMode = v;
                                            if (!v &&
                                                _selectedDates.length > 1) {
                                              _selectedDates = {
                                                _selectedDates.first
                                              };
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            if (_multiDateMode && widget.existing == null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '${_selectedDates.length} ${s.selectedDatesCount} • ${s.multiDateHint}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.auroraCyan,
                                  ),
                                ),
                              ),
                            GlassCalendarPicker(
                              focusedMonth: _focusedMonth,
                              selectedDates: _selectedDates,
                              multiSelect: _multiDateMode,
                              strings: s,
                              onDateTapped: _onDateTapped,
                              onMonthChanged: (m) =>
                                  setState(() => _focusedMonth = m),
                            ),
                            const SizedBox(height: 18),

                            // Wheel Time Picker
                            Text(
                              s.selectTime,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            GlassContainer(
                              useBlur: false,
                              borderRadius: 20,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: WheelTimePicker(
                                initialHour: _hour,
                                initialMinute: _minute,
                                onChanged: (h, m) {
                                  _hour = h;
                                  _minute = m;
                                },
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Recurrence Rules
                            Text(
                              s.recurrenceLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _RecChip(
                                  label: s.recOnce,
                                  selected:
                                      _recurrenceType == RecurrenceType.once,
                                  onTap: () => setState(() =>
                                      _recurrenceType = RecurrenceType.once),
                                ),
                                _RecChip(
                                  label: s.recWeekly,
                                  selected:
                                      _recurrenceType == RecurrenceType.weekly,
                                  onTap: () => setState(() =>
                                      _recurrenceType = RecurrenceType.weekly),
                                ),
                                _RecChip(
                                  label: s.recMonthly,
                                  selected:
                                      _recurrenceType == RecurrenceType.monthly,
                                  onTap: () => setState(() =>
                                      _recurrenceType = RecurrenceType.monthly),
                                ),
                                _RecChip(
                                  label: s.recYearly,
                                  selected:
                                      _recurrenceType == RecurrenceType.yearly,
                                  onTap: () => setState(() =>
                                      _recurrenceType = RecurrenceType.yearly),
                                ),
                                _RecChip(
                                  label: s.recCustom,
                                  selected: _recurrenceType ==
                                      RecurrenceType.customInterval,
                                  onTap: () => setState(() => _recurrenceType =
                                      RecurrenceType.customInterval),
                                ),
                              ],
                            ),
                            if (_recurrenceType == RecurrenceType.weekly) ...[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(7, (idx) {
                                  final dayNum = idx + 1;
                                  final active = _weeklyDays.contains(dayNum);
                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        if (active && _weeklyDays.length > 1) {
                                          _weeklyDays.remove(dayNum);
                                        } else {
                                          _weeklyDays.add(dayNum);
                                        }
                                      });
                                    },
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: active
                                            ? AppColors.auroraCyan
                                            : Colors.white
                                                .withValues(alpha: 0.08),
                                      ),
                                      child: Text(
                                        s.weekdayShort[idx],
                                        maxLines: 1,
                                        softWrap: false,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: active
                                              ? const Color(0xFF06131F)
                                              : null,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                            if (_recurrenceType == RecurrenceType.monthly) ...[
                              const SizedBox(height: 8),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: Text(s.lastDayOfMonth),
                                value: _monthlyLastDay,
                                onChanged: (v) =>
                                    setState(() => _monthlyLastDay = v),
                              ),
                            ],
                            if (_recurrenceType == RecurrenceType.yearly) ...[
                              const SizedBox(height: 10),
                              TextField(
                                controller: _originYearController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: s.birthYearLabel,
                                  hintText: '1998',
                                ),
                              ),
                            ],
                            if (_recurrenceType ==
                                RecurrenceType.customInterval) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Text(
                                    s.everyLabel,
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                  SizedBox(
                                    width: 74,
                                    child: TextField(
                                      controller: _customIntervalController,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  ChoiceChip(
                                    label: Text(
                                      s.unitDays,
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                    selected: _customIntervalUnit ==
                                        CustomIntervalUnit.days,
                                    onSelected: (_) => setState(() =>
                                        _customIntervalUnit =
                                            CustomIntervalUnit.days),
                                  ),
                                  ChoiceChip(
                                    label: Text(
                                      s.unitHours,
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                    selected: _customIntervalUnit ==
                                        CustomIntervalUnit.hours,
                                    onSelected: (_) => setState(() =>
                                        _customIntervalUnit =
                                            CustomIntervalUnit.hours),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 18),

                            // Pre-Reminders (Nhắc trước)
                            Text(
                              s.preReminderLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: AppConstants.preReminderPresets
                                  .map((mins) {
                                final active =
                                    _preReminderMinutes.contains(mins);
                                return FilterChip(
                                  label: Text(
                                    DateTimeUtils.formatPreReminderOffset(
                                        mins, s),
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                  selected: active,
                                  onSelected: (sel) {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      if (sel) {
                                        _preReminderMinutes.add(mins);
                                      } else {
                                        _preReminderMinutes.remove(mins);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _customPreMinController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: s.customPreMin,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  onPressed: () {
                                    final v = int.tryParse(
                                        _customPreMinController.text.trim());
                                    if (v != null && v > 0) {
                                      setState(() {
                                        _preReminderMinutes.add(v);
                                        _customPreMinController.clear();
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.add_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Categories & Color Tags
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.categoryLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _showAddCustomTagDialog(s),
                                  child: Text(
                                    s.addCustomTag,
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: settings.allCategories.map((cat) {
                                final sel = cat.id == _categoryId;
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _categoryId = cat.id);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: cat.color
                                          .withValues(alpha: sel ? 0.28 : 0.10),
                                      border: Border.all(
                                        color: sel
                                            ? cat.color
                                            : cat.color.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(cat.icon,
                                            size: 15, color: cat.color),
                                        const SizedBox(width: 6),
                                        Text(
                                          cat.label(s.locale),
                                          maxLines: 1,
                                          softWrap: false,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: sel
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            // Ringtone Picker Tile
                            const SizedBox(height: 18),
                            Text(
                              s.soundLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            GlassContainer(
                              useBlur: false,
                              borderRadius: 16,
                              accentTint: AppColors.auroraCyan,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              onTap: () => _openRingtonePicker(
                                s,
                                settings.defaultAlarmSoundId,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.music_note_rounded,
                                    color: AppColors.auroraCyan,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      selectedRingtoneName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                            ),

                            // Dismiss Challenge (always visible for Strong Alarm)
                            const SizedBox(height: 16),
                            Text(
                              s.dismissChallengeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _RecChip(
                                  label: s.challengeSlide,
                                  selected: _dismissChallenge ==
                                      DismissChallenge.slide,
                                  onTap: () => setState(() =>
                                      _dismissChallenge =
                                          DismissChallenge.slide),
                                ),
                                _RecChip(
                                  label: s.challengeHold,
                                  selected: _dismissChallenge ==
                                      DismissChallenge.hold3Sec,
                                  onTap: () => setState(() =>
                                      _dismissChallenge =
                                          DismissChallenge.hold3Sec),
                                ),
                                _RecChip(
                                  label: s.challengeMath,
                                  selected: _dismissChallenge ==
                                      DismissChallenge.quickMath,
                                  onTap: () => setState(() =>
                                      _dismissChallenge =
                                          DismissChallenge.quickMath),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),
                            Text(
                              s.snoozeConfig,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: AppConstants.snoozePresets.map((m) {
                                return ChoiceChip(
                                  label: Text(
                                    '$m ${s.minutesShort}',
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                  selected: _snoozeIntervalMinutes == m,
                                  onSelected: (_) => setState(
                                      () => _snoozeIntervalMinutes = m),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${s.maxSnooze}: $_maxSnoozeCount',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _maxSnoozeCount.toDouble(),
                                    min: 1,
                                    max: 10,
                                    divisions: 9,
                                    onChanged: (v) => setState(
                                        () => _maxSnoozeCount = v.round()),
                                  ),
                                ),
                              ],
                            ),

                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                s.importantFlag,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              secondary: const Icon(
                                Icons.star_rounded,
                                color: AppColors.auroraAmber,
                              ),
                              value: _isImportant,
                              onChanged: (v) =>
                                  setState(() => _isImportant = v),
                            ),
                            const SizedBox(height: 12),

                            // Sub-task Checklist
                            Text(
                              s.checklistLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _subtaskController,
                                    onSubmitted: (_) => _addSubtask(),
                                    decoration: InputDecoration(
                                      hintText: s.addSubtaskHint,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  onPressed: _addSubtask,
                                  icon: const Icon(Icons.add_task_rounded),
                                ),
                              ],
                            ),
                            ..._checklist.map(
                              (item) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Checkbox(
                                  value: item.isDone,
                                  onChanged: (v) {
                                    setState(() {
                                      final idx = _checklist.indexOf(item);
                                      _checklist[idx] =
                                          item.copyWith(isDone: v ?? false);
                                    });
                                  },
                                ),
                                title: Text(item.title),
                                trailing: IconButton(
                                  icon:
                                      const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () =>
                                      setState(() => _checklist.remove(item)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.auroraCyan,
                                  foregroundColor: const Color(0xFF06131F),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: () => _save(s),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _multiDateMode && _selectedDates.length > 1
                                        ? '${s.save} (${_selectedDates.length})'
                                        : s.save,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RecChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RecChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, maxLines: 1, softWrap: false),
      selected: selected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}
