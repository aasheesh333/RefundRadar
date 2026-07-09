# Refund Radar — ProGuard / R8 rules
#
# Flutter ships its own consumer rules; most plugins do too. Add only what's
# missing for our Firebase + RevenueCat + OneSignal + WorkManager setup.

# --------- Flutter (built-in rule via plugin) ----------
# Already covered by Flutter Gradle Plugin.

# --------- Firebase ----------
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# --------- RevenueCat (purchases_flutter) ----------
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# --------- OneSignal (onesignal_flutter) ----------
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**
-keep class com.onesignal.android_sdk.** { *; }

# --------- WorkManager / WorkDatabase ----------
# Fixes release-only crash:
#   java.lang.RuntimeException: Failed to create an instance of class
#   androidx.work.impl.WorkDatabase.canonicalName
# WorkManager uses Room's reflection-based table-init at app startup via
# androidx.startup.InitializationProvider. R8 must keep all of:
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase$* { *; }
-dontwarn androidx.work.**

# --------- Room (used by WorkManager + OneSignal) ----------
-keep class androidx.room.** { *; }
-keep class androidx.room.RoomDatabase { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Entity class * { *; }
-keepclassmembers class * { @androidx.room.* <methods>; }
-keepclassmembers class * { @androidx.room.* <fields>; }
-dontwarn androidx.room.**

# --------- androidx.startup (used by WorkManager + plugins) ----------
# InitializationProvider reflectively instantiates Initializer implementations
# found in the merged manifest — must keep them.
-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { *; }
-keepclassmembers class * implements androidx.startup.Initializer {
    public <init>();
}
-dontwarn androidx.startup.**

# --------- Lifecycle / ViewModel (used by R8 reflection) ----------
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.lifecycle.**

# --------- Kotlin / Flutter reflection ----------
-keep class kotlin.Metadata { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeInvisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations
-keepattributes RuntimeInvisibleParameterAnnotations
-keepattributes RuntimeVisibleTypeAnnotations
-keepattributes RuntimeInvisibleTypeAnnotations
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# --------- Firestore / Squflite (offline persistence B8) ----------
-keep class com.google.firebase.firestore.** { *; }
-dontwarn com.google.firebase.firestore.**

# --------- Preserve enum values for serialization (dispute status, type) ----------
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
