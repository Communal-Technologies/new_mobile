import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Reads google-services.json and injects FCM/Firebase project metadata at build time.
    id("com.google.gms.google-services")
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.fromTarget("11"))
    }
}

// Read MAPS_API_KEY from android/local.properties (gitignored). Falls back to the
// MAPS_API_KEY environment variable so CI can inject it without a properties file.
// If neither is set the placeholder resolves to an empty string and the Maps SDK
// will fail loudly at first map render — which is what we want, never a hardcoded key.
val mapsApiKey: String = run {
    val props = Properties()
    val localProps = rootProject.file("local.properties")
    if (localProps.exists()) {
        localProps.inputStream().use { props.load(it) }
    }
    props.getProperty("MAPS_API_KEY") ?: System.getenv("MAPS_API_KEY") ?: ""
}

// Read release signing config from android/key.properties (gitignored).
// CI generates this file from the ANDROID_KEYSTORE_* environment secrets; locally
// you create it by hand alongside upload.jks. When the file is absent we fall back
// to debug signing so `flutter run --release` keeps working without the upload key.
val keyPropsFile = rootProject.file("key.properties")
val keyProps = Properties().apply {
    if (keyPropsFile.exists()) {
        keyPropsFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "elite.codec.communal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Required by `flutter_local_notifications` (and any plugin that
        // pulls in java.time / Stream APIs while targeting older Android
        // runtimes). Without this AGP fails with
        // "requires core library desugaring to be enabled" on
        // assembleDebug. See
        // https://developer.android.com/studio/write/java8-support.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "elite.codec.communal"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        create("release") {
            if (keyPropsFile.exists()) {
                storeFile = keyProps.getProperty("storeFile")?.let { rootProject.file(it) }
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Audit M13: be explicit rather than relying on the build-variant
            // default. Release artifacts must never be debuggable — JDWP
            // exposure on a production APK lets anyone with adb attach a
            // debugger and inspect runtime state.
            isDebuggable = false

            // Use the release signing config when key.properties is present
            // (CI, or a local dev who set it up); otherwise fall back to debug
            // so `flutter run --release` keeps working without the upload key.
            signingConfig = if (keyPropsFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Audit M38: androidx.biometric brings BiometricPrompt + BiometricManager
// for the platform channel that backs `lib/data/datasources/...biometric*`.
// Pinning to a specific 1.2.x build avoids surprises with the alpha-only
// auth-types API the channel uses.
dependencies {
    implementation("androidx.biometric:biometric:1.2.0-alpha05")
    // Provides backports of java.time / Stream APIs at build time so
    // `isCoreLibraryDesugaringEnabled = true` above can resolve them on
    // older Android runtimes. Required by `flutter_local_notifications`.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
