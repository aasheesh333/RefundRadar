# Refund Radar — ProGuard / R8 rules
#
# Flutter ships its own consumer rules; most plugins do too. Add only what's
# missing for our Firebase + RevenueCat setup.

# --------- Flutter (built-in rule via plugin) ----------
# Already covered by Flutter Gradle Plugin.

# --------- Firebase ----------
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# --------- RevenueCat (purchases_flutter) ----------
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

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

# --------- Preserve enum values for serialization (dispute status, type) ----------
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
