package com.chronoglass.app.chronoglass

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log
import androidx.core.content.ContextCompat
import com.chronoglass.app.chronoglass.NativeAlarmScheduler.putExtrasFromPayload

/**
 * Native BroadcastReceiver handling both:
 * 1. Exact alarm triggers (ACTION_TRIGGER_ALARM) -> acquires WakeLock & starts AlarmForegroundService
 * 2. Device boot / package replacement -> reschedules future alarms & triggers any missed alarm within 15 mins
 */
class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.i(TAG, "AlarmReceiver onReceive action=$action")

        if (action == ACTION_TRIGGER_ALARM) {
            acquireWakeLock(context)
            val payload = NativeAlarmScheduler.payloadFromIntent(intent)
                ?: intent.getStringExtra(EXTRA_ID)?.let { AlarmStorageHelper.getAlarm(context, it) }
                ?: return

            startRingingService(context, payload)
            return
        }

        // Boot / Package update / Time change recovery
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_LOCKED_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON" ||
            action == Intent.ACTION_TIME_CHANGED ||
            action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED"
        ) {
            recoverAlarmsOnBoot(context)
        }
    }

    private fun acquireWakeLock(context: Context) {
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val cpuLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "ChronoGlass:AlarmReceiverCpuLock"
            )
            cpuLock.acquire(60_000L)

            @Suppress("DEPRECATION")
            val screenLock = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                "ChronoGlass:AlarmReceiverScreenLock"
            )
            screenLock.acquire(15_000L)
        } catch (e: Exception) {
            Log.w(TAG, "WakeLock warning: ${e.message}")
        }
    }

    private fun startRingingService(context: Context, payload: NativeAlarmPayload) {
        try {
            val serviceIntent = Intent(context, AlarmForegroundService::class.java).apply {
                putExtrasFromPayload(payload)
            }
            ContextCompat.startForegroundService(context, serviceIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start AlarmForegroundService: ${e.message}", e)
        }
    }

    private fun recoverAlarmsOnBoot(context: Context) {
        val now = System.currentTimeMillis()
        val missedWindowMs = 15L * 60L * 1000L // 15 minutes
        val saved = AlarmStorageHelper.getAllAlarms(context)
        var missedToTrigger: NativeAlarmPayload? = null

        for (alarm in saved) {
            if (alarm.triggerAtMillis > now) {
                NativeAlarmScheduler.schedule(context, alarm, persist = false)
            } else if (now - alarm.triggerAtMillis in 0..missedWindowMs) {
                if (missedToTrigger == null || alarm.triggerAtMillis > missedToTrigger.triggerAtMillis) {
                    missedToTrigger = alarm
                }
            } else {
                AlarmStorageHelper.removeAlarm(context, alarm.id)
            }
        }

        if (missedToTrigger != null) {
            Log.i(TAG, "Boot recovery triggering missed alarm: ${missedToTrigger.id}")
            acquireWakeLock(context)
            startRingingService(context, missedToTrigger)
        }
    }

    companion object {
        private const val TAG = "ChronoGlassReceiver"
        const val ACTION_TRIGGER_ALARM = "com.chronoglass.app.chronoglass.ACTION_TRIGGER_ALARM"

        const val EXTRA_ID = "id"
        const val EXTRA_TRIGGER_AT = "triggerAtMillis"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_RINGTONE_PATH = "ringtonePath"
        const val EXTRA_IS_ASSET = "isAsset"
        const val EXTRA_DISMISS_CHALLENGE = "dismissChallenge"
        const val EXTRA_SNOOZE_MINUTES = "snoozeMinutes"
        const val EXTRA_IS_ALARM_LAUNCH = "is_alarm_launch"
    }
}
