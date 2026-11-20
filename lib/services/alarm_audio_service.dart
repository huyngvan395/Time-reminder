import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../core/constants/app_constants.dart';
import '../domain/entities/ringtone_item.dart';
import 'alarm_scheduler_service.dart';
import 'ringtone_service.dart';

/// Controls alarm audio playback with gradual volume ramp-up, continuous vibration,
/// screen wake lock, Android lock-screen display flags, and live ringtone previewing.
/// Automatically delegates to Android's native `AlarmForegroundService` when a native alarm
/// is already ringing so audio never plays twice.
class AlarmAudioService {
  AlarmAudioService._();
  static final AlarmAudioService instance = AlarmAudioService._();

  static const _systemChannel = MethodChannel('com.chronoglass.app/system');

  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<String?> playingPreviewId = ValueNotifier<String?>(null);

  Timer? _volumeRampTimer;
  Timer? _vibrationTimer;
  StreamSubscription<void>? _completeSub;
  bool _isPlaying = false;
  double _currentVolume = 0.2;

  bool get isPlaying => _isPlaying;

  Future<void> startAlarm({
    String? soundId,
    String globalDefaultId = AppConstants.defaultRingtoneId,
    bool escalateVolume = true,
    bool vibrate = true,
  }) async {
    try {
      await WakelockPlus.enable();
      if (Platform.isAndroid) {
        await _systemChannel.invokeMethod('setLockScreenAlarmMode', {
          'enabled': true,
        });
      }
    } catch (_) {}

    // If Android native AlarmForegroundService is already playing USAGE_ALARM audio,
    // do not start a duplicate Flutter AudioPlayer instance.
    if (Platform.isAndroid) {
      final nativeRinging =
          await AlarmSchedulerService.instance.isNativeRinging();
      if (nativeRinging) {
        _isPlaying = true;
        return;
      }
    }

    await _stopLocalAudioAndVibrationOnly();
    _isPlaying = true;

    final resolved = RingtoneService.instance.resolveRingtone(
      soundId,
      globalDefaultId: globalDefaultId,
    );

    try {
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            },
          ),
        ),
      );
      await _player.setReleaseMode(ReleaseMode.loop);
      _currentVolume = escalateVolume ? 0.18 : 1.0;
      await _player.setVolume(_currentVolume);

      await _playRingtoneSource(resolved);

      if (escalateVolume) {
        _volumeRampTimer = Timer.periodic(
          const Duration(milliseconds: 900),
          (timer) async {
            if (!_isPlaying) {
              timer.cancel();
              return;
            }
            _currentVolume = (_currentVolume + 0.06).clamp(0.18, 1.0);
            try {
              await _player.setVolume(_currentVolume);
            } catch (_) {}
            if (_currentVolume >= 1.0) {
              timer.cancel();
            }
          },
        );
      }
    } catch (_) {
      try {
        await _player.play(
          AssetSource(AppConstants.builtInRingtones.first.assetPath!),
        );
      } catch (_) {}
    }

    if (vibrate) {
      _startVibrationLoop();
    }
  }

  Future<void> _playRingtoneSource(RingtoneItem item) async {
    if (item.isCustom &&
        item.filePath != null &&
        File(item.filePath!).existsSync()) {
      await _player.play(DeviceFileSource(item.filePath!));
    } else if (item.assetPath != null) {
      await _player.play(AssetSource(item.assetPath!));
    } else {
      await _player.play(
        AssetSource(AppConstants.builtInRingtones.first.assetPath!),
      );
    }
  }

  /// Toggles live preview for a RingtoneItem in the RingtonePickerSheet.
  Future<void> togglePreview(RingtoneItem item) async {
    if (playingPreviewId.value == item.id) {
      await stopPreview();
      return;
    }

    await stopPreview();
    playingPreviewId.value = item.id;

    try {
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.setVolume(0.85);
      _completeSub?.cancel();
      _completeSub = _player.onPlayerComplete.listen((_) {
        if (playingPreviewId.value == item.id) {
          playingPreviewId.value = null;
        }
      });
      await _playRingtoneSource(item);
    } catch (_) {
      playingPreviewId.value = null;
    }
  }

  Future<void> stopPreview() async {
    _completeSub?.cancel();
    _completeSub = null;
    playingPreviewId.value = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> _startVibrationLoop() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) return;
      Vibration.vibrate(pattern: [0, 600, 400, 800, 500]);
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
        if (_isPlaying) {
          Vibration.vibrate(pattern: [0, 600, 400, 800, 500]);
        }
      });
    } catch (_) {}
  }

  Future<void> _stopLocalAudioAndVibrationOnly() async {
    _isPlaying = false;
    playingPreviewId.value = null;
    _volumeRampTimer?.cancel();
    _volumeRampTimer = null;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    _completeSub?.cancel();
    _completeSub = null;

    try {
      await _player.stop();
    } catch (_) {}

    try {
      await Vibration.cancel();
    } catch (_) {}
  }

  /// Stops both Flutter audio/vibration AND Android's native AlarmForegroundService.
  Future<void> stopAlarm() async {
    await _stopLocalAudioAndVibrationOnly();
    await AlarmSchedulerService.instance.stopNativeRinging();

    try {
      await WakelockPlus.disable();
      if (Platform.isAndroid) {
        await _systemChannel.invokeMethod('setLockScreenAlarmMode', {
          'enabled': false,
        });
      }
    } catch (_) {}
  }
}
