# MEALIN — R8 / ProGuard rules
#
# build.gradle.kts sets isMinifyEnabled=true and isShrinkResources=true for the
# release build type, so every rule below is load-bearing. The app depends on
# several plugins that resolve classes and methods reflectively or through JNI;
# R8 cannot see those call sites and will happily strip them. The symptom is not
# a build error — it is a crash or silently broken feature that only appears in
# a minified release build, which is exactly the build that goes to Play.
#
# Namespaces below were read from the resolved plugin packages, not guessed:
#   razorpay_flutter-1.4.5              com.razorpay.razorpay_flutter
#   flutter_sound-9.30.0                xyz.canardoux.fluttersound
#   audioplayers_android-5.3.0          xyz.luan.audioplayers
#   printing-5.x                        net.nfet.flutter.printing
#   print_bluetooth_thermal-1.x         app.web.groons.print_bluetooth_thermal
#   flutter_local_notifications-18.0.1  com.dexterous.flutterlocalnotifications
#   firebase_messaging-16.4.3           io.flutter.plugins.firebase.messaging
#   geolocator / permission_handler / local_auth / sqflite / jni also ship
#   Kotlin/Java that is reached only via reflection or the JNI bridge.

# ---------------------------------------------------------------- Flutter core
# The generated plugin registrant is built by the Flutter Gradle plugin at build
# time and references plugin classes only by name.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.utility.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# FlutterActivity / FlutterFragmentActivity are instantiated by the system.
-keep class io.flutter.embedding.android.FlutterActivity { *; }
-keep class io.flutter.embedding.android.FlutterFragmentActivity { *; }
-keep class io.flutter.embedding.android.FlutterView { *; }
-keep class androidx.fragment.app.** { *; }

# Dart entrypoints are looked up reflectively from the native side.
-keep class com.example.housefoods.** { *; }
-keep class com.mealin.** { *; }
-keep class app.mealin.** { *; }

# ------------------------------------------------------------------ Razorpay
# Payment is the highest-risk surface in the app: a stripped callback model or
# payment-result activity fails at checkout with no build-time signal.
-keep class com.razorpay.** { *; }
-keep interface com.razorpay.** { *; }
-keep enum com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keepclassmembers class * implements com.razorpay.** { *; }

# ------------------------------------------- Audio: MEAL AI voice input/output
-keep class xyz.canardoux.fluttersound.** { *; }
-dontwarn xyz.canardoux.fluttersound.**
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**
-keep class xyz.luan.maestro.** { *; }
-dontwarn xyz.luan.maestro.**

# flutter_sound talks to Android's AudioRecord/AudioTrack and MediaRecorder
# through platform channels with classes resolved at runtime.
-keepclassmembers class xyz.canardoux.fluttersound.** {
    native <methods>;
}
-keep class xyz.canardoux.fluttersound.plugin.** { *; }

# ------------------------------------------------ Printing / PDF (bill, share)
# The resto app prints bills via USB thermal OTG and PDF/pos system print.
-keep class net.nfet.flutter.printing.** { *; }
-dontwarn net.nfet.flutter.printing.**
-keep class app.web.groons.print_bluetooth_thermal.** { *; }
-dontwarn app.web.groons.print_bluetooth_thermal.**
# Bluetooth thermal printers are loaded as a runtime ESC/POS implementation.
-keep class com.epicpos.printer.** { *; }
-dontwarn com.epicpos.printer.**
-keep class com.kongzhe.** { *; }
-dontwarn com.kongzhe.**
-keep class com.woopos.wooposprinter.** { *; }
-dontwarn com.woopos.wooposprinter.**

# ------------------------------------------------------- Firebase / messaging
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class io.flutter.plugins.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Firebase deserialises payloads with reflection; without these, push payloads
# silently arrive empty.
-keep class com.google.firebase.**$* { *; }
-keepattributes Signature
-keepattributes *Annotation*

# -------------------------------------------------------- Local notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**
# Scheduled-notification receivers are declared in the plugin's own manifest and
# instantiated by name at alarm time.
-keep class * extends android.content.BroadcastReceiver { *; }

# ----------------------------------------------- Device / permission / geo
# These use @RequiresPermission checks and reflection against Play Services.
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**
-keep class com.google.android.gms.location.** { *; }
-dontwarn com.google.android.gms.location.**

# JNI bridge (jni_flutter) — used by geolocator_android for platform structs.
-keep class dev.flutter.jni.** { *; }
-dontwarn dev.flutter.jni.**
-keep class * implements dev.flutter.jni.** { *; }

# ------------------------------------------------------------- Data / storage
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**
-keep class it.unimi.dsi.fastutil.** { *; }
-dontwarn it.unimi.dsi.fastutil.**

# ------------------------------------------------------------------ WebView
# AI chat renders streamed markdown; the WebView bridge resolves JS handlers by
# name and an obfuscated handler name breaks streaming silently.
-keep class android.webkit.** { *; }
-dontwarn android.webkit.**
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ------------------------------------------------------------- Kotlin metadata
# Kotlin coroutines and default-argument bridges rely on metadata that R8 strips
# unless explicitly retained.
-keepattributes RuntimeVisibleAnnotations,AnnotationDefault
-keepclassmembers class kotlin.Metadata { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**
-dontwarn org.jetbrains.annotations.**

# --------------------------------------------------------------- Generic safety
# Play Core (deferred components / split installs).
#
# io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager
# references com.google.android.play.core.* unconditionally, but the app does
# not depend on Play Core — deferred components are a Flutter framework
# capability this app never calls. Without these -dontwarn lines R8 fails the
# build outright with "Missing class com.google.android.play.core.splitinstall.*",
# which is what happened on the first minified release attempt.
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.assetpacks.**

# Never let a missing rule become a minified-only production crash.
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn sun.misc.**
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**