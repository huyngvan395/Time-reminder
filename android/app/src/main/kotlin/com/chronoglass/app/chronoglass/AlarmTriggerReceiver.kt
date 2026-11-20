package com.chronoglass.app.chronoglass

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Native fail-safe BroadcastReceiver invoked by Android AlarmManager.setAlarmClock().
 * Wakes the CPU & screen from Deep Doze / Lockscreen (Android 9 / ColorOS 6+),
 * posts a high-priority Full-Screen Intent alarm notification, and launches MainActivity
 * directly into FullScreenAlarmScreen.
 */
class AlarmTriggerReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val reminderId = intent?.getStringExtra(EXTRA_REMINDER_ID) ?: return
        val reminderTitle = intent.getStringExtra(EXTRA_REMINDER_TITLE) ?: "ChronoGlass Alarm"
        Log.i(TAG, "Native AlarmTriggerReceiver fired for reminder=$reminderId ($reminderTitle)")
        triggerNow(context, reminderId, reminderTitle)
    }

    companion object {
        private const val TAG = "ChronoGlassAlarm"
        const val EXTRA_REMINDER_ID = "reminder_id"
        const val EXTRA_REMINDER_TITLE = "reminder_title"
        const val EXTRA_IS_ALARM_LAUNCH = "is_alarm_launch"
        private const val CHANNEL_ID = "chronoglass_strong_alarm_channel"

        fun requestCodeFor(id: String): Int = (id.hashCode() and 0x7FFFFFFF)

        fun scheduleExact(context: Context, id: String, title: String, triggerAtMs: Long) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val receiverIntent = Intent(context, AlarmTriggerReceiver::class.java).apply {
                putExtra(EXTRA_REMINDER_ID, id)
                putExtra(EXTRA_REMINDER_TITLE, title)
            }
            val reqCode = requestCodeFor(id)
            val operation = PendingIntent.getBroadcast(
                context,
                reqCode,
                receiverIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val showIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra(EXTRA_REMINDER_ID, id)
                putExtra(EXTRA_REMINDER_TITLE, title)
                putExtra(EXTRA_IS_ALARM_LAUNCH, true)
            }
            val showPending = PendingIntent.getActivity(
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
                    val info = AlarmManager.AlarmClockInfo(triggerAtMs, showPending)
                    alarmManager.setAlarmClock(info, operation)
                    Log.i(TAG, "Scheduled setAlarmClock for $id at $triggerAtMs")
                } else {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, operation)
                    Log.w(TAG, "Exact alarm denied; scheduled setAndAllowWhileIdle for $id")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule native alarm for $id: ${e.message}", e)
            }
        }

        fun cancel(context: Context, id: String) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val receiverIntent = Intent(context, AlarmTriggerReceiver::class.java)
                val operation = PendingIntent.getBroadcast(
                    context,
                    requestCodeFor(id),
                    receiverIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(operation)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cancel native alarm for $id: ${e.message}")
            }
        }

        fun triggerNow(context: Context, id: String, title: String) {
            // 1. Acquire wake lock to wake screen & CPU immediately on Android 9 / ColorOS 6+
            try {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                @Suppress("DEPRECATION")
                val wl = pm.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                        PowerManager.ACQUIRE_CAUSES_WAKEUP or
                        PowerManager.ON_AFTER_RELEASE,
                    "ChronoGlass:AlarmWakeLock"
                )
                wl.acquire(10_000L)
            } catch (e: Exception) {
                Log.w(TAG, "WakeLock acquire warning: ${e.message}")
            }

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
                putExtra(EXTRA_REMINDER_ID, id)
                putExtra(EXTRA_REMINDER_TITLE, title)
                putExtra(EXTRA_IS_ALARM_LAUNCH, true)
            }

            val reqCode = requestCodeFor(id)
            val fullScreenPendingIntent = PendingIntent.getActivity(
                context,
                reqCode,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // 2. Post full-screen high-priority alarm notification (works on Android 10-15 lockscreen)
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val existing = nm.getNotificationChannel(CHANNEL_ID)
                    if (existing == null) {
                        val soundUri = Uri.parse("android.resource://${context.packageName}/raw/aurora_chime")
                        val attrs = AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                        val channel = NotificationChannel(
                            CHANNEL_ID,
                            "ChronoGlass Strong Alarms",
                            NotificationManager.IMPORTANCE_HIGH
                        ).apply {
                            description = "High-priority full-screen lockscreen alarms"
                            enableVibration(true)
                            vibrationPattern = longArrayOf(0, 600, 400, 800, 400)
                            setSound(soundUri, attrs)
                            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                        }
                        nm.createNotificationChannel(channel)
                    }
                }

                val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                    .setSmallIcon(context.applicationInfo.icon)
                    .setContentTitle(title)
                    .setContentText("Báo thức đang reo • Chạm để mở")
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setOngoing(true)
                    .setAutoCancel(true)
                    .setContentIntent(fullScreenPendingIntent)
                    .setFullScreenIntent(fullScreenPendingIntent, true)
                    .build()

                nm.notify(reqCode, notification)
            } catch (e: Exception) {
                Log.e(TAG, "Notification post warning: ${e.message}")
            }

            // 3. Directly launch MainActivity (essential on Android 9 / ColorOS 6)
            try {
                context.startActivity(launchIntent)
            } catch (e: Exception) {
                Log.w(TAG, "Direct startActivity deferred to fullScreenIntent: ${e.message}")
            }
        }
    }
}
