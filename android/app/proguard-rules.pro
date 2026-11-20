# ChronoGlass ProGuard / R8 Keep Rules

# Keep Flutter & app classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.chronoglass.app.chronoglass.** { *; }

# Keep flutter_local_notifications (Gson serialization & receivers)
-keep class com.dexterous.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep android_alarm_manager_plus services & receivers
-keep class dev.fluttercommunity.plus.androidalarmmanager.** { *; }

# Keep audioplayers, sqflite, vibration, wakelock_plus
-keep class xyz.luan.audioplayers.** { *; }
-keep class com.tekartik.sqflite.** { *; }
-keep class com.benjaminabel.vibration.** { *; }
-keep class dev.fluttercommunity.plus.wakelock.** { *; }

# Prevent stripping of native methods & BroadcastReceivers
-keepclassmembers class * extends android.content.BroadcastReceiver {
    public void onReceive(android.content.Context, android.content.Intent);
}
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn com.google.android.play.core.**
