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
 * 1. Exact timestamp alarm triggers (ACTION_TRIGGER_ALARM & poweroffalarm.action.ALARM)
 *    - Verifies exact timestamp (prevents any premature trigger if a kernel fires early!)
 *    - Immediately invokes AlarmRingerController.startRinging() + AlarmForegroundService
 * 2. Device boot / Direct Boot (LOCKED_BOOT_COMPLETED, BOOT_COMPLETED, QUICKBOOT_POWERON)
 *    - Recovers all alarms from DeviceProtectedStorage & SQLite chronoglass.db
 *    - Reschedules all future exact-date alarms & catches up missed power-off alarms
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

            val now = System.currentTimeMillis()
            // Strict exact-date/time guard: if a buggy OEM fires more than 10 seconds early,
            // reschedule for the exact target millisecond instead of ringing on the wrong date/time!
            if (payload.triggerAtMillis > now + 10_000L) {
                Log.w(TAG, "Alarm ${payload.id} fired early! Rescheduling for exact timestamp ${payload.triggerAtMillis}")
                NativeAlarmScheduler.schedule(context, payload, persist = true)
                return
            }

            triggerAlarmImmediately(context, payload)
            return
        }

        // Boot / Direct Boot / Power-On / Package update / Time change recovery
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
        AlarmRingerController.startRinging(context, payload)
        try {
            val serviceIntent = Intent(context, AlarmForegroundService::class.java).apply {
                putExtrasFromPayload(payload)
            }
            ContextCompat.startForegroundService(context, serviceIntent)
        } catch (e: Exception) {
            Log.w(TAG, "ForegroundService promotion deferred (AlarmRingerController active): ${e.message}")
        }
    }

    private fun findDueAlarmInStorageOrDb(context: Context): NativeAlarmPayload? {
        val now = System.currentTimeMillis()
        val windowMs = 12L * 60L * 60L * 1000L
        return AlarmStorageHelper.getAllAlarms(context)
            .filter { it.triggerAtMillis <= now + 10_000L && now - it.triggerAtMillis <= windowMs }
            .maxByOrNull { it.triggerAtMillis }
    }

    private fun recoverAlarmsOnBoot(context: Context) {
        val now = System.currentTimeMillis()
        val missedWindowMs = 12L * 60L * 60L * 1000L
        val allAlarms = mutableMapOf<String, NativeAlarmPayload>()

        for (alarm in AlarmStorageHelper.getAllAlarms(context)) {
            allAlarms[alarm.id] = alarm
        }

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
            Log.w(TAG, "Direct-Boot SQLite read skipped: ${e.message}")
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
            Log.i(TAG, "Power-on recovery ringing missed alarm: ${missedToTrigger.id}")
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
