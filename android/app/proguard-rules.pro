# ==============================================================================
# FloraX Universal Mobile - Release ProGuard / R8 Obfuscation & Keep Rules
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. FLUTTER ENGINE & CAMERA2 PLATFORM CHANNELS
# ------------------------------------------------------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-dontwarn io.flutter.**

# Camera2 and Image Streaming wrapper classes
-keep class io.flutter.plugins.camera.** { *; }
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Flutter Native JNI Bridge and Surface Renderers
-keepclasseswithmembers class * {
    native <methods>;
}
-keepclassmembers class * {
    native <methods>;
}

# ------------------------------------------------------------------------------
# 2. TENSORFLOW LITE & GOOGLE AI EDGE LITERT DELEGATES
# ------------------------------------------------------------------------------
-keep class org.tensorflow.lite.** { *; }
-keep interface org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

-keep class com.google.ai.edge.litert.** { *; }
-keep interface com.google.ai.edge.litert.** { *; }
-dontwarn com.google.ai.edge.litert.**

# TFLite C/C++ JNI Runtime
-keep class com.tflite.** { *; }
-keep class tflite_flutter.** { *; }
-dontwarn tflite_flutter.**

# Preserve annotations, inner classes, and generic signatures for TFLite tensors
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ------------------------------------------------------------------------------
# 3. FIREBASE SUITE & GOOGLE PLAY INTEGRITY
# ------------------------------------------------------------------------------
# Firebase Core & Cloud Services
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Firebase App Check & Play Integrity Provider
-keep class com.google.firebase.appcheck.** { *; }
-keep class com.google.android.play.core.integrity.** { *; }
-dontwarn com.google.android.play.core.integrity.**

# Google Play Services & Tasks API
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Cloud Firestore & gRPC Transport Serialization
-keep class io.grpc.** { *; }
-dontwarn io.grpc.**
-keep class com.google.firestore.** { *; }
-dontwarn com.google.firestore.**
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# Firebase Storage & Authentication
-keep class com.google.firebase.storage.** { *; }
-keep class com.google.firebase.auth.** { *; }

# Firebase Cloud Messaging
-keep class com.google.firebase.messaging.** { *; }

# ------------------------------------------------------------------------------
# 4. MULTIDEX & JAVA DESUGARING RUNTIME SUPPORT
# ------------------------------------------------------------------------------
-keep class androidx.multidex.** { *; }
-dontwarn java.lang.invoke.**
-dontwarn java.lang.SafeVarargs

# ------------------------------------------------------------------------------
# 5. SECURE STORAGE & NETWORKING (DIO / OKHTTP / COROUTINES)
# ------------------------------------------------------------------------------
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
-dontwarn kotlinx.coroutines.**
