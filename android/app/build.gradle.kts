plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Native Firebase plugins (B2 + B8).
    //   google-services      → registers the native Firebase app metadata
    //                           (App ID, API key) from google-services.json
    //   firebase.crashlytics → maps obfuscated stack traces back to sources
    //                           and uploads build symbols on assembleRelease.
    // Order matters: google-services MUST be applied LAST (per Firebase docs).
    id("com.google.firebase.crashlytics")
}

// google-services plugin must be applied at the very end of the file (after the
// android {} block) — see `apply(plugin = ...)` at file bottom.

android {
    namespace = "com.dhanuk.refundradar"
    ndkVersion = flutter.ndkVersion

    // Android 15+ 16 KB page-size support. Requires AGP ≥8.3 and
    // compileSdk ≥35. This keeps native libraries (libflutter.so,
    // libapp.so, Firebase/RC native libs) 16 KB aligned so the app
    // does not crash on 16 KB-page devices (Pixel 9, future devices).
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.dhanuk.refundradar"
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 16 KB native library packaging — keeps lib*.so files aligned to
    // 16 KB boundaries inside the APK/AAB zip. Required for Android 15
    // 16 KB-page devices.
    packagingOptions {
        jniLibs {
            useLegacyPackaging = false
        }
    }
    // ---------------------------------------------------------------------------
    // 1. Local: define these as env vars or in ~/.gradle/gradle.properties.
    // 2. CI: GitHub secrets — see .github/workflows/android.yml → release job.
    // Falls back to debug signing config when the keystore file isn't present
    // (i.e. local dev builds without a release key). This keeps
    // `flutter build apk --release` working on developer machines that don't
    // have a release keystore yet.
    // ---------------------------------------------------------------------------
    val keystorePath = file("keystore.jks")
    val keystorePassword = (System.getenv("KEYSTORE_PASSWORD") ?: "")
    val keyAliasValue = (System.getenv("KEY_ALIAS") ?: "")
    val keyPasswordValue = (System.getenv("KEY_PASSWORD") ?: "")
    val hasKeystore = keystorePath.exists() && keystorePassword.isNotEmpty() && keyAliasValue.isNotEmpty() && keyPasswordValue.isNotEmpty()

    if (hasKeystore) {
        signingConfigs {
            create("release") {
                storeFile = keystorePath
                storePassword = keystorePassword
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
            }
        }
    }

    buildTypes {
        release {
            if (hasKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Fallback: sign with debug keys (developer machines only).
                signingConfig = signingConfigs.getByName("debug")
            }
            // Strip native debug symbols and enable R8.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// google-services plugin MUST be applied LAST — per Firebase docs it
// requires the android {} block to already be evaluated so it can
// resolve the applicationId. Applying via `apply(plugin = ...)` (rather
// than adding it inside the `plugins {}` block above) lets us keep
// ordering correct.
apply(plugin = "com.google.gms.google-services")
