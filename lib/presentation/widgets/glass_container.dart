import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Reusable Glassmorphism surface.
///
/// Performance Rule:
/// - Set [useBlur] = `true` ONLY for Hero cards, floating bottom nav, modals,
///   and the full-screen alarm overlay.
/// - Set [useBlur] = `false` for scrolling `ListView.builder` cards to render
///   optimized multi-stop translucent gradients with specular borders at locked 60fps.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool useBlur;
  final double blurSigma;
  final Color? accentTint;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.useBlur = true,
    this.blurSigma = 14,
    this.accentTint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    final startColor = accentTint != null
        ? Color.alphaBlend(
            accentTint!.withValues(alpha: isDark ? 0.14 : 0.10),
            AppColors.glassFillStart(isDark),
          )
        : AppColors.glassFillStart(isDark);

    final endColor = accentTint != null
        ? Color.alphaBlend(
            accentTint!.withValues(alpha: isDark ? 0.05 : 0.04),
            AppColors.glassFillEnd(isDark),
          )
        : AppColors.glassFillEnd(isDark);

    final decoration = BoxDecoration(
      borderRadius: radius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: useBlur
            ? [startColor, endColor]
            : [
                isDark
                    ? Color.alphaBlend(
                        (accentTint ?? Colors.white).withValues(alpha: 0.08),
                        const Color(0xCC161F38),
                      )
                    : Color.alphaBlend(
                        (accentTint ?? Colors.white).withValues(alpha: 0.06),
                        const Color(0xE6FFFFFF),
                      ),
                isDark
                    ? const Color(0xB310182E)
                    : const Color(0xCCF8FAFC),
              ],
      ),
      border: Border.all(
        color: accentTint != null
            ? accentTint!.withValues(alpha: isDark ? 0.34 : 0.30)
            : AppColors.glassBorder(isDark),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.28)
              : const Color(0xFF0F172A).withValues(alpha: 0.06),
          blurRadius: useBlur ? 24 : 12,
          offset: const Offset(0, 8),
        ),
      ],
    );

    Widget surface = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (useBlur) {
      surface = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: surface,
        ),
      );
    } else {
      surface = ClipRRect(
        borderRadius: radius,
        child: surface,
      );
    }

    if (onTap != null) {
      surface = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: surface,
        ),
      );
    }

    if (margin != null) {
      return Padding(padding: margin!, child: surface);
    }
    return surface;
  }
}
