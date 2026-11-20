import 'package:equatable/equatable.dart';

class RingtoneItem extends Equatable {
  final String id;
  final String nameVi;
  final String nameEn;
  final String descriptionVi;
  final String descriptionEn;
  final String? assetPath;
  final String? filePath;
  final bool isCustom;

  const RingtoneItem({
    required this.id,
    required this.nameVi,
    required this.nameEn,
    this.descriptionVi = '',
    this.descriptionEn = '',
    this.assetPath,
    this.filePath,
    this.isCustom = false,
  });

  String label(String locale) => locale == 'vi' ? nameVi : nameEn;
  String description(String locale) =>
      locale == 'vi' ? descriptionVi : descriptionEn;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameVi': nameVi,
        'nameEn': nameEn,
        'descriptionVi': descriptionVi,
        'descriptionEn': descriptionEn,
        'assetPath': assetPath,
        'filePath': filePath,
        'isCustom': isCustom,
      };

  factory RingtoneItem.fromJson(Map<String, dynamic> json) {
    return RingtoneItem(
      id: json['id'] as String,
      nameVi: json['nameVi'] as String,
      nameEn: json['nameEn'] as String,
      descriptionVi: (json['descriptionVi'] as String?) ?? '',
      descriptionEn: (json['descriptionEn'] as String?) ?? '',
      assetPath: json['assetPath'] as String?,
      filePath: json['filePath'] as String?,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        nameVi,
        nameEn,
        descriptionVi,
        descriptionEn,
        assetPath,
        filePath,
        isCustom,
      ];
}
