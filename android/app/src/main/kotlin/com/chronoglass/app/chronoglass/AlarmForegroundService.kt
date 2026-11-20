package com.chronoglass.app.chronoglass

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * ForegroundService that keeps the ChronoGlass alarm process at foreground priority while
 * AlarmRingerController plays looping USAGE_ALARM audio, vibrates, and displays the popup/lockscreen notification.
 */
class AlarmForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val payload = NativeAlarmScheduler.payloadFromIntent(intent)
            ?: AlarmStorageHelper.getRingingAlarm(this)
            ?: NativeAlarmPayload(
                id = "default_alarm",
                triggerAtMillis = System.currentTimeMillis(),
                title = "ChronoGlass Alarm",
                body = "Báo thức đang reo",
                ringtonePath = "assets/sounds/morning_marimba.wav",
                isAsset = true,
                dismissChallenge = "slide",
                snoozeMinutes = 5
            )

        val notification = AlarmRingerController.startRinging(this, payload)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    AlarmRingerController.NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
            } else {
                startForeground(AlarmRingerController.NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.w("ChronoGlassFgService", "startForeground warning (AlarmRingerController already active): ${e.message}")
        }

        return START_STICKY
    }

    companion object {
        val isRinging: Boolean
            get() = AlarmRingerController.isRinging

        fun stopAlarm(context: Context) {
            AlarmRingerController.stopRinging(context)
        }
    }
}
