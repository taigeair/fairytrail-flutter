plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "app.fairytrail.release"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (Java 8+ APIs on older Android).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.fairytrail.release"
        // Play Billing Library 8.3+ (Google Play requires 8+ by Aug 31, 2026).
        // Keep aligned with RevenueCat purchases-android `bc8` flavor.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        // RevenueCat purchases-android ships Play Billing 7/8 flavors.
        missingDimensionStrategy("billingclient", "bc8")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Keep WorkManager/Room reflective ctors (google_mobile_ads → work-runtime).
            proguardFiles("proguard-rules.pro")
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

configurations.configureEach {
    resolutionStrategy {
        // Google Play requires Billing Library 8+ for new uploads (deadline Aug 31, 2026).
        // Pin to RevenueCat's current Play Billing version (purchases-android 8.3.0).
        force("com.android.billingclient:billing:8.3.0")
        force("com.android.billingclient:billing-ktx:8.3.0")
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.android.billingclient:billing:8.3.0")
}
