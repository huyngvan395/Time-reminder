import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/ringtone_item.dart';
import '../../services/alarm_audio_service.dart';
import '../../services/ringtone_service.dart';
import 'glass_container.dart';

/// Glassmorphic Ringtone Picker Bottom Sheet with live audio preview,
/// built-in polyphonic ringtones, and custom audio file import.
class RingtonePickerSheet extends StatefulWidget {
  final String selectedSoundId;
  final String globalDefaultId;
  final bool allowSystemDefault;
  final AppStrings strings;

  const RingtonePickerSheet({
    super.key,
    required this.selectedSoundId,
    required this.globalDefaultId,
    required this.strings,
    this.allowSystemDefault = false,
  });

  static Future<String?> show(
    BuildContext context, {
    required String selectedSoundId,
    required String globalDefaultId,
    required AppStrings strings,
    bool allowSystemDefault = false,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RingtonePickerSheet(
        selectedSoundId: selectedSoundId,
        globalDefaultId: globalDefaultId,
        strings: strings,
        allowSystemDefault: allowSystemDefault,
      ),
    );
    await AlarmAudioService.instance.stopPreview();
    return result;
  }

  @override
  State<RingtonePickerSheet> createState() => _RingtonePickerSheetState();
}

class _RingtonePickerSheetState extends State<RingtonePickerSheet> {
  late String _selectedId;
  List<RingtoneItem> _customRingtones = const [];
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedSoundId;
    _loadCustom();
  }

  @override
  void dispose() {
    AlarmAudioService.instance.stopPreview();
    super.dispose();
  }

  Future<void> _loadCustom() async {
    await RingtoneService.instance.init();
    if (mounted) {
      setState(() {
        _customRingtones = RingtoneService.instance.getCustomRingtones();
      });
    }
  }

  Future<void> _importRingtone() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final imported = await RingtoneService.instance.importCustomRingtone();
      if (imported != null && mounted) {
        setState(() {
          _customRingtones = RingtoneService.instance.getCustomRingtones();
          _selectedId = imported.id;
        });
        await AlarmAudioService.instance.togglePreview(imported);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.strings.ringtoneImported)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _deleteCustom(RingtoneItem item) async {
    if (AlarmAudioService.instance.playingPreviewId.value == item.id) {
      await AlarmAudioService.instance.stopPreview();
    }
    await RingtoneService.instance.deleteCustomRingtone(item.id);
    if (mounted) {
      setState(() {
        _customRingtones = RingtoneService.instance.getCustomRingtones();
        if (_selectedId == item.id) {
          _selectedId = widget.allowSystemDefault
              ? AppConstants.systemDefaultRingtoneToken
              : AppConstants.defaultRingtoneId;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.ringtoneDeleted)),
      );
    }
  }

  void _selectAndPreview(String id, RingtoneItem previewTarget) {
    HapticFeedback.selectionClick();
    setState(() => _selectedId = id);
    AlarmAudioService.instance.togglePreview(previewTarget);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final builtIns = RingtoneService.instance.builtInRingtones;
    final resolvedGlobalDefault = RingtoneService.instance.resolveRingtone(
      widget.globalDefaultId,
      globalDefaultId: widget.globalDefaultId,
    );

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.55,
        maxChildSize: 0.94,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  color: isDark
                      ? const Color(0xEB0E1529)
                      : const Color(0xF5F8FAFC),
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
                      padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.ringtonePickerTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  s.tapToPreview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.auroraCyan,
                              foregroundColor: const Color(0xFF06131F),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              AlarmAudioService.instance.stopPreview();
                              Navigator.pop(context, _selectedId);
                            },
                            child: Text(
                              s.isVi ? 'Chọn' : 'Done',
                              maxLines: 1,
                              softWrap: false,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: GlassContainer(
                        useBlur: false,
                        borderRadius: 18,
                        accentTint: AppColors.auroraCyan,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        onTap: _importing ? null : _importRingtone,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_importing)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              const Icon(
                                Icons.library_music_rounded,
                                color: AppColors.auroraCyan,
                                size: 20,
                              ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  s.addRingtoneFromDevice,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppColors.auroraCyan,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ValueListenableBuilder<String?>(
                        valueListenable:
                            AlarmAudioService.instance.playingPreviewId,
                        builder: (context, playingId, _) {
                          return ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                            children: [
                              if (widget.allowSystemDefault) ...[
                                _RingtoneRow(
                                  title: s.systemDefaultRingtone,
                                  subtitle: resolvedGlobalDefault.label(s.locale),
                                  selected: _selectedId ==
                                      AppConstants.systemDefaultRingtoneToken,
                                  isPlaying:
                                      playingId == resolvedGlobalDefault.id &&
                                          _selectedId ==
                                              AppConstants
                                                  .systemDefaultRingtoneToken,
                                  accent: AppColors.auroraViolet,
                                  onTap: () => _selectAndPreview(
                                    AppConstants.systemDefaultRingtoneToken,
                                    resolvedGlobalDefault,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (_customRingtones.isNotEmpty) ...[
                                _SectionLabel(title: s.myRingtones),
                                const SizedBox(height: 8),
                                ..._customRingtones.map(
                                  (item) => _RingtoneRow(
                                    title: item.label(s.locale),
                                    subtitle: item.description(s.locale),
                                    selected: _selectedId == item.id,
                                    isPlaying: playingId == item.id,
                                    accent: AppColors.auroraRose,
                                    onTap: () =>
                                        _selectAndPreview(item.id, item),
                                    onDelete: () => _deleteCustom(item),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              _SectionLabel(title: s.builtInRingtones),
                              const SizedBox(height: 8),
                              ...builtIns.map(
                                (item) => _RingtoneRow(
                                  title: item.label(s.locale),
                                  subtitle: item.description(s.locale),
                                  selected: _selectedId == item.id,
                                  isPlaying: playingId == item.id,
                                  accent: AppColors.auroraCyan,
                                  onTap: () => _selectAndPreview(item.id, item),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11.5,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w800,
        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
      ),
    );
  }
}

class _RingtoneRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool isPlaying;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _RingtoneRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.isPlaying,
    required this.accent,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        useBlur: false,
        borderRadius: 18,
        accentTint: selected ? accent : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: isPlaying ? 0.28 : 0.14),
                border: Border.all(
                  color: accent.withValues(alpha: isPlaying ? 0.85 : 0.35),
                ),
              ),
              child: Icon(
                isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: selected ? accent : null,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppColors.danger,
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? accent
                  : (isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
