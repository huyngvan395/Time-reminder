import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_time_utils.dart';
import '../../domain/entities/reminder.dart';
import '../../services/alarm_audio_service.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass_container.dart';

/// Full-Screen Glassmorphic Lockscreen Alarm UI with:
/// - Balanced vertical composition with concentric pulsing glow behind clock/card
/// - Symmetrical full-width (64px tall) Snooze & Slide-to-Dismiss controls
/// - Zero text clipping on compact 360dp screens
/// - Looping escalating alarm audio (built-in or custom) + continuous vibration + wakelock
class FullScreenAlarmScreen extends StatefulWidget {
  final Reminder reminder;
  final AppStrings strings;
  final String globalDefaultSoundId;
  final VoidCallback onDismissed;
  final ValueChanged<int> onSnoozed;

  const FullScreenAlarmScreen({
    super.key,
    required this.reminder,
    required this.strings,
    this.globalDefaultSoundId = AppConstants.defaultRingtoneId,
    required this.onDismissed,
    required this.onSnoozed,
  });

  @override
  State<FullScreenAlarmScreen> createState() => _FullScreenAlarmScreenState();
}

class _FullScreenAlarmScreenState extends State<FullScreenAlarmScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  // Slide to dismiss state
  double _slideProgress = 0.0;

  // Hold 3s state
  Timer? _holdTimer;
  double _holdProgress = 0.0;

  // Quick Math state
  late int _mathA;
  late int _mathB;
  late bool _mathIsAdd;
  final TextEditingController _mathController = TextEditingController();
  bool _mathError = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    final rng = Random();
    _mathA = 12 + rng.nextInt(25);
    _mathB = 7 + rng.nextInt(18);
    _mathIsAdd = rng.nextBool();

    AlarmAudioService.instance.startAlarm(
      soundId: widget.reminder.alarmSoundId,
      globalDefaultId: widget.globalDefaultSoundId,
      escalateVolume: true,
      vibrate: true,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _clockTimer.cancel();
    _holdTimer?.cancel();
    _mathController.dispose();
    AlarmAudioService.instance.stopAlarm();
    super.dispose();
  }

  Future<void> _completeDismiss() async {
    HapticFeedback.heavyImpact();
    await AlarmAudioService.instance.stopAlarm();
    widget.onDismissed();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _triggerSnooze() async {
    if (!widget.reminder.canSnooze) return;
    HapticFeedback.mediumImpact();
    await AlarmAudioService.instance.stopAlarm();
    widget.onSnoozed(widget.reminder.snoozeIntervalMinutes);
    if (mounted) Navigator.of(context).pop();
  }

  void _startHold() {
    _holdTimer?.cancel();
    const tick = Duration(milliseconds: 50);
    _holdTimer = Timer.periodic(tick, (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _holdProgress = (_holdProgress + 50 / 3000).clamp(0.0, 1.0);
      });
      if (_holdProgress >= 1.0) {
        t.cancel();
        _completeDismiss();
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    if (mounted) {
      setState(() => _holdProgress = 0.0);
    }
  }

  void _verifyMath() {
    final expected = _mathIsAdd ? _mathA + _mathB : (_mathA - _mathB).abs();
    final input = int.tryParse(_mathController.text.trim());
    if (input == expected) {
      _completeDismiss();
    } else {
      HapticFeedback.vibrate();
      setState(() => _mathError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final r = widget.reminder;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.darkBgStart,
        resizeToAvoidBottomInset: false,
        body: AuroraBackground(
          isDark: true,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Top Status Badge
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 1.0 + (_pulseController.value * 0.08);
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: AppColors.auroraRose.withValues(alpha: 0.22),
                        border: Border.all(
                          color: AppColors.auroraRose.withValues(alpha: 0.65),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.notifications_active_rounded,
                            color: AppColors.auroraRose,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            s.alarmRinging,
                            maxLines: 1,
                            softWrap: false,
                            style: const TextStyle(
                              color: AppColors.auroraRose,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Concentric Animated Pulse Glow behind Clock + Title Card
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final v = _pulseController.value;
                          return IgnorePointer(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 260 + v * 50,
                                  height: 260 + v * 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppColors.auroraRose
                                            .withValues(alpha: 0.20 - v * 0.08),
                                        AppColors.auroraViolet
                                            .withValues(alpha: 0.08 - v * 0.04),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.55, 1.0],
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 190 + v * 28,
                                  height: 190 + v * 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.auroraRose
                                          .withValues(alpha: 0.16 - v * 0.10),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                DateTimeUtils.formatTime(_now),
                                maxLines: 1,
                                softWrap: false,
                                style: AppTheme.tabularDigits(
                                  const TextStyle(
                                    fontSize: 74,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateTimeUtils.formatDate(_now, locale: s.locale),
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.darkTextSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 26),
                            SizedBox(
                              width: double.infinity,
                              child: GlassContainer(
                                useBlur: true,
                                blurSigma: 16,
                                borderRadius: 24,
                                accentTint: AppColors.auroraRose,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 20,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      r.title,
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1.25,
                                      ),
                                    ),
                                    if (r.notes.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        r.notes,
                                        textAlign: TextAlign.center,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          color: AppColors.darkTextSecondary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 3),

                  // Symmetrical Full-Width Bottom Action Controls
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (r.canSnooze)
                          SizedBox(
                            width: double.infinity,
                            height: 64,
                            child: GlassContainer(
                              useBlur: true,
                              borderRadius: 32,
                              accentTint: AppColors.auroraViolet,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              onTap: _triggerSnooze,
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.snooze_rounded,
                                        color: AppColors.auroraViolet,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${s.snoozeNow} ${r.snoozeIntervalMinutes} ${s.minutesShort} (${r.currentSnoozeCount}/${r.maxSnoozeCount})',
                                        maxLines: 1,
                                        softWrap: false,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              s.snoozeLimitReached,
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                color: AppColors.auroraAmber,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        _buildDismissChallenge(s, r.dismissChallenge),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDismissChallenge(AppStrings s, DismissChallenge challenge) {
    switch (challenge) {
      case DismissChallenge.slide:
        return LayoutBuilder(
          builder: (context, constraints) {
            const double thumbSize = 52;
            const double trackPad = 6;
            final double maxDrag =
                (constraints.maxWidth - thumbSize - trackPad * 2)
                    .clamp(1.0, double.infinity);

            return SizedBox(
              width: double.infinity,
              height: 64,
              child: GlassContainer(
                useBlur: true,
                borderRadius: 32,
                accentTint: AppColors.auroraCyan,
                padding: EdgeInsets.zero,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Label with left padding 68px (clears 52px thumb) & right padding 20px
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 68, right: 20),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 120),
                              opacity: (1.0 - _slideProgress * 1.1)
                                  .clamp(0.15, 1.0),
                              child: Text(
                                s.slideToDismiss,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.90),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: trackPad + _slideProgress * maxDrag,
                      top: trackPad,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _slideProgress = (_slideProgress +
                                    details.delta.dx / maxDrag)
                                .clamp(0.0, 1.0);
                          });
                        },
                        onHorizontalDragEnd: (_) {
                          if (_slideProgress > 0.80) {
                            _completeDismiss();
                          } else {
                            setState(() => _slideProgress = 0.0);
                          }
                        },
                        child: Container(
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.auroraCyan,
                                AppColors.auroraViolet,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.auroraCyan
                                    .withValues(alpha: 0.45),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

      case DismissChallenge.hold3Sec:
        return GestureDetector(
          onLongPressStart: (_) => _startHold(),
          onLongPressEnd: (_) => _cancelHold(),
          onTapDown: (_) => _startHold(),
          onTapUp: (_) => _cancelHold(),
          onTapCancel: _cancelHold,
          child: SizedBox(
            width: double.infinity,
            child: GlassContainer(
              useBlur: true,
              borderRadius: 24,
              accentTint: AppColors.auroraRose,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      s.holdToDismiss,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _holdProgress,
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.auroraRose),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case DismissChallenge.quickMath:
        final high = max(_mathA, _mathB);
        final low = min(_mathA, _mathB);
        final expr = _mathIsAdd ? '$_mathA + $_mathB = ?' : '$high - $low = ?';
        return SizedBox(
          width: double.infinity,
          child: GlassContainer(
            useBlur: true,
            borderRadius: 24,
            accentTint: AppColors.auroraAmber,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    s.solveToDismiss,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      color: AppColors.darkTextSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  expr,
                  maxLines: 1,
                  softWrap: false,
                  style: AppTheme.tabularDigits(
                    const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mathController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: '...',
                          errorText: _mathError ? s.wrongAnswer : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.auroraCyan,
                        foregroundColor: const Color(0xFF06131F),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _verifyMath,
                      child: Text(
                        s.confirmAnswer,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
    }
  }
}
