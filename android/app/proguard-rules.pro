# Flutter Wrapper Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn com.google.android.play.core.**

# audio_service rules
-keep class com.ryanheise.audioservice.** { *; }
-keep class androidx.media.** { *; }
-keep class androidx.core.app.NotificationCompat** { *; }

# just_audio & ExoPlayer / Media3 rules
-keep class com.ryanheise.just_audio.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# on_audio_query rules
-keep class com.lucasjosino.onaudioquery.** { *; }
-keep class com.lucasjosino.onaudioquery.observers.** { *; }
-keep class com.lucasjosino.onaudioquery.queries.** { *; }
-keep class com.lucasjosino.onaudioquery.utils.** { *; }
-dontwarn com.lucasjosino.onaudioquery.**

# Flowy Application Native Classes
-keep class com.example.flowy.** { *; }

# General Serialization & Annotation Attributes
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
