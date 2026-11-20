package com.chronoglass.app.chronoglass

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import androidx.core.content.ContextCompat
import com.chronoglass.app.chronoglass.NativeAlarmScheduler.putExtrasFromPayload

/**
 * Native BroadcastReceiver handling:
 * 1. Exact alarm triggers (ACTION_TRIGGER_ALARM & poweroffalarm.action.ALARM)
 *    -> IMMEDIATELY invokes AlarmRingerController.startRinging() (popup notification + sound + vibration + lockscreen launch)
 *    AND promotes to AlarmForegroundService.
 * 2. Device boot / power-on / Direct Boot (LOCKED_BOOT_COMPLETED, BOOT_COMPLETED, QUICKBOOT_POWERON)
 *    -> Recovers all alarms from Direct-Boot SharedPreferences AND SQLite chronoglass.db,
 *    reschedules future alarms, and immediately rings any alarm that occurred while powered off!
 */
class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.i(TAG, "AlarmReceiver onReceive action=$action")

        if (action == ACTION_TRIGGER_ALARM ||
            action == "org.codeaurora.poweroffalarm.action.ALARM"
        ) {
            val payload = NativeAlarmScheduler.payloadFromIntent(intent)
                ?: intent.getStringExtra(EXTRA_ID)?.let { AlarmStorageHelper.getAlarm(context, it) }
                ?: findDueAlarmInStorageOrDb(context)
                ?: return

            triggerAlarmImmediately(context, payload)
            return
        }

        // Boot / Direct Boot (before PIN unlock) / Power-On / Package update / Time change recovery
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_LOCKED_BOOT_COMPLETED ||
            action == Intent.ACTION_REBOOT ||
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

    private fun triggerAlarmImmediately(context: Context, payload: NativeAlarmPayload) {
        // 1. Synchronously start popup notification, MediaPlayer (USAGE_ALARM), Vibrator & WakeLock right inside onReceive!
        AlarmRingerController.startRinging(context, payload)

        // 2. Also start AlarmForegroundService to keep process at Foreground Service priority
        try {
            val serviceIntent = Intent(context, AlarmForegroundService::class.java).apply {
                putExtrasFromPayload(payload)
            }
            ContextCompat.startForegroundService(context, serviceIntent)
        } catch (e: Exception) {
            Log.w(TAG, "ForegroundService promotion deferred (AlarmRingerController already ringing): ${e.message}")
        }
    }

    private fun findDueAlarmInStorageOrDb(context: Context): NativeAlarmPayload? {
        val now = System.currentTimeMillis()
        val windowMs = 12L * 60L * 60L * 1000L
        val saved = AlarmStorageHelper.getAllAlarms(context)
        return saved
            .filter { it.triggerAtMillis <= now + 60_000L && now - it.triggerAtMillis <= windowMs }
            .maxByOrNull { it.triggerAtMillis }
    }

    private fun recoverAlarmsOnBoot(context: Context) {
        val now = System.currentTimeMillis()
        // 12-hour catch-up window so any alarm that fired while the phone was powered off rings on power-on
        val missedWindowMs = 12L * 60L * 60L * 1000L
        val allAlarms = mutableMapOf<String, NativeAlarmPayload>()

        // 1. Load from Direct-Boot SharedPreferences
        for (alarm in AlarmStorageHelper.getAllAlarms(context)) {
            allAlarms[alarm.id] = alarm
        }

        // 2. Also load from SQLite chronoglass.db (if available after user unlock)
        try {
            val dbFile = context.getDatabasePath("chronoglass.db")
            if (dbFile.exists()) {
                val db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
                db.rawQuery(
                    "SELECT id, title, notes, scheduled_at_ms, snooze_interval_minutes FROM reminders WHERE is_active = 1 AND is_completed = 0",
                    null
                ).use { cursor ->
                    while (cursor.moveToNext()) {
                        val id = cursor.getString(0)
                        if (!allAlarms.containsKey(id)) {
                            val title = cursor.getString(1) ?: "ChronoGlass Alarm"
                            val notes = cursor.getString(2) ?: ""
                            val triggerAtMs = cursor.getLong(3)
                            val snoozeMins = cursor.getInt(4)
                            allAlarms[id] = NativeAlarmPayload(
                                id = id,
                                triggerAtMillis = triggerAtMs,
                                title = title,
                                body = notes,
                                ringtonePath = "assets/sounds/morning_marimba.wav",
                                isAsset = true,
                                dismissChallenge = "slide",
                                snoozeMinutes = if (snoozeMins > 0) snoozeMins else 5
                            )
                        }
                    }
                }
                db.close()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Direct-Boot SQLite read skipped (using DeviceProtectedStorage): ${e.message}")
        }

        var missedToTrigger: NativeAlarmPayload? = null

        for (alarm in allAlarms.values) {
            if (alarm.triggerAtMillis > now + 5_000L) {
                NativeAlarmScheduler.schedule(context, alarm, persist = true)
            } else if (now - alarm.triggerAtMillis <= missedWindowMs) {
                if (missedToTrigger == null || alarm.triggerAtMillis > missedToTrigger.triggerAtMillis) {
                    missedToTrigger = alarm
                }
            } else {
                AlarmStorageHelper.removeAlarm(context, alarm.id)
            }
        }

        if (missedToTrigger != null) {
            Log.i(TAG, "Power-on recovery ringing alarm that occurred during power-off: ${missedToTrigger.id}")
            triggerAlarmImmediately(context, missedToTrigger)
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
