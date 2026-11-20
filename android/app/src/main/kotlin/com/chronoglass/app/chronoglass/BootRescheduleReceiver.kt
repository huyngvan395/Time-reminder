package com.chronoglass.app.chronoglass

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.util.Log

/**
 * Automatically recalculates and reschedules active alarms from the local SQLite database
 * immediately after device reboot, package update, or timezone/clock change.
 */
class BootRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.i("ChronoGlassBoot", "Received system broadcast: $action — verifying scheduled alarms.")

        try {
            val dbFile = context.getDatabasePath("chronoglass.db")
            if (!dbFile.exists()) return

            val db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
            val nowMs = System.currentTimeMillis()
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            db.rawQuery(
                "SELECT id, title, scheduled_at_ms, alert_mode FROM reminders WHERE is_active = 1 AND is_completed = 0 AND scheduled_at_ms > ?",
                arrayOf(nowMs.toString())
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    val id = cursor.getString(0)
                    val title = cursor.getString(1)
                    val triggerAtMs = cursor.getLong(2)
                    val alertMode = cursor.getInt(3)

                    val launchIntent = Intent(context, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        putExtra("reminder_id", id)
                        putExtra("reminder_title", title)
                        putExtra("is_alarm_launch", alertMode == 1)
                    }

                    val requestCode = id.hashCode() and 0x7FFFFFFF
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        requestCode,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    val canScheduleExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        alarmManager.canScheduleExactAlarms()
                    } else {
                        true
                    }

                    if (alertMode == 1 && canScheduleExact) {
                        val clockInfo = AlarmManager.AlarmClockInfo(triggerAtMs, pendingIntent)
                        alarmManager.setAlarmClock(clockInfo, pendingIntent)
                    } else if (canScheduleExact) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerAtMs,
                            pendingIntent
                        )
                    } else {
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerAtMs,
                            pendingIntent
                        )
                    }
                }
            }
            db.close()
        } catch (e: Exception) {
            Log.e("ChronoGlassBoot", "Failed to reschedule alarms on boot: ${e.message}", e)
        }
    }
}
