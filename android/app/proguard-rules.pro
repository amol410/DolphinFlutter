# DolphinCoder LMS ProGuard & R8 Configuration Rules
# Designed to enable dead-code elimination while guaranteeing 100% preservation of:
# 1. Native Speech Recognition & reflection hooks
# 2. Bluetooth SCO voice routing & AudioManager listeners
# 3. Flutter embedding, MethodChannels, and audio plugins

# -------------------------------------------------------------
# 1. Flutter Core Framework & Embedding
# -------------------------------------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }

# -------------------------------------------------------------
# 2. DolphinCoder Native Android Activity & Lifecycle Bridge
# -------------------------------------------------------------
-keep class com.dolphincoder.lms.** { *; }
-keepclassmembers class com.dolphincoder.lms.** { *; }

# -------------------------------------------------------------
# 3. Speech Recognition Engine & Reflection Injection (CRITICAL)
# MainActivity.kt uses Class.forName("com.csdcorp.speech_to_text.SpeechToTextPlugin")
# and accesses the private "speechRecognizer" field.
# -------------------------------------------------------------
-keep class com.csdcorp.speech_to_text.** { *; }
-keepclassmembers class com.csdcorp.speech_to_text.SpeechToTextPlugin {
    private android.speech.SpeechRecognizer speechRecognizer;
    <fields>;
    <methods>;
}
-keep class android.speech.** { *; }
-keepclassmembers class android.speech.** { *; }

# -------------------------------------------------------------
# 4. Audio Engine, Bluetooth SCO & Hardware Routing
# MainActivity.kt registers becomingNoisyReceiver, audioFocusChangeListener,
# and controls Bluetooth SCO voice routing via AudioManager.
# -------------------------------------------------------------
-keep class android.media.** { *; }
-keepclassmembers class android.media.** { *; }
-keep class com.tundralabs.fluttertts.** { *; }
-keepclassmembers class com.tundralabs.fluttertts.** { *; }
-keep class xyz.luan.audioplayers.** { *; }
-keepclassmembers class xyz.luan.audioplayers.** { *; }

# -------------------------------------------------------------
# 5. SharedPreferences, Storage, Path Provider & Network
# -------------------------------------------------------------
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# -------------------------------------------------------------
# 6. Google Mobile Ads (Safely prune unused, keep required entrypoints)
# -------------------------------------------------------------
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.mediation.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.core.**

# -------------------------------------------------------------
# 7. General Optimization & Reflection Preservation
# -------------------------------------------------------------
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-dontwarn android.speech.**
-dontwarn android.media.**

# -------------------------------------------------------------
# 8. AndroidX WorkManager & Room Database Reflection
# -------------------------------------------------------------
-keep class androidx.work.** { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-dontwarn androidx.work.**

