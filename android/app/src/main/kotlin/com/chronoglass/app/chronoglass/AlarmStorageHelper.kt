package com.chronoglass.app.chronoglass

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import org.json.JSONObject

data class NativeAlarmPayload(
    val id: String,
    val triggerAtMillis: Long,
    val title: String,
    val body: String,
    val ringtonePath: String,
    val isAsset: Boolean,
    val dismissChallenge: String,
    val snoozeMinutes: Int = 5
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("triggerAtMillis", triggerAtMillis)
        put("title", title)
        put("body", body)
        put("ringtonePath", ringtonePath)
        put("isAsset", isAsset)
        put("dismissChallenge", dismissChallenge)
        put("snoozeMinutes", snoozeMinutes)
    }

    fun toMap(): Map<String, Any> = mapOf(
        "id" to id,
        "triggerAtMillis" to triggerAtMillis,
        "title" to title,
        "body" to body,
        "ringtonePath" to ringtonePath,
        "isAsset" to isAsset,
        "dismissChallenge" to dismissChallenge,
        "snoozeMinutes" to snoozeMinutes
    )

    companion object {
        fun fromJson(obj: JSONObject): NativeAlarmPayload = NativeAlarmPayload(
            id = obj.optString("id", ""),
            triggerAtMillis = obj.optLong("triggerAtMillis", 0L),
            title = obj.optString("title", "ChronoGlass Alarm"),
            body = obj.optString("body", ""),
            ringtonePath = obj.optString("ringtonePath", "assets/sounds/morning_marimba.wav"),
            isAsset = obj.optBoolean("isAsset", true),
            dismissChallenge = obj.optString("dismissChallenge", "slide"),
            snoozeMinutes = obj.optInt("snoozeMinutes", 5)
        )
    }
}

/**
 * Native persistence in SharedPreferences (Direct-Boot aware on API 24+)
 * so scheduled alarms survive app swipe-away and device reboot without needing Flutter to boot first.
 */
object AlarmStorageHelper {
    private const val PREFS_NAME = "chronoglass_native_alarms"
    private const val KEY_ACTIVE_RINGING = "__active_ringing_alarm__"

    private fun prefs(context: Context): SharedPreferences {
        val storageContext = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            context.createDeviceProtectedStorageContext()
        } else {
            context
        }
        return storageContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun saveAlarm(context: Context, payload: NativeAlarmPayload) {
        if (payload.id.isEmpty()) return
        prefs(context).edit().putString("alarm_${payload.id}", payload.toJson().toString()).apply()
    }

    fun removeAlarm(context: Context, id: String) {
        prefs(context).edit().remove("alarm_$id").apply()
    }

    fun getAlarm(context: Context, id: String): NativeAlarmPayload? {
        val raw = prefs(context).getString("alarm_$id", null) ?: return null
        return try {
            NativeAlarmPayload.fromJson(JSONObject(raw))
        } catch (_: Exception) {
            null
        }
    }

    fun getAllAlarms(context: Context): List<NativeAlarmPayload> {
        val result = mutableListOf<NativeAlarmPayload>()
        for ((key, value) in prefs(context).all) {
            if (key.startsWith("alarm_") && value is String) {
                try {
                    val item = NativeAlarmPayload.fromJson(JSONObject(value))
                    if (item.id.isNotEmpty()) {
                        result.add(item)
                    }
                } catch (_: Exception) {
                }
            }
        }
        return result
    }

    fun saveRingingAlarm(context: Context, payload: NativeAlarmPayload) {
        prefs(context).edit().putString(KEY_ACTIVE_RINGING, payload.toJson().toString()).apply()
    }

    fun clearRingingAlarm(context: Context) {
        prefs(context).edit().remove(KEY_ACTIVE_RINGING).apply()
    }

    fun getRingingAlarm(context: Context): NativeAlarmPayload? {
        val raw = prefs(context).getString(KEY_ACTIVE_RINGING, null) ?: return null
        return try {
            NativeAlarmPayload.fromJson(JSONObject(raw))
        } catch (_: Exception) {
            null
        }
    }
}
