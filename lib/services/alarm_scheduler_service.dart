import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../core/constants/app_constants.dart';
import '../core/utils/recurrence_calculator.dart';
import '../domain/entities/reminder.dart';
import 'ringtone_service.dart';

class NotificationInteractionEvent {
  final String reminderId;
  final String? titleOverride;
  final String? bodyOverride;
  final String? actionId;
  final int? snoozeMinutesOverride;
  final bool isStrongAlarm;

  const NotificationInteractionEvent({
    required this.reminderId,
    this.titleOverride,
    this.bodyOverride,
    this.actionId,
    this.snoozeMinutesOverride,
    this.isStrongAlarm = true,
  });
}

/// Top-level handler for notification action buttons tapped in the background.
@pragma('vm:entry-point')
void chronoGlassNotificationBgResponse(NotificationResponse response) {
  debugPrint(
    'Background notification action: ${response.actionId} -> ${response.payload}',
  );
}

class AlarmSchedulerService {
  AlarmSchedulerService._();
  static final AlarmSchedulerService instance = AlarmSchedulerService._();

  static const MethodChannel _nativeAlarmChannel =
      MethodChannel('com.chronoglass.app/native_alarm');
  static const String testAlarmId = 'chronoglass_test_5s_alarm';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<NotificationInteractionEvent> _interactionController =
      StreamController<NotificationInteractionEvent>.broadcast();

  Stream<NotificationInteractionEvent> get onInteraction =>
      _interactionController.stream;

  NotificationInteractionEvent? _pendingLaunchEvent;
  NotificationInteractionEvent? consumePendingLaunchEvent() {
    final e = _pendingLaunchEvent;
    _pendingLaunchEvent = null;
    return e;
  }

  /// In-memory scheduled timestamp for the 5-second test alarm
  /// so the foreground watchdog fires it on the exact second if app is open.
  DateTime? pendingTestAlarmAt;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    if (Platform.isAndroid) {
      _nativeAlarmChannel.setMethodCallHandler((call) async {
        if (call.method == 'onAlarmFired') {
          final args = call.arguments as Map<dynamic, dynamic>?;
          final id = args?['id'] as String?;
          final title = args?['title'] as String?;
          final body = args?['body'] as String?;
          if (id != null && id.isNotEmpty) {
            _interactionController.add(
              NotificationInteractionEvent(
                reminderId: id,
                titleOverride: title,
                bodyOverride: body,
                isStrongAlarm: true,
              ),
            );
          }
        } else if (call.method == 'onNativeAlarmAction') {
          final args = call.arguments as Map<dynamic, dynamic>?;
          final action = args?['action'] as String?;
          final id = args?['id'] as String?;
          final snoozeMins = (args?['snoozeMinutes'] as num?)?.toInt();
          if (id != null && id.isNotEmpty) {
            _interactionController.add(
              NotificationInteractionEvent(
                reminderId: id,
                actionId: action == 'dismiss'
                    ? AppConstants.actionComplete
                    : AppConstants.actionSnooze10,
                snoozeMinutesOverride: snoozeMins,
                isStrongAlarm: true,
              ),
            );
          }
        }
      });

      // Cold-start check: did native AlarmForegroundService launch MainActivity?
      try {
        final pending = await _nativeAlarmChannel
            .invokeMethod<Map<dynamic, dynamic>>('getPendingAlarm');
        final id = pending?['id'] as String?;
        final title = pending?['title'] as String?;
        final body = pending?['body'] as String?;
        if (id != null && id.isNotEmpty) {
          _pendingLaunchEvent = NotificationInteractionEvent(
            reminderId: id,
            titleOverride: title,
            bodyOverride: body,
            isStrongAlarm: true,
          );
        }
      } catch (e) {
        debugPrint('getPendingAlarm warning: $e');
      }
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _handleForegroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          chronoGlassNotificationBgResponse,
    );

    await _createAndroidChannels();

    final launchDetails =
        await _notifications.getNotificationAppLaunchDetails();
    if (_pendingLaunchEvent == null &&
        launchDetails?.didNotificationLaunchApp == true &&
        launchDetails?.notificationResponse != null) {
      final event = _parseResponse(launchDetails!.notificationResponse!);
      if (event != null) {
        _pendingLaunchEvent = event;
      }
    }

