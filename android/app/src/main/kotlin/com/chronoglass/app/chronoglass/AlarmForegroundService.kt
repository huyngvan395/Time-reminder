package com.chronoglass.app.chronoglass

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.chronoglass.app.chronoglass.NativeAlarmScheduler.putExtrasFromPayload
import java.io.File

/**
 * Native ForegroundService that:
 * 1. Posts a PRIORITY_MAX, CATEGORY_ALARM notification with FullScreenIntent over the lockscreen
 * 2. Loops the alarm ringtone natively via MediaPlayer with AudioAttributes.USAGE_ALARM (rings over silent mode)
 *    and gradual volume ramp-up
 * 3. Vibrates continuously
 * 4. Launches MainActivity over the lockscreen
 */
class AlarmForegroundService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private val rampHandler = Handler(Looper.getMainLooper())
    private var currentVolume = 0.20f

    private val volumeRampRunnable = object : Runnable {
        override fun run() {
            if (!isRinging || mediaPlayer == null) return
            currentVolume = (currentVolume + 0.08f).coerceAtMost(1.0f)
            try {
                mediaPlayer?.setVolume(currentVolume, currentVolume)
            } catch (_: Exception) {
            }
            if (currentVolume < 1.0f) {
                rampHandler.postDelayed(this, 850L)
            }
        }
    }

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

        Log.i(TAG, "AlarmForegroundService starting for id=${payload.id}, title=${payload.title}")
        isRinging = true
        AlarmStorageHelper.saveRingingAlarm(this, payload)
        AlarmStorageHelper.removeAlarm(this, payload.id)

        createAlarmNotificationChannel()
        val notification = buildAlarmNotification(payload)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground fallback: ${e.message}")
            try {
                startForeground(NOTIFICATION_ID, notification)
            } catch (_: Exception) {
            }
        }

        startNativeAudio(payload)
        startNativeVibration()
        launchFullScreenActivity(payload)
        MainActivity.deliverAlarmToFlutter(payload)

        return START_STICKY
    }

    private fun createAlarmNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ChronoGlass Alarm Clock",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Full-screen lockscreen alarm clock notifications"
                // Sound disabled on channel because MediaPlayer plays looping USAGE_ALARM audio
                setSound(null, null)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 600, 400, 800, 500)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildAlarmNotification(payload: NativeAlarmPayload): Notification {
        val reqCode = NativeAlarmScheduler.requestCodeFor(payload.id)

        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtrasFromPayload(payload)
            putExtra(AlarmReceiver.EXTRA_IS_ALARM_LAUNCH, true)
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            reqCode,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val dismissIntent = Intent(this, AlarmActionReceiver::class.java).apply {
            action = AlarmActionReceiver.ACTION_DISMISS
            putExtrasFromPayload(payload)
        }
        val dismissPending = PendingIntent.getBroadcast(
            this,
            reqCode xor 0x1111,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val snoozeIntent = Intent(this, AlarmActionReceiver::class.java).apply {
            action = AlarmActionReceiver.ACTION_SNOOZE
            putExtrasFromPayload(payload)
        }
        val snoozePending = PendingIntent.getBroadcast(
            this,
            reqCode xor 0x2222,
            snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val bodyText = if (payload.body.isNotBlank()) payload.body else "Báo thức đang reo • Chạm để mở"
        val snoozeLabel = "Báo lại ${if (payload.snoozeMinutes > 0) payload.snoozeMinutes else 5} phút"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(payload.title)
            .setContentText(bodyText)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(fullScreenPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .addAction(0, snoozeLabel, snoozePending)
            .addAction(0, "Tắt báo thức", dismissPending)
            .build()
    }

    private fun startNativeAudio(payload: NativeAlarmPayload) {
        stopNativeAudio()
        val player = MediaPlayer()
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        player.setAudioAttributes(attrs)

        var configured = false
        try {
            if (payload.isAsset) {
                val normalized = if (payload.ringtonePath.startsWith("assets/")) {
                    "flutter_assets/${payload.ringtonePath}"
                } else {
                    "flutter_assets/assets/${payload.ringtonePath}"
                }
                assets.openFd(normalized).use { afd ->
                    player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    configured = true
                }
            } else if (payload.ringtonePath.isNotEmpty() && File(payload.ringtonePath).exists()) {
                player.setDataSource(payload.ringtonePath)
                configured = true
            }
        } catch (e: Exception) {
            Log.w(TAG, "Primary ringtone load warning (${payload.ringtonePath}): ${e.message}")
        }

        if (!configured) {
            try {
                assets.openFd("flutter_assets/assets/sounds/morning_marimba.wav").use { afd ->
                    player.reset()
                    player.setAudioAttributes(attrs)
                    player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    configured = true
                }
            } catch (_: Exception) {
            }
        }

        if (!configured) {
            try {
                val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                if (defaultUri != null) {
                    player.reset()
                    player.setAudioAttributes(attrs)
                    player.setDataSource(applicationContext, defaultUri)
                    configured = true
                }
            } catch (e: Exception) {
                Log.e(TAG, "Fallback ringtone failed: ${e.message}")
            }
        }

        if (configured) {
            try {
                player.isLooping = true
                currentVolume = 0.22f
                player.setVolume(currentVolume, currentVolume)
                player.prepare()
                player.start()
                mediaPlayer = player
                rampHandler.postDelayed(volumeRampRunnable, 850L)
            } catch (e: Exception) {
                Log.e(TAG, "MediaPlayer start failed: ${e.message}")
            }
        }
    }

    private fun stopNativeAudio() {
        rampHandler.removeCallbacks(volumeRampRunnable)
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {
        }
        try {
            mediaPlayer?.release()
        } catch (_: Exception) {
        }
        mediaPlayer = null
    }

    private fun startNativeVibration() {
        stopNativeVibration()
        try {
            val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (!vib.hasVibrator()) return
            val pattern = longArrayOf(0, 600, 400, 800, 500)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val attrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()
                @Suppress("DEPRECATION")
                vib.vibrate(VibrationEffect.createWaveform(pattern, 0), attrs)
            } else {
                @Suppress("DEPRECATION")
                vib.vibrate(pattern, 0)
            }
            vibrator = vib
        } catch (e: Exception) {
            Log.w(TAG, "Vibration start warning: ${e.message}")
        }
    }

    private fun stopNativeVibration() {
        try {
            vibrator?.cancel()
        } catch (_: Exception) {
        }
        vibrator = null
    }

    private fun launchFullScreenActivity(payload: NativeAlarmPayload) {
        try {
            val activityIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
                putExtrasFromPayload(payload)
                putExtra(AlarmReceiver.EXTRA_IS_ALARM_LAUNCH, true)
            }
            startActivity(activityIntent)
        } catch (e: Exception) {
            Log.w(TAG, "Direct startActivity deferred to FullScreenIntent: ${e.message}")
        }
    }

    override fun onDestroy() {
        isRinging = false
        stopNativeAudio()
        stopNativeVibration()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "ChronoGlassFgService"
        const val CHANNEL_ID = "chronoglass_alarm_clock_channel"
        const val NOTIFICATION_ID = 994411

        @Volatile
        var isRinging: Boolean = false

        fun stopAlarm(context: Context) {
            isRinging = false
            AlarmStorageHelper.clearRingingAlarm(context)
            try {
                val serviceIntent = Intent(context, AlarmForegroundService::class.java)
                context.stopService(serviceIntent)
            } catch (_: Exception) {
            }
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancel(NOTIFICATION_ID)
            } catch (_: Exception) {
            }
        }
    }
}
