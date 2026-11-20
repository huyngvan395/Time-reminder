import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../core/constants/app_constants.dart';
import '../core/utils/recurrence_calculator.dart';
import '../domain/entities/reminder.dart';

class NotificationInteractionEvent {
  final String reminderId;
  final String? actionId;
  final bool isStrongAlarm;

  const NotificationInteractionEvent({
    required this.reminderId,
    this.actionId,
    this.isStrongAlarm = true,
  });
}

/// Top-level background entry point for AndroidAlarmManagerPlus RTC_WAKEUP triggers.
@pragma('vm:entry-point')
Future<void> chronoGlassAlarmCallback(int id, Map<String, dynamic> params) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: androidInit));

    final title = (params['title'] as String?) ?? 'ChronoGlass Alarm';
    final body = (params['notes'] as String?) ?? '';
    final payload = jsonEncode({
      'reminderId': params['reminderId'],
      'isStrongAlarm': true,
      'alarmSoundId': params['alarmSoundId'],
    });

    await plugin.show(
      id,
      title,
      body.isEmpty ? 'Báo thức ChronoGlass đang reo' : body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.strongAlarmChannelId,
          AppConstants.strongAlarmChannelName,
          channelDescription: AppConstants.strongAlarmChannelDesc,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('aurora_chime'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          vibrationPattern: Int64List.fromList([0, 600, 400, 800, 400]),
        ),
      ),
      payload: payload,
    );
  } catch (e) {
    debugPrint('ChronoGlass background alarm callback error: $e');
  }
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
      try {
        await AndroidAlarmManager.initialize();
      } catch (e) {
        debugPrint('AndroidAlarmManager init warning: $e');
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
    if (launchDetails?.didNotificationLaunchApp == true &&
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
      AndroidNotificationChannel(
        AppConstants.strongAlarmChannelId,
        AppConstants.strongAlarmChannelName,
        description: AppConstants.strongAlarmChannelDesc,
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('aurora_chime'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 600, 400, 800, 400]),
      ),
    );

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

  /// Schedules every reminder unconditionally as a Strong Alarm (fullScreenIntent + RTC_WAKEUP)
  /// plus any configured pre-reminders, falling back gracefully if exact-alarm permission is pending.
  Future<void> scheduleReminder(Reminder reminder, {String locale = 'vi'}) async {
    await cancelReminder(reminder);
    if (!reminder.isActive || reminder.isCompleted) return;

    final now = DateTime.now();
    if (!reminder.scheduledAt.isAfter(now)) return;

    final tzScheduled = tz.TZDateTime.from(reminder.scheduledAt, tz.local);
    final payload = jsonEncode({
      'reminderId': reminder.id,
      'isStrongAlarm': true,
      'alarmSoundId': reminder.alarmSoundId,
    });

    final completeLabel = locale == 'vi' ? 'Hoàn thành' : 'Complete';
    final snoozeLabel = locale == 'vi'
        ? 'Báo lại ${reminder.snoozeIntervalMinutes}p'
        : 'Snooze ${reminder.snoozeIntervalMinutes}m';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        AppConstants.strongAlarmChannelId,
        AppConstants.strongAlarmChannelName,
        channelDescription: AppConstants.strongAlarmChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('aurora_chime'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        vibrationPattern: Int64List.fromList([0, 600, 400, 800, 400]),
        actions: [
          AndroidNotificationAction(
            AppConstants.actionSnooze10,
            snoozeLabel,
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            AppConstants.actionComplete,
            completeLabel,
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    final body = reminder.notes.isEmpty
        ? (locale == 'vi' ? 'Báo thức • ChronoGlass' : 'Alarm • ChronoGlass')
        : reminder.notes;

    try {
      await _notifications.zonedSchedule(
        reminder.notificationId,
        reminder.title,
        body,
        tzScheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Exact alarmClock schedule fallback: $e');
      try {
        await _notifications.zonedSchedule(
          reminder.notificationId,
          reminder.title,
          body,
          tzScheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } catch (fallbackErr) {
        debugPrint('Inexact fallback schedule warning: $fallbackErr');
      }
    }

    // Backup exact RTC_WAKEUP via AndroidAlarmManagerPlus for aggressive OEM devices
    if (Platform.isAndroid) {
      try {
        await AndroidAlarmManager.oneShotAt(
          reminder.scheduledAt,
          reminder.notificationId,
          chronoGlassAlarmCallback,
          exact: true,
          wakeup: true,
          alarmClock: true,
          rescheduleOnReboot: true,
          params: {
            'reminderId': reminder.id,
            'title': reminder.title,
            'notes': reminder.notes,
            'alarmSoundId': reminder.alarmSoundId,
          },
        );
      } catch (e) {
        debugPrint('AndroidAlarmManager oneShotAt warning: $e');
      }
    }

    // Schedule Pre-Reminders (Nhắc trước)
    final preDates = RecurrenceCalculator.computePreReminderTimestamps(
      reminder.scheduledAt,
      reminder.preReminderMinutes,
      now: now,
    );
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
    try {
      await _notifications.cancel(reminder.notificationId);
      for (int i = 0; i < 8; i++) {
        await _notifications.cancel(reminder.preReminderNotificationId(i));
      }
    } catch (_) {}
    if (Platform.isAndroid) {
      try {
        await AndroidAlarmManager.cancel(reminder.notificationId);
      } catch (_) {}
    }
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
