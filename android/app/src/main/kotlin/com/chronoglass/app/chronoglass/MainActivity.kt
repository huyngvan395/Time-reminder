package com.chronoglass.app.chronoglass

import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val systemChannelName = "com.chronoglass.app/system"
    private val nativeAlarmChannelName = "com.chronoglass.app/native_alarm"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableLockScreenAlarmMode(true)
        extractAlarmIntent(intent, dispatchNow = false)
    }

    override fun onResume() {
        super.onResume()
        isForeground = true
        // Hide the floating pill when user enters ChronoGlass directly
        if (AlarmRingerController.isRinging) {
            AlarmOverlayManager.dismiss(this)
        }
    }

    override fun onPause() {
        isForeground = false
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        enableLockScreenAlarmMode(true)
        extractAlarmIntent(intent, dispatchNow = true)
    }

    private fun extractAlarmIntent(intent: Intent?, dispatchNow: Boolean) {
        val payload = NativeAlarmScheduler.payloadFromIntent(intent) ?: return
        val isAlarm = intent?.getBooleanExtra(AlarmReceiver.EXTRA_IS_ALARM_LAUNCH, false) == true
        if (isAlarm || AlarmRingerController.isRinging) {
            pendingPayload = payload
            if (dispatchNow) {
                deliverAlarmToFlutter(payload)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        nativeAlarmChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            nativeAlarmChannelName
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        val id = call.argument<String>("id") ?: ""
                        val triggerAtMillis = call.argument<Number>("triggerAtMillis")?.toLong() ?: 0L
                        val title = call.argument<String>("title") ?: "ChronoGlass Alarm"
                        val body = call.argument<String>("body") ?: ""
                        val ringtonePath = call.argument<String>("ringtonePath")
                            ?: "assets/sounds/morning_marimba.wav"
                        val isAsset = call.argument<Boolean>("isAsset") ?: true
                        val dismissChallenge = call.argument<String>("dismissChallenge") ?: "slide"
                        val snoozeMinutes = call.argument<Number>("snoozeMinutes")?.toInt() ?: 5

                        if (id.isNotEmpty() && triggerAtMillis > 0L) {
                            val payload = NativeAlarmPayload(
                                id = id,
                                triggerAtMillis = triggerAtMillis,
                                title = title,
                                body = body,
                                ringtonePath = ringtonePath,
                                isAsset = isAsset,
                                dismissChallenge = dismissChallenge,
                                snoozeMinutes = snoozeMinutes
                            )
                            NativeAlarmScheduler.schedule(this, payload, persist = true)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "cancelAlarm" -> {
                        val id = call.argument<String>("id") ?: ""
                        if (id.isNotEmpty()) {
                            NativeAlarmScheduler.cancel(this, id)
                        }
                        result.success(true)
                    }
                    "stopRinging" -> {
                        pendingPayload = null
                        AlarmRingerController.stopRinging(this)
                        result.success(true)
                    }
                    "isNativeRinging" -> {
                        result.success(AlarmRingerController.isRinging)
                    }
                    "getPendingAlarm" -> {
                        val active = pendingPayload ?: AlarmStorageHelper.getRingingAlarm(this)
                        pendingPayload = null
                        if (active != null) {
                            result.success(active.toMap())
                        } else {
                            result.success(null)
                        }
                    }
                    "openAppSettings" -> {
                        openApplicationDetailsSettings()
                        result.success(true)
                    }
                    "openAutoStartSettings" -> {
                        openOemAutoStartSettings()
                        result.success(true)
                    }
                    "canDrawOverlays" -> {
                        result.success(AlarmOverlayManager.canDrawOverlays(this))
                    }
                    "openOverlaySettings" -> {
                        openOverlayPermissionSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        systemChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            systemChannelName
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingAlarm" -> {
                        val active = pendingPayload ?: AlarmStorageHelper.getRingingAlarm(this)
                        pendingPayload = null
                        if (active != null) {
                            result.success(active.toMap())
                        } else {
                            result.success(null)
                        }
                    }
                    "openAppSettings" -> {
                        openApplicationDetailsSettings()
                        result.success(true)
                    }
                    "openAutoStartSettings" -> {
                        openOemAutoStartSettings()
                        result.success(true)
                    }
                    "canDrawOverlays" -> {
                        result.success(AlarmOverlayManager.canDrawOverlays(this))
                    }
                    "openOverlaySettings" -> {
                        openOverlayPermissionSettings()
                        result.success(true)
                    }
                    "canScheduleExactAlarms" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            result.success(alarmManager.canScheduleExactAlarms())
                        } else {
                            result.success(true)
                        }
                    }
                    "openExactAlarmSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    }
                    "canUseFullScreenIntent" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            result.success(nm.canUseFullScreenIntent())
                        } else {
                            result.success(true)
                        }
                    }
                    "openFullScreenIntentSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        } else {
                            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "openBatteryOptimizationSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        } catch (e: Exception) {
                            val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallback)
                        }
                        result.success(true)
                    }
                    "setLockScreenAlarmMode" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        enableLockScreenAlarmMode(enabled)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun openOverlayPermissionSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return
            } catch (_: Exception) {
            }
        }
        openApplicationDetailsSettings()
    }

    private fun openOemAutoStartSettings() {
        val candidates = listOf(
            // Xiaomi MIUI / HyperOS Autostart
            Intent().setComponent(
                ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity"
                )
            ),
            // Xiaomi MIUI / HyperOS Other Permissions (Display pop-up windows in background / Lockscreen)
            Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                setClassName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.permissions.PermissionsEditorActivity"
                )
                putExtra("extra_pkgname", packageName)
            },
            // OPPO / Realme ColorOS
            Intent().setComponent(
                ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                )
            ),
            Intent().setComponent(
                ComponentName(
                    "com.oplus.safecenter",
                    "com.oplus.safecenter.permission.startup.StartupAppListActivity"
                )
            ),
            // Vivo
            Intent().setComponent(
                ComponentName(
                    "com.iqoo.secure",
                    "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"
                )
            ),
            // Huawei / Honor
            Intent().setComponent(
                ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                )
            )
        )

        for (candidate in candidates) {
            try {
                candidate.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (packageManager.resolveActivity(candidate, 0) != null) {
                    startActivity(candidate)
                    return
                }
            } catch (_: Exception) {
            }
        }
        openApplicationDetailsSettings()
    }

    private fun openApplicationDetailsSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (_: Exception) {
        }
    }

    private fun enableLockScreenAlarmMode(enabled: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(enabled)
            setTurnScreenOn(enabled)
            if (enabled) {
                val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                keyguardManager.requestDismissKeyguard(this, null)
            }
        }
        if (enabled) {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        } else {
            @Suppress("DEPRECATION")
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    override fun onDestroy() {
        isForeground = false
        nativeAlarmChannel = null
        systemChannel = null
        super.onDestroy()
    }

    companion object {
        private val mainHandler = Handler(Looper.getMainLooper())
        private var nativeAlarmChannel: MethodChannel? = null
        private var systemChannel: MethodChannel? = null
        private var pendingPayload: NativeAlarmPayload? = null

        @Volatile
        var isForeground: Boolean = false

        fun deliverAlarmToFlutter(payload: NativeAlarmPayload) {
            pendingPayload = payload
            mainHandler.post {
                nativeAlarmChannel?.invokeMethod("onAlarmFired", payload.toMap())
            }
        }

        fun deliverNativeActionToFlutter(action: String, id: String, snoozeMinutes: Int) {
            mainHandler.post {
                nativeAlarmChannel?.invokeMethod(
                    "onNativeAlarmAction",
                    mapOf("action" to action, "id" to id, "snoozeMinutes" to snoozeMinutes)
                )
            }
        }
    }
}
