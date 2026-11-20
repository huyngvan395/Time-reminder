import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Smooth 24-hour wheel time picker with tabular digits & tactile haptic clicks.
class WheelTimePicker extends StatefulWidget {
  final int initialHour;
  final int initialMinute;
  final void Function(int hour, int minute) onChanged;

  const WheelTimePicker({
    super.key,
    required this.initialHour,
    required this.initialMinute,
    required this.onChanged,
  });

  @override
  State<WheelTimePicker> createState() => _WheelTimePickerState();
}

class _WheelTimePickerState extends State<WheelTimePicker> {
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialHour;
    _minute = widget.initialMinute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 156,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 46,
            margin: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppColors.auroraCyan.withValues(alpha: isDark ? 0.16 : 0.14),
              border: Border.all(
                color: AppColors.auroraCyan.withValues(alpha: 0.45),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 84,
                child: ListWheelScrollView.useDelegate(
                  controller: _hourController,
                  itemExtent: 44,
                  perspective: 0.004,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (idx) {
                    HapticFeedback.selectionClick();
                    setState(() => _hour = idx % 24);
                    widget.onChanged(_hour, _minute);
                  },
                  childDelegate: ListWheelChildLoopingListDelegate(
                    children: List.generate(24, (i) {
                      final active = i == _hour;
                      return Center(
                        child: Text(
                          i.toString().padLeft(2, '0'),
                          style: AppTheme.tabularDigits(
                            TextStyle(
                              fontSize: active ? 28 : 20,
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w500,
                              color: active
                                  ? (isDark
                                      ? Colors.white
                                      : AppColors.lightTextPrimary)
                                  : (isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              Text(
                ':',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.auroraCyan : const Color(0xFF0284C7),
                ),
              ),
              SizedBox(
                width: 84,
                child: ListWheelScrollView.useDelegate(
                  controller: _minuteController,
                  itemExtent: 44,
                  perspective: 0.004,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (idx) {
                    HapticFeedback.selectionClick();
                    setState(() => _minute = idx % 60);
                    widget.onChanged(_hour, _minute);
                  },
                  childDelegate: ListWheelChildLoopingListDelegate(
                    children: List.generate(60, (i) {
                      final active = i == _minute;
                      return Center(
                        child: Text(
                          i.toString().padLeft(2, '0'),
                          style: AppTheme.tabularDigits(
                            TextStyle(
                              fontSize: active ? 28 : 20,
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w500,
                              color: active
                                  ? (isDark
                                      ? Colors.white
                                      : AppColors.lightTextPrimary)
                                  : (isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
