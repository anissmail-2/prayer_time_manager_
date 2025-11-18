# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Firebase Auth
-keepattributes Signature
-keepattributes *Annotation*

# Firebase Firestore
-keep class com.google.firebase.firestore.** { *; }
-dontwarn okio.**
-dontwarn retrofit2.Call
-dontnote retrofit2.Platform$IOS$MainThreadExecutor
-keep class * extends com.google.firebase.firestore.DocumentSnapshot { *; }
-keep class * extends com.google.firebase.firestore.QuerySnapshot { *; }

# Google Sign In
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.api.** { *; }

# Gson (used by Firebase)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.examples.android.model.** { <fields>; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep custom models
-keep class com.example.prayer_time_manager.models.** { *; }
-keep class com.awkati.taskflow.models.** { *; }

# Google Play Core - Fix for missing classes
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-keep class com.google.android.play.core.** { *; }

# Additional Flutter deferred components rules
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }