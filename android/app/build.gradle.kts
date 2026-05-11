import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val envProperties = Properties()
val envFile = project.rootProject.file(".env")
if (envFile.exists()) {
    FileInputStream(envFile).use { envProperties.load(it) }
}
val googleMapsApiKey: String = envProperties.getProperty("ANDROID_MAPS_KEY") ?: ""

android {
    compileSdk = 36
    ndkVersion = "28.2.13676358"
    namespace = "com.jh311.haul_alerts"

    defaultConfig {
        applicationId = "com.jh311.haul_alerts"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["ANDROID_MAPS_KEY"] = googleMapsApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = "21"
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-splashscreen:1.0.1")
}
