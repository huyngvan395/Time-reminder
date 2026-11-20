import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class SystemReliabilityStatus {
  final bool notificationsGranted;
  final bool exactAlarmGranted;
  final bool fullScreenIntentGranted;
  final bool batteryOptimizationIgnored;
  final String deviceManufacturer;
  final String deviceModel;
  final int androidSdkInt;

  const SystemReliabilityStatus({
    required this.notificationsGranted,
    required this.exactAlarmGranted,
    required this.fullScreenIntentGranted,
    required this.batteryOptimizationIgnored,
    required this.deviceManufacturer,
    required this.deviceModel,
    required this.androidSdkInt,
  });

  bool get allReady =>
      notificationsGranted &&
      exactAlarmGranted &&
      fullScreenIntentGranted &&
      batteryOptimizationIgnored;

  int get readyCount => [
        notificationsGranted,
        exactAlarmGranted,
        fullScreenIntentGranted,
        batteryOptimizationIgnored,
      ].where((e) => e).length;

  bool get isAggressiveOem {
    final m = deviceManufacturer.toLowerCase();
    return m.contains('xiaomi') ||
        m.contains('redmi') ||
        m.contains('poco') ||
        m.contains('oppo') ||
        m.contains('realme') ||
        m.contains('oneplus') ||
        m.contains('samsung') ||
        m.contains('vivo') ||
        m.contains('huawei') ||
        m.contains('honor');
  }
}

class PermissionGuardService {
  PermissionGuardService._();
  static final PermissionGuardService instance = PermissionGuardService._();

  static const _systemChannel = MethodChannel('com.chronoglass.app/system');

  Future<SystemReliabilityStatus> checkAll() async {
    if (!Platform.isAndroid) {
      final notif = await Permission.notification.isGranted;
      return SystemReliabilityStatus(
        notificationsGranted: notif,
        exactAlarmGranted: true,
        fullScreenIntentGranted: true,
        batteryOptimizationIgnored: true,
        deviceManufacturer: 'Apple',
        deviceModel: 'iOS',
        androidSdkInt: 0,
      );
    }

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    final notifGranted = await Permission.notification.isGranted;
    bool exactGranted = true;
    bool fullScreenGranted = true;
    bool batteryIgnored = true;

    try {
      exactGranted =
          await _systemChannel.invokeMethod<bool>('canScheduleExactAlarms') ??
              true;
    } catch (_) {
      exactGranted = await Permission.scheduleExactAlarm.isGranted;
    }

    try {
      fullScreenGranted =
          await _systemChannel.invokeMethod<bool>('canUseFullScreenIntent') ??
              true;
    } catch (_) {
      fullScreenGranted = true;
    }

    try {
      batteryIgnored = await _systemChannel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
    } catch (_) {
      batteryIgnored = await Permission.ignoreBatteryOptimizations.isGranted;
    }

    return SystemReliabilityStatus(
      notificationsGranted: notifGranted,
      exactAlarmGranted: exactGranted,
      fullScreenIntentGranted: fullScreenGranted,
      batteryOptimizationIgnored: batteryIgnored,
      deviceManufacturer: androidInfo.manufacturer,
      deviceModel: androidInfo.model,
      androidSdkInt: androidInfo.version.sdkInt,
    );
  }

  Future<void> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _systemChannel.invokeMethod('openExactAlarmSettings');
    } catch (_) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  Future<void> openFullScreenIntentSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _systemChannel.invokeMethod('openFullScreenIntentSettings');
    } catch (_) {
      await openAppSettings();
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _systemChannel.invokeMethod('openBatteryOptimizationSettings');
    } catch (_) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
}
