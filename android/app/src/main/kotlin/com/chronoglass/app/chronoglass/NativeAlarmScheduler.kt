package com.chronoglass.app.chronoglass

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Schedules exact calendar-date & time alarms using:
 * 1. Android's highest-priority AlarmManager.setAlarmClock API (exact epoch triggerAtMillis)
 * 2. Exact-epoch Hardware RTC Power-Off drivers (Qualcomm com.qualcomm.qti.poweroffalarm & RTC_POWEROFF_WAKEUP)
 * Never delegates to the stock Clock app (which ignores future calendar dates).
 */
object NativeAlarmScheduler {
    private const val TAG = "ChronoGlassScheduler"
    private const val RTC_POWEROFF_WAKEUP = 5

    fun requestCodeFor(id: String): Int = (id.hashCode() and 0x7FFFFFFF)

    fun schedule(context: Context, payload: NativeAlarmPayload, persist: Boolean = true) {
        if (payload.id.isEmpty()) return
        if (persist) {
            AlarmStorageHelper.saveAlarm(context, payload)
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val reqCode = requestCodeFor(payload.id)

        val alarmIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_TRIGGER_ALARM
            putExtrasFromPayload(payload)
        }

        val alarmPendingIntent = PendingIntent.getBroadcast(
            context,
            reqCode,
            alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val showIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtrasFromPayload(payload)
            putExtra(AlarmReceiver.EXTRA_IS_ALARM_LAUNCH, true)
        }

        val showPendingIntent = PendingIntent.getActivity(
            context,
            reqCode,
            showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }

        try {
            if (canExact) {
                val clockInfo = AlarmManager.AlarmClockInfo(payload.triggerAtMillis, showPendingIntent)
                alarmManager.setAlarmClock(clockInfo, alarmPendingIntent)
                Log.i(TAG, "setAlarmClock scheduled: id=${payload.id}, triggerAt=${payload.triggerAtMillis}")
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    payload.triggerAtMillis,
                    alarmPendingIntent
                )
                Log.w(TAG, "Exact alarm permission missing; fallback setAndAllowWhileIdle: id=${payload.id}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule alarm ${payload.id}: ${e.message}", e)
        }

        // Exact-epoch Hardware Power-Off RTC Alarm (respects exact calendar date + time)
        scheduleHardwarePowerOffRtc(context, alarmManager, payload, alarmPendingIntent)
    }

    private fun scheduleHardwarePowerOffRtc(
        context: Context,
        alarmManager: AlarmManager,
        payload: NativeAlarmPayload,
        alarmPendingIntent: PendingIntent
    ) {
        try {
            val qtiIntent = Intent("org.codeaurora.poweroffalarm.action.SET_ALARM").apply {
                setPackage("com.qualcomm.qti.poweroffalarm")
                putExtra("time", payload.triggerAtMillis)
            }
            context.sendBroadcast(qtiIntent)
        } catch (_: Exception) {
        }

        try {
            alarmManager.setExactAndAllowWhileIdle(
                RTC_POWEROFF_WAKEUP,
                payload.triggerAtMillis,
                alarmPendingIntent
            )
        } catch (_: Exception) {
        }
    }

    fun cancel(context: Context, id: String) {
        if (id.isEmpty()) return
        val existing = AlarmStorageHelper.getAlarm(context, id)
        AlarmStorageHelper.removeAlarm(context, id)

        if (existing != null) {
            try {
                val qtiCancel = Intent("org.codeaurora.poweroffalarm.action.CANCEL_ALARM").apply {
                    setPackage("com.qualcomm.qti.poweroffalarm")
                    putExtra("time", existing.triggerAtMillis)
                }
                context.sendBroadcast(qtiCancel)
            } catch (_: Exception) {
            }
        }

        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val alarmIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = AlarmReceiver.ACTION_TRIGGER_ALARM
            }
            val pending = PendingIntent.getBroadcast(
                context,
                requestCodeFor(id),
                alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pending)
            Log.i(TAG, "Cancelled native alarm id=$id")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel alarm $id: ${e.message}")
        }
    }

    fun Intent.putExtrasFromPayload(payload: NativeAlarmPayload) {
        putExtra(AlarmReceiver.EXTRA_ID, payload.id)
        putExtra(AlarmReceiver.EXTRA_TRIGGER_AT, payload.triggerAtMillis)
        putExtra(AlarmReceiver.EXTRA_TITLE, payload.title)
        putExtra(AlarmReceiver.EXTRA_BODY, payload.body)
        putExtra(AlarmReceiver.EXTRA_RINGTONE_PATH, payload.ringtonePath)
        putExtra(AlarmReceiver.EXTRA_IS_ASSET, payload.isAsset)
        putExtra(AlarmReceiver.EXTRA_DISMISS_CHALLENGE, payload.dismissChallenge)
        putExtra(AlarmReceiver.EXTRA_SNOOZE_MINUTES, payload.snoozeMinutes)
    }

    fun payloadFromIntent(intent: Intent?): NativeAlarmPayload? {
        if (intent == null) return null
        val id = intent.getStringExtra(AlarmReceiver.EXTRA_ID)
            ?: intent.getStringExtra("reminder_id")
            ?: return null
        if (id.isEmpty()) return null
        return NativeAlarmPayload(
            id = id,
            triggerAtMillis = intent.getLongExtra(AlarmReceiver.EXTRA_TRIGGER_AT, System.currentTimeMillis()),
            title = intent.getStringExtra(AlarmReceiver.EXTRA_TITLE)
                ?: intent.getStringExtra("reminder_title")
                ?: "ChronoGlass Alarm",
            body = intent.getStringExtra(AlarmReceiver.EXTRA_BODY) ?: "",
            ringtonePath = intent.getStringExtra(AlarmReceiver.EXTRA_RINGTONE_PATH)
                ?: "assets/sounds/morning_marimba.wav",
            isAsset = intent.getBooleanExtra(AlarmReceiver.EXTRA_IS_ASSET, true),
            dismissChallenge = intent.getStringExtra(AlarmReceiver.EXTRA_DISMISS_CHALLENGE) ?: "slide",
            snoozeMinutes = intent.getIntExtra(AlarmReceiver.EXTRA_SNOOZE_MINUTES, 5)
        )
    }
}
