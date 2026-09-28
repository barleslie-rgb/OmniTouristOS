# -------------------------------------------------------------
# FLUTTER & DART CORE RULES
# -------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# -------------------------------------------------------------
# GOOGLE PLAY CORE & DEFERRED COMPONENTS
# Suppresses missing Play Core classes when not using split APKs
# -------------------------------------------------------------
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# -------------------------------------------------------------
# WEBVIEW FLUTTER & JAVASCRIPT BRIDGES
# Prevents R8 from stripping JS interfaces, DOM storage, & WebChromeClient
# -------------------------------------------------------------
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keep class io.flutter.plugins.webviewflutter.** { *; }
-keep class android.webkit.** { *; }

# -------------------------------------------------------------
# GEOLOCATOR & LOCATION SERVICES
# Prevents obfuscation of GPS background callbacks & permissions
# -------------------------------------------------------------
-keep class com.baseflow.geolocator.** { *; }
-keep class com.google.android.gms.location.** { *; }
-dontwarn com.google.android.gms.**

# -------------------------------------------------------------
# HTTP, NETWORKING & OKHTTP / GSON
# -------------------------------------------------------------
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# -------------------------------------------------------------
# SUPABASE / SHARED PREFERENCES / SYSTEM PLUGINS
# -------------------------------------------------------------
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn io.flutter.plugins.**