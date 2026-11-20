package com.chronoglass.app.chronoglass

import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.util.Log

/**
 * Handles Dismiss (■) and Snooze (Zz) actions from BOTH the Floating Pill Overlay
 * and the Custom Heads-Up Notification — syncing directly to SQLite chronoglass.db
 * even when the Flutter app is completely closed!
 */
class AlarmActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        val payload = NativeAlarmScheduler.payloadFromIntent(intent)
            ?: AlarmStorageHelper.getRingingAlarm(context)

        Log.i(TAG, "Action received=$action for alarm=${payload?.id}")
        if (payload == null) {
            AlarmRingerController.stopRinging(context)
            return
        }

        when (action) {
            ACTION_DISMISS -> handleDismiss(context, payload)
            ACTION_SNOOZE -> handleSnooze(context, payload)
        }
    }

    companion object {
        private const val TAG = "ChronoGlassAction"
        const val ACTION_DISMISS = "com.chronoglass.app.chronoglass.ACTION_DISMISS_ALARM"
        const val ACTION_SNOOZE = "com.chronoglass.app.chronoglass.ACTION_SNOOZE_ALARM"

        fun handleDismiss(context: Context, payload: NativeAlarmPayload) {
            AlarmRingerController.stopRinging(context)
            AlarmStorageHelper.removeAlarm(context, payload.id)

            // Sync dismissal directly to SQLite chronoglass.db so opening the app later
            // never re-triggers an already-dismissed one-time reminder!
            if (payload.id != "chronoglass_test_5s_alarm") {
                try {
                    val dbFile = context.getDatabasePath("chronoglass.db")
                    if (dbFile.exists()) {
                        val db = SQLiteDatabase.openDatabase(
                            dbFile.path,
                            null,
                            SQLiteDatabase.OPEN_READWRITE
                        )
                        // Check recurrence_type (0 = one-time)
                        var isOnce = true
                        db.rawQuery(
                            "SELECT recurrence_type FROM reminders WHERE id = ? LIMIT 1",
                            arrayOf(payload.id)
                        ).use { cursor ->
                            if (cursor.moveToFirst()) {
                                isOnce = cursor.getInt(0) == 0
                            }
                        }
                        if (isOnce) {
                            val values = ContentValues().apply {
                                put("is_completed", 1)
                                put("is_active", 0)
                                put("updated_at_ms", System.currentTimeMillis())
                            }
                            db.update("reminders", values, "id = ?", arrayOf(payload.id))
                        }
                        db.close()
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "SQLite dismiss sync warning: ${e.message}")
                }
            }

            MainActivity.deliverNativeActionToFlutter("dismiss", payload.id, 0)
        }

        fun handleSnooze(context: Context, payload: NativeAlarmPayload) {
            AlarmRingerController.stopRinging(context)
            val mins = if (payload.snoozeMinutes > 0) payload.snoozeMinutes else 5
            val nextTrigger = System.currentTimeMillis() + mins * 60_000L
            val snoozedPayload = payload.copy(triggerAtMillis = nextTrigger)
            NativeAlarmScheduler.schedule(context, snoozedPayload, persist = true)

            if (payload.id != "chronoglass_test_5s_alarm") {
                try {
                    val dbFile = context.getDatabasePath("chronoglass.db")
                    if (dbFile.exists()) {
                        val db = SQLiteDatabase.openDatabase(
                            dbFile.path,
                            null,
                            SQLiteDatabase.OPEN_READWRITE
                        )
                        db.execSQL(
                            "UPDATE reminders SET scheduled_at_ms = ?, current_snooze_count = current_snooze_count + 1, updated_at_ms = ? WHERE id = ?",
                            arrayOf(nextTrigger, System.currentTimeMillis(), payload.id)
                        )
                        db.close()
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "SQLite snooze sync warning: ${e.message}")
                }
            }

            MainActivity.deliverNativeActionToFlutter("snooze", payload.id, mins)
        }
    }
}
