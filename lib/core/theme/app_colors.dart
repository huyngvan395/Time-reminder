import 'package:flutter/material.dart';

/// Color tokens for "Frosted Dark Aurora" (primary) & "Crystal Light" (optional) themes.
class AppColors {
  AppColors._();

  // Frosted Dark Aurora background canvas
  static const Color darkBgStart = Color(0xFF0A0E1A);
  static const Color darkBgMid = Color(0xFF0F1629);
  static const Color darkBgEnd = Color(0xFF141B34);

  // Ambient glowing orbs
  static const Color auroraCyan = Color(0xFF38BDF8);
  static const Color auroraViolet = Color(0xFF818CF8);
  static const Color auroraRose = Color(0xFFFB7185);
  static const Color auroraEmerald = Color(0xFF34D399);
  static const Color auroraAmber = Color(0xFFFBBF24);

  // Crystal Light background canvas
  static const Color lightBgStart = Color(0xFFF0F4FF);
  static const Color lightBgMid = Color(0xFFE8EEFF);
  static const Color lightBgEnd = Color(0xFFF5F3FF);

  // Text colors
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF64748B);

  // Semantic accents
  static const Color danger = Color(0xFFFB7185);
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color info = Color(0xFF38BDF8);

  // Category default colors
  static const Color catWork = Color(0xFF38BDF8);
  static const Color catStudy = Color(0xFF818CF8);
  static const Color catFinance = Color(0xFFFBBF24);
  static const Color catHealth = Color(0xFF34D399);
  static const Color catEvent = Color(0xFFFB7185);
  static const Color catPersonal = Color(0xFFC084FC);

  static Color glassBorder(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.18)
      : Colors.white.withValues(alpha: 0.72);

  static Color glassFillStart(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.11)
      : Colors.white.withValues(alpha: 0.76);

  static Color glassFillEnd(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.04)
      : Colors.white.withValues(alpha: 0.45);
}
