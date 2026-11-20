import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../domain/entities/ringtone_item.dart';

/// Manages built-in alarm ringtones and permanently persisted custom user audio files.
class RingtoneService {
  RingtoneService._();
  static final RingtoneService instance = RingtoneService._();

  final _uuid = const Uuid();
  Box<dynamic>? _box;

  Future<void> init() async {
    if (_box != null) return;
    _box = await Hive.openBox<dynamic>(AppConstants.ringtonesBoxName);
  }

  List<RingtoneItem> get builtInRingtones => AppConstants.builtInRingtones;

  List<RingtoneItem> getCustomRingtones() {
    if (_box == null) return const [];
    final raw = _box!.get('custom_ringtones_json', defaultValue: '[]') as String;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RingtoneItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<RingtoneItem> getAllRingtones() {
    return [...getCustomRingtones(), ...builtInRingtones];
  }

  Future<void> _saveCustomRingtones(List<RingtoneItem> items) async {
    await init();
    await _box!.put(
      'custom_ringtones_json',
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  /// Opens system audio picker, copies the chosen file into `<appDocumentsDirectory>/custom_ringtones/`
  /// so it remains playable after reboot or file moves, and persists its metadata.
  Future<RingtoneItem?> importCustomRingtone() async {
    await init();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'ogg', 'aac'],
    );
    if (result == null || result.files.single.path == null) return null;

    final picked = result.files.single;
    final sourceFile = File(picked.path!);
    if (!await sourceFile.exists()) return null;

    final docsDir = await getApplicationDocumentsDirectory();
    final customDir = Directory(p.join(docsDir.path, 'custom_ringtones'));
    if (!await customDir.exists()) {
      await customDir.create(recursive: true);
    }

    final id = 'custom_${_uuid.v4().substring(0, 8)}';
    final ext = p.extension(picked.name).isNotEmpty
        ? p.extension(picked.name)
        : '.mp3';
    final safeBase = p
        .basenameWithoutExtension(picked.name)
        .replaceAll(RegExp(r'[^\w\s\-\u00C0-\u1EF9]'), '')
        .trim();
    final displayTitle = safeBase.isEmpty ? 'Custom Ringtone' : safeBase;
    final destPath = p.join(customDir.path, '${id}_${DateTime.now().millisecondsSinceEpoch}$ext');

    await sourceFile.copy(destPath);

    final item = RingtoneItem(
      id: id,
      nameVi: displayTitle,
      nameEn: displayTitle,
      descriptionVi: 'Nhạc chuông nhập từ thiết bị (${ext.replaceFirst('.', '').toUpperCase()})',
      descriptionEn: 'Imported from device (${ext.replaceFirst('.', '').toUpperCase()})',
      filePath: destPath,
      isCustom: true,
    );

    final updated = [item, ...getCustomRingtones()];
    await _saveCustomRingtones(updated);
    return item;
  }

  Future<void> deleteCustomRingtone(String id) async {
    await init();
    final existing = getCustomRingtones();
    final target = existing.where((e) => e.id == id).toList();
    for (final item in target) {
      if (item.filePath != null) {
        try {
          final file = File(item.filePath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
    final remaining = existing.where((e) => e.id != id).toList();
    await _saveCustomRingtones(remaining);
  }

  /// Resolves a reminder's sound ID (or `system_default`) into a playable RingtoneItem,
  /// verifying custom file existence and gracefully falling back to `morning_marimba`.
  RingtoneItem resolveRingtone(
    String? reminderSoundId, {
    String globalDefaultId = AppConstants.defaultRingtoneId,
  }) {
    final effectiveId = (reminderSoundId == null ||
            reminderSoundId.isEmpty ||
            reminderSoundId == AppConstants.systemDefaultRingtoneToken)
        ? globalDefaultId
        : reminderSoundId;

    // Map legacy sound IDs gracefully
    final normalizedId = switch (effectiveId) {
      'aurora_chime' => 'aurora_chimes',
      'crystal_pulse' => 'radar_pulse',
      'deep_horizon' => 'daybreak_synth',
      _ => effectiveId,
    };

    for (final custom in getCustomRingtones()) {
      if (custom.id == normalizedId &&
          custom.filePath != null &&
          File(custom.filePath!).existsSync()) {
        return custom;
      }
    }

    for (final builtIn in builtInRingtones) {
      if (builtIn.id == normalizedId) {
        return builtIn;
      }
    }

    // Fallback to global default if built-in, else morning_marimba
    for (final builtIn in builtInRingtones) {
      if (builtIn.id == globalDefaultId) {
        return builtIn;
      }
    }
    return builtInRingtones.first;
  }

  String displayNameForId(
    String? soundId, {
    required String globalDefaultId,
    required String locale,
  }) {
    if (soundId == null ||
        soundId.isEmpty ||
        soundId == AppConstants.systemDefaultRingtoneToken) {
      final def = resolveRingtone(globalDefaultId, globalDefaultId: globalDefaultId);
      return locale == 'vi'
          ? 'Mặc định (${def.label(locale)})'
          : 'Default (${def.label(locale)})';
    }
    return resolveRingtone(soundId, globalDefaultId: globalDefaultId)
        .label(locale);
  }
}
