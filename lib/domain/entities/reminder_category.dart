import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ReminderCategory extends Equatable {
  final String id;
  final String nameVi;
  final String nameEn;
  final int colorValue;
  final int iconCodePoint;
  final bool isCustom;

  const ReminderCategory({
    required this.id,
    required this.nameVi,
    required this.nameEn,
    required this.colorValue,
    required this.iconCodePoint,
    this.isCustom = false,
  });

  Color get color => Color(colorValue);

  IconData get icon {
    if (iconCodePoint == Icons.work_rounded.codePoint) {
      return Icons.work_rounded;
    }
    if (iconCodePoint == Icons.school_rounded.codePoint) {
      return Icons.school_rounded;
    }
    if (iconCodePoint == Icons.receipt_long_rounded.codePoint) {
      return Icons.receipt_long_rounded;
    }
    if (iconCodePoint == Icons.favorite_rounded.codePoint) {
      return Icons.favorite_rounded;
    }
    if (iconCodePoint == Icons.cake_rounded.codePoint) {
      return Icons.cake_rounded;
    }
    if (iconCodePoint == Icons.person_rounded.codePoint) {
      return Icons.person_rounded;
    }
    return Icons.label_rounded;
  }

  String label(String locale) => locale == 'vi' ? nameVi : nameEn;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameVi': nameVi,
        'nameEn': nameEn,
        'colorValue': colorValue,
        'iconCodePoint': iconCodePoint,
        'isCustom': isCustom,
      };

  factory ReminderCategory.fromJson(Map<String, dynamic> json) {
    return ReminderCategory(
      id: json['id'] as String,
      nameVi: json['nameVi'] as String,
      nameEn: json['nameEn'] as String,
      colorValue: json['colorValue'] as int,
      iconCodePoint: json['iconCodePoint'] as int,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  static List<ReminderCategory> defaults() => [
        ReminderCategory(
          id: 'work',
          nameVi: 'Công việc',
          nameEn: 'Work',
          colorValue: AppColors.catWork.toARGB32(),
          iconCodePoint: Icons.work_rounded.codePoint,
        ),
        ReminderCategory(
          id: 'study',
          nameVi: 'Học tập',
          nameEn: 'Study',
          colorValue: AppColors.catStudy.toARGB32(),
          iconCodePoint: Icons.school_rounded.codePoint,
        ),
        ReminderCategory(
          id: 'finance',
          nameVi: 'Tài chính / Hóa đơn',
          nameEn: 'Finance / Bills',
          colorValue: AppColors.catFinance.toARGB32(),
          iconCodePoint: Icons.receipt_long_rounded.codePoint,
        ),
        ReminderCategory(
          id: 'health',
          nameVi: 'Sức khỏe',
          nameEn: 'Health',
          colorValue: AppColors.catHealth.toARGB32(),
          iconCodePoint: Icons.favorite_rounded.codePoint,
        ),
        ReminderCategory(
          id: 'event',
          nameVi: 'Sự kiện / Sinh nhật',
          nameEn: 'Events / Birthdays',
          colorValue: AppColors.catEvent.toARGB32(),
          iconCodePoint: Icons.cake_rounded.codePoint,
        ),
        ReminderCategory(
          id: 'personal',
          nameVi: 'Cá nhân',
          nameEn: 'Personal',
          colorValue: AppColors.catPersonal.toARGB32(),
          iconCodePoint: Icons.person_rounded.codePoint,
        ),
      ];

  @override
  List<Object?> get props =>
      [id, nameVi, nameEn, colorValue, iconCodePoint, isCustom];
}
