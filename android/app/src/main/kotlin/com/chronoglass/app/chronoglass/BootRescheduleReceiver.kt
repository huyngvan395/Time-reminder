package com.chronoglass.app.chronoglass

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.util.Log

/**
 * Device Reboot & Power-On Recovery Receiver:
 * 1. Immediately reschedules all upcoming active alarms from SQLite via AlarmTriggerReceiver.scheduleExact().
 * 2. Immediately catches up and rings any active alarm that occurred while the device was powered off
 *    (within a 12-hour catch-up window).
 */
class BootRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.i("ChronoGlassBoot", "Received system broadcast: $action — recovering scheduled alarms.")

        try {
            val dbFile = context.getDatabasePath("chronoglass.db")
            if (!dbFile.exists()) return

            val db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
            val nowMs = System.currentTimeMillis()
            val catchUpWindowMs = 12L * 60L * 60L * 1000L // 12 hours
            var missedToRingId: String? = null
            var missedToRingTitle: String? = null

            db.rawQuery(
                "SELECT id, title, scheduled_at_ms FROM reminders WHERE is_active = 1 AND is_completed = 0 ORDER BY scheduled_at_ms ASC",
                null
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    val id = cursor.getString(0)
                    val title = cursor.getString(1)
                    val triggerAtMs = cursor.getLong(2)

                    if (triggerAtMs > nowMs) {
                        AlarmTriggerReceiver.scheduleExact(context, id, title, triggerAtMs)
                    } else if (nowMs - triggerAtMs <= catchUpWindowMs && missedToRingId == null) {
                        // Catch up missed alarm that fired while phone was powered off
                        missedToRingId = id
                        missedToRingTitle = title
                    }
                }
            }
            db.close()

            if (missedToRingId != null) {
                Log.i("ChronoGlassBoot", "Power-on catch-up ringing missed alarm: $missedToRingId")
                AlarmTriggerReceiver.triggerNow(
                    context,
                    missedToRingId!!,
                    missedToRingTitle ?: "ChronoGlass Alarm"
                )
            }
        } catch (e: Exception) {
            Log.e("ChronoGlassBoot", "Failed to recover alarms on boot: ${e.message}", e)
        }
    }
}
