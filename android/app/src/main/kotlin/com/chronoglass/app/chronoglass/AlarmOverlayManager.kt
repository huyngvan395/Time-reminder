package com.chronoglass.app.chronoglass

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import com.chronoglass.app.chronoglass.NativeAlarmScheduler.putExtrasFromPayload
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Renders the sleek dark floating alarm pill banner at the top of the screen over ANY app
 * or Home Screen (using TYPE_APPLICATION_OVERLAY when granted), with bold HH:mm time,
 * reminder title, circular Snooze (Zz) button, and circular Stop (■) button.
 */
object AlarmOverlayManager {
    private const val TAG = "ChronoGlassOverlay"
    private val mainHandler = Handler(Looper.getMainLooper())
    private var overlayView: View? = null

    fun canDrawOverlays(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    fun show(context: Context, payload: NativeAlarmPayload) {
        if (!canDrawOverlays(context)) return
        val appCtx = context.applicationContext

        mainHandler.post {
            try {
                dismissInternal(appCtx)

                val wm = appCtx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val density = appCtx.resources.displayMetrics.density
                val marginH = (12 * density).toInt()
                val topOffset = getStatusBarHeight(appCtx) + (6 * density).toInt()

                val wrapper = FrameLayout(appCtx).apply {
                    setPadding(marginH, 0, marginH, 0)
                }

                val pill = LayoutInflater.from(appCtx).inflate(
                    R.layout.overlay_alarm_pill,
                    wrapper,
                    false
                )

                val timeStr = SimpleDateFormat("HH:mm", Locale.getDefault())
                    .format(Date(System.currentTimeMillis()))
                val displayTitle = payload.title.trim().ifEmpty { "Nhắc nhở" }
                pill.findViewById<TextView>(R.id.alarm_pill_time)?.text = timeStr
                pill.findViewById<TextView>(R.id.alarm_pill_subtitle)?.text = displayTitle

                // Tap pill body -> open FullScreenAlarmScreen in ChronoGlass
                pill.findViewById<View>(R.id.alarm_pill_root)?.setOnClickListener {
                    dismissInternal(appCtx)
                    try {
                        val openIntent = Intent(appCtx, MainActivity::class.java).apply {
                            addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK or
                                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                            )
                            putExtrasFromPayload(payload)
                            putExtra(AlarmReceiver.EXTRA_IS_ALARM_LAUNCH, true)
                        }
                        appCtx.startActivity(openIntent)
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to open MainActivity from pill: ${e.message}")
                    }
                }

                // Tap circular Snooze (Zz) button
                pill.findViewById<View>(R.id.alarm_pill_snooze)?.setOnClickListener {
                    AlarmActionReceiver.handleSnooze(appCtx, payload)
                }

                // Tap circular Stop (■) button
                pill.findViewById<View>(R.id.alarm_pill_stop)?.setOnClickListener {
                    AlarmActionReceiver.handleDismiss(appCtx, payload)
                }

                wrapper.addView(pill)

                val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                }

                @Suppress("DEPRECATION")
                val flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    layoutType,
                    flags,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                    y = topOffset
                }

                // Subtle slide-down entrance animation
                pill.translationY = -120f
                pill.alpha = 0f
                wm.addView(wrapper, params)
                overlayView = wrapper
                pill.animate()
                    .translationY(0f)
                    .alpha(1f)
                    .setDuration(260L)
                    .start()

                Log.i(TAG, "Displayed floating alarm pill overlay for ${payload.id}")
            } catch (e: Exception) {
                Log.w(TAG, "Unable to attach overlay pill: ${e.message}")
            }
        }
    }

    fun dismiss(context: Context) {
        val appCtx = context.applicationContext
        mainHandler.post { dismissInternal(appCtx) }
    }

    private fun dismissInternal(appCtx: Context) {
        val view = overlayView ?: return
        overlayView = null
        try {
            val wm = appCtx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            wm.removeView(view)
        } catch (_: Exception) {
        }
    }

    private fun getStatusBarHeight(context: Context): Int {
        val resId = context.resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resId > 0) context.resources.getDimensionPixelSize(resId) else 72
    }
}
