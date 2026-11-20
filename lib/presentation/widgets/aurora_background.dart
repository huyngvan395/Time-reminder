import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Deep midnight mesh gradient ("Frosted Dark Aurora") or "Crystal Light" canvas
/// with softly drifting ambient glowing orbs wrapped in a RepaintBoundary for 60fps efficiency.
class AuroraBackground extends StatefulWidget {
  final Widget child;
  final bool isDark;

  const AuroraBackground({
    super.key,
    required this.child,
    this.isDark = true,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Stack(
      children: [
        RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        AppColors.darkBgStart,
                        AppColors.darkBgMid,
                        AppColors.darkBgEnd,
                      ]
                    : const [
                        AppColors.lightBgStart,
                        AppColors.lightBgMid,
                        AppColors.lightBgEnd,
                      ],
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final angle = _controller.value * 2 * math.pi;
                final dx1 = math.sin(angle) * 24;
                final dy1 = math.cos(angle) * 18;
                final dx2 = math.cos(angle * 0.8) * 28;
                final dy2 = math.sin(angle * 0.8) * 22;
                final dx3 = math.sin(angle * 0.6 + 1.5) * 20;
                final dy3 = math.cos(angle * 0.6 + 1.5) * 24;

                return Stack(
                  children: [
                    Positioned(
                      top: -90 + dy1,
                      left: -70 + dx1,
                      child: _AmbientOrb(
                        size: 290,
                        color: AppColors.auroraCyan
                            .withValues(alpha: isDark ? 0.22 : 0.20),
                      ),
                    ),
                    Positioned(
                      top: 220 + dy2,
                      right: -100 + dx2,
                      child: _AmbientOrb(
                        size: 320,
                        color: AppColors.auroraViolet
                            .withValues(alpha: isDark ? 0.20 : 0.18),
                      ),
                    ),
                    Positioned(
                      bottom: -80 + dy3,
                      left: 40 + dx3,
                      child: _AmbientOrb(
                        size: 260,
                        color: AppColors.auroraRose
                            .withValues(alpha: isDark ? 0.16 : 0.14),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.72],
          ),
        ),
      ),
    );
  }
}
