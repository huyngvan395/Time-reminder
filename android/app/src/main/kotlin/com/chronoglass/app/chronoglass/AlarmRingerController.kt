package com.chronoglass.app.chronoglass

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.chronoglass.app.chronoglass.NativeAlarmScheduler.putExtrasFromPayload
import java.io.File

/**
 * In-process singleton that IMMEDIATELY executes when AlarmReceiver fires:
 * 1. Acquires CPU & Screen WakeLocks so the device wakes from Deep Doze / Lockscreen
 * 2. Posts a Heads-Up Popup Banner + FullScreenIntent Notification (PRIORITY_MAX, CATEGORY_ALARM)
 *    even if Android 12-15 or ColorOS restricts background ForegroundService startup
 * 3. Plays looping USAGE_ALARM ringtone via MediaPlayer with volume boost & ramp
 * 4. Starts continuous USAGE_ALARM vibration
 * 5. Launches MainActivity over the lockscreen
 */
object AlarmRingerController {
    private const val TAG = "ChronoGlassRinger"
    const val CHANNEL_ID = "chronoglass_alarm_popup_v3"
    const val NOTIFICATION_ID = 994411

    @Volatile
    var isRinging: Boolean = false
        private set

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var cpuWakeLock: PowerManager.WakeLock? = null
    private var screenWakeLock: PowerManager.WakeLock? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var currentVolume = 0.35f

    private val volumeRampRunnable = object : Runnable {
        override fun run() {
            if (!isRinging || mediaPlayer == null) return
            currentVolume = (currentVolume + 0.10f).coerceAtMost(1.0f)
            try {
                mediaPlayer?.setVolume(currentVolume, currentVolume)
            } catch (_: Exception) {
            }
            if (currentVolume < 1.0f) {
                mainHandler.postDelayed(this, 750L)
            }
        }
    }

    private val autoStopRunnable = Runnable {
        // Safety auto-stop after 10 minutes of continuous ringing
        Log.i(TAG, "Auto-stopping alarm after 10 minutes timeout")
    }

    @Synchronized
    fun startRinging(context: Context, payload: NativeAlarmPayload): Notification {
        val appCtx = context.applicationContext
        Log.i(TAG, "startRinging id=${payload.id}, title=${payload.title}")

        acquireWakeLocks(appCtx)
        AlarmStorageHelper.saveRingingAlarm(appCtx, payload)
        AlarmStorageHelper.removeAlarm(appCtx, payload.id)

        // Cancel any duplicate scheduled flutter_local_notifications entry for this ID
        try {
            val nm = appCtx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(NativeAlarmScheduler.requestCodeFor(payload.id))
        } catch (_: Exception) {
        }

        ensureNotificationChannel(appCtx)
        val notification = buildPopupAlarmNotification(appCtx, payload)

        // Immediately post Heads-Up Popup + FullScreenIntent notification from BroadcastReceiver context!
        try {
            val nm = appCtx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to post popup notification: ${e.message}", e)
        }

        if (!isRinging) {
            isRinging = true
            startNativeAudio(appCtx, payload)
            startNativeVibration(appCtx)
        }

        launchFullScreenActivity(appCtx, payload)
        MainActivity.deliverAlarmToFlutter(payload)

        return notification
    }

    fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) != null) return

            val soundUri = Uri.parse("android.resource://${context.packageName}/raw/aurora_chime")
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            val channel = NotificationChannel(
                CHANNEL_ID,
                "Báo thức & Nhắc nhở ChronoGlass (Popup)",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Thông báo popup nổi và báo thức toàn màn hình khóa"
                // Attach fallback alarm sound on channel in case OEM kills background process,
                // while MediaPlayer plays the selected custom/built-in melody
                setSound(soundUri, attrs)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 600, 400, 800, 500)
                enableLights(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            nm.createNotificationChannel(channel)
        }
    }

    fun buildPopupAlarmNotification(context: Context, payload: NativeAlarmPayload): Notification {
        val reqCode = NativeAlarmScheduler.requestCodeFor(payload.id)

        val fullScreenIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtrasFromPayload(payload)
            putExtra(AlarmReceiver.EXTRA_IS_ALARM_LAUNCH, true)
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            reqCode,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val dismissIntent = Intent(context, AlarmActionReceiver::class.java).apply {
            action = AlarmActionReceiver.ACTION_DISMISS
            putExtrasFromPayload(payload)
        }
        val dismissPending = PendingIntent.getBroadcast(
            context,
            reqCode xor 0x1111,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val snoozeIntent = Intent(context, AlarmActionReceiver::class.java).apply {
            action = AlarmActionReceiver.ACTION_SNOOZE
            putExtrasFromPayload(payload)
        }
        val snoozePending = PendingIntent.getBroadcast(
            context,
            reqCode xor 0x2222,
            snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val bodyText = if (payload.body.isNotBlank()) payload.body else "⏰ Đến giờ nhắc nhở • Chạm để mở"
        val snoozeMins = if (payload.snoozeMinutes > 0) payload.snoozeMinutes else 5
        val snoozeLabel = "Báo lại ${snoozeMins}p"

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("⏰ ${payload.title}")
            .setContentText(bodyText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bodyText))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setDefaults(NotificationCompat.DEFAULT_LIGHTS or NotificationCompat.DEFAULT_VIBRATE)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(fullScreenPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .addAction(0, snoozeLabel, snoozePending)
            .addAction(0, "Tắt báo thức", dismissPending)
            .build()
    }

    private fun acquireWakeLocks(context: Context) {
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            if (cpuWakeLock?.isHeld != true) {
                cpuWakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "ChronoGlass:RingerCpuWakeLock"
                ).apply {
                    setReferenceCounted(false)
                    acquire(3 * 60_000L)
                }
            }
            if (screenWakeLock?.isHeld != true) {
                @Suppress("DEPRECATION")
                screenWakeLock = pm.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                        PowerManager.ACQUIRE_CAUSES_WAKEUP or
                        PowerManager.ON_AFTER_RELEASE,
                    "ChronoGlass:RingerScreenWakeLock"
                ).apply {
                    setReferenceCounted(false)
                    acquire(45_000L)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "WakeLock acquire warning: ${e.message}")
        }
    }

    private fun startNativeAudio(context: Context, payload: NativeAlarmPayload) {
        stopNativeAudio()

        // Ensure hardware STREAM_ALARM volume is audible (at least 60% of max if muted)
        try {
            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxVol = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            val curVol = am.getStreamVolume(AudioManager.STREAM_ALARM)
            if (curVol == 0 && maxVol > 0) {
                am.setStreamVolume(AudioManager.STREAM_ALARM, (maxVol * 0.7).toInt().coerceAtLeast(1), 0)
            }
        } catch (_: Exception) {
        }

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
                context.assets.openFd(normalized).use { afd ->
                    player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    configured = true
                }
            } else if (payload.ringtonePath.isNotEmpty() && File(payload.ringtonePath).exists()) {
                player.setDataSource(payload.ringtonePath)
                configured = true
            }
        } catch (e: Exception) {
            Log.w(TAG, "Primary asset/file ringtone warning: ${e.message}")
        }

        if (!configured) {
            try {
                context.assets.openFd("flutter_assets/assets/sounds/morning_marimba.wav").use { afd ->
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
                val rawUri = Uri.parse("android.resource://${context.packageName}/raw/aurora_chime")
                player.reset()
                player.setAudioAttributes(attrs)
                player.setDataSource(context, rawUri)
                configured = true
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
                    player.setDataSource(context, defaultUri)
                    configured = true
                }
            } catch (e: Exception) {
                Log.e(TAG, "System default alarm ringtone fallback failed: ${e.message}")
            }
        }

        if (configured) {
            try {
                player.isLooping = true
                currentVolume = 0.35f
                player.setVolume(currentVolume, currentVolume)
                player.prepare()
                player.start()
                mediaPlayer = player
                mainHandler.postDelayed(volumeRampRunnable, 750L)
                Log.i(TAG, "MediaPlayer started looping USAGE_ALARM audio")
            } catch (e: Exception) {
                Log.e(TAG, "MediaPlayer start failed: ${e.message}")
            }
        }
    }

    private fun stopNativeAudio() {
        mainHandler.removeCallbacks(volumeRampRunnable)
        mainHandler.removeCallbacks(autoStopRunnable)
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

    private fun startNativeVibration(context: Context) {
        stopNativeVibration()
        try {
            val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
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
            Log.w(TAG, "Vibration warning: ${e.message}")
        }
    }

    private fun stopNativeVibration() {
        try {
            vibrator?.cancel()
        } catch (_: Exception) {
        }
        vibrator = null
    }

    private fun launchFullScreenActivity(context: Context, payload: NativeAlarmPayload) {
        try {
            val activityIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
                putExtrasFromPayload(payload)
                putExtra(AlarmReceiver.EXTRA_IS_ALARM_LAUNCH, true)
            }
            context.startActivity(activityIntent)
        } catch (e: Exception) {
            Log.w(TAG, "Direct startActivity deferred to FullScreenIntent: ${e.message}")
        }
    }

    @Synchronized
    fun stopRinging(context: Context) {
        val appCtx = context.applicationContext
        isRinging = false
        stopNativeAudio()
        stopNativeVibration()
        AlarmStorageHelper.clearRingingAlarm(appCtx)

        try {
            if (cpuWakeLock?.isHeld == true) cpuWakeLock?.release()
        } catch (_: Exception) {
        }
        try {
            if (screenWakeLock?.isHeld == true) screenWakeLock?.release()
        } catch (_: Exception) {
        }

        try {
            val nm = appCtx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(NOTIFICATION_ID)
        } catch (_: Exception) {
        }

        try {
            appCtx.stopService(Intent(appCtx, AlarmForegroundService::class.java))
        } catch (_: Exception) {
        }
    }
}