    _initialized = true;
  }

  Future<void> _createAndroidChannels() async {
    if (!Platform.isAndroid) return;
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        AppConstants.preReminderChannelId,
        AppConstants.preReminderChannelName,
        description: AppConstants.preReminderChannelDesc,
        importance: Importance.high,
        playSound: true,
      ),
    );
  }

  void _handleForegroundResponse(NotificationResponse response) {
    final event = _parseResponse(response);
    if (event != null) {
      _interactionController.add(event);
    }
  }

  NotificationInteractionEvent? _parseResponse(NotificationResponse response) {
    if (response.payload == null || response.payload!.isEmpty) return null;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final reminderId = data['reminderId'] as String?;
      if (reminderId == null) return null;
      return NotificationInteractionEvent(
        reminderId: reminderId,
        actionId: response.actionId,
        isStrongAlarm: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Queries whether native AlarmForegroundService is currently playing alarm audio.
  Future<bool> isNativeRinging() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _nativeAlarmChannel.invokeMethod<bool>('isNativeRinging') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Immediately stops the native AlarmForegroundService (MediaPlayer + Vibrator + notification).
  Future<void> stopNativeRinging() async {
    if (!Platform.isAndroid) return;
    try {
      await _nativeAlarmChannel.invokeMethod('stopRinging');
    } catch (e) {
      debugPrint('stopNativeRinging warning: $e');
    }
  }

  /// Opens Android Application Details Settings for Auto-Startup / Background / Lockscreen permissions.
  Future<void> openNativeAppSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _nativeAlarmChannel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  /// Schedules a real 5-second test alarm through the 100% Native Android Alarm Engine.
  Future<DateTime> scheduleQuickTestAlarm({String locale = 'vi'}) async {
    final triggerAt = DateTime.now().add(const Duration(seconds: 5));
    pendingTestAlarmAt = triggerAt;
    final testTitle = locale == 'vi'
        ? 'Báo thức thử nghiệm (5 giây)'
        : '5-Second Alarm Test';

    final testReminder = Reminder(
      id: testAlarmId,
      title: testTitle,
      notes: locale == 'vi'
          ? 'Đánh thức màn hình khóa, chuông tăng dần và rung liên tục từ Native ForegroundService.'
          : 'Verifying lockscreen wake-up, escalating ringtone & vibration via Native ForegroundService.',
      scheduledAt: triggerAt,
      alertMode: AlertMode.strongAlarm,
      alarmSoundId: AppConstants.systemDefaultRingtoneToken,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await scheduleReminder(testReminder, locale: locale);
    return triggerAt;
  }

  /// Schedules a reminder via the 100% Native Android Alarm Engine
  /// (`AlarmManager.setAlarmClock` -> `AlarmReceiver` -> `AlarmForegroundService`),
  /// plus pre-reminders via `flutter_local_notifications`.
  Future<void> scheduleReminder(
    Reminder reminder, {
    String locale = 'vi',
    String globalDefaultSoundId = AppConstants.defaultRingtoneId,
  }) async {
    await cancelReminder(reminder);
    if (!reminder.isActive || reminder.isCompleted) return;

    final now = DateTime.now();
    if (!reminder.scheduledAt.isAfter(now)) return;

    final resolvedTone = RingtoneService.instance.resolveRingtone(
      reminder.alarmSoundId,
      globalDefaultId: globalDefaultSoundId,
    );
    final bool isAsset = !resolvedTone.isCustom;
    final String ringtonePath = isAsset
        ? 'assets/${resolvedTone.assetPath ?? 'sounds/morning_marimba.wav'}'
        : (resolvedTone.filePath ?? 'assets/sounds/morning_marimba.wav');

    final body = reminder.notes.isEmpty
        ? (locale == 'vi'
            ? 'Báo thức đang reo • Chạm để mở'
            : 'Alarm ringing • Tap to open')
        : reminder.notes;

    if (Platform.isAndroid) {
      try {
        await _nativeAlarmChannel.invokeMethod('scheduleAlarm', {
          'id': reminder.id,
          'triggerAtMillis': reminder.scheduledAt.millisecondsSinceEpoch,
          'title': reminder.title,
          'body': body,
          'ringtonePath': ringtonePath,
          'isAsset': isAsset,
          'dismissChallenge': reminder.dismissChallenge.name,
          'snoozeMinutes': reminder.snoozeIntervalMinutes,
        });
      } catch (e) {
        debugPrint('Native scheduleAlarm warning: $e');
      }
    } else {
      // iOS scheduling via flutter_local_notifications
      final tzScheduled = tz.TZDateTime.from(reminder.scheduledAt, tz.local);
      final payload = jsonEncode({
        'reminderId': reminder.id,
        'isStrongAlarm': true,
        'alarmSoundId': reminder.alarmSoundId,
      });
      try {
        await _notifications.zonedSchedule(
          reminder.notificationId,
          reminder.title,
          body,
          tzScheduled,
          const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } catch (e) {
        debugPrint('iOS zonedSchedule warning: $e');
      }
    }

    // Schedule Pre-Reminders (Nhắc trước)
    final preDates = RecurrenceCalculator.computePreReminderTimestamps(
      reminder.scheduledAt,
      reminder.preReminderMinutes,
      now: now,
    );
    final payload = jsonEncode({
      'reminderId': reminder.id,
      'isStrongAlarm': true,
      'alarmSoundId': reminder.alarmSoundId,
    });
    for (int i = 0; i < preDates.length; i++) {
      final preDt = preDates[i];
      final mins = reminder.preReminderMinutes[i];
      final preTitle = locale == 'vi'
          ? 'Nhắc trước: ${reminder.title}'
          : 'Upcoming: ${reminder.title}';
      final preBody = locale == 'vi'
          ? 'Sắp diễn ra trong $mins phút nữa'
          : 'Starting in $mins minutes';
      try {
        await _notifications.zonedSchedule(
          reminder.preReminderNotificationId(i),
          preTitle,
          preBody,
          tz.TZDateTime.from(preDt, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              AppConstants.preReminderChannelId,
              AppConstants.preReminderChannelName,
              channelDescription: AppConstants.preReminderChannelDesc,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } catch (e) {
        debugPrint('Pre-reminder schedule warning: $e');
      }
    }
  }

  Future<void> cancelReminder(Reminder reminder) async {
    if (Platform.isAndroid) {
      try {
        await _nativeAlarmChannel.invokeMethod('cancelAlarm', {
          'id': reminder.id,
        });
      } catch (_) {}
    }
    try {
      await _notifications.cancel(reminder.notificationId);
      for (int i = 0; i < 8; i++) {
        await _notifications.cancel(reminder.preReminderNotificationId(i));
      }
    } catch (_) {}
  }

  Future<void> rescheduleAllActive(
    List<Reminder> reminders, {
    String locale = 'vi',
  }) async {
    try {
      await _notifications.cancelAll();
    } catch (_) {}
    for (final reminder in reminders) {
      if (reminder.isActive && !reminder.isCompleted) {
        await scheduleReminder(reminder, locale: locale);
      }
    }
  }
}
