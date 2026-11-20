package com.chronoglass.app.chronoglass

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Handles lockscreen / heads-up notification action buttons:
 * - "Tắt báo thức" (ACTION_DISMISS)
 * - "Báo lại 5 phút" (ACTION_SNOOZE)
 */
class AlarmActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        val payload = NativeAlarmScheduler.payloadFromIntent(intent)
            ?: AlarmStorageHelper.getRingingAlarm(context)

        Log.i("ChronoGlassAction", "Notification action=$action for alarm=${payload?.id}")
        AlarmForegroundService.stopAlarm(context)

        if (payload == null) return

        when (action) {
            ACTION_DISMISS -> {
                AlarmStorageHelper.removeAlarm(context, payload.id)
                MainActivity.deliverNativeActionToFlutter("dismiss", payload.id, 0)
            }
            ACTION_SNOOZE -> {
                val mins = if (payload.snoozeMinutes > 0) payload.snoozeMinutes else 5
                val nextTrigger = System.currentTimeMillis() + mins * 60_000L
                val snoozedPayload = payload.copy(triggerAtMillis = nextTrigger)
                NativeAlarmScheduler.schedule(context, snoozedPayload, persist = true)
                MainActivity.deliverNativeActionToFlutter("snooze", payload.id, mins)
            }
        }
    }

    companion object {
        const val ACTION_DISMISS = "com.chronoglass.app.chronoglass.ACTION_DISMISS_ALARM"
        const val ACTION_SNOOZE = "com.chronoglass.app.chronoglass.ACTION_SNOOZE_ALARM"
    }
}
