import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val envProps = Properties().apply {
    val envPropsFile = rootProject.file("../configs/env.props")
    if (envPropsFile.exists()) {
        envPropsFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "app.locafy"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }


    defaultConfig {
        // Must match a client in android/app/google-services.json (Firebase)
        applicationId = "com.magentoegyptpro.ajstore"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = envProps.getProperty("keyAlias", "ajstore")
            keyPassword = envProps.getProperty("keyPassword", "magentoegypt123456ajstore")
            storePassword = envProps.getProperty("storePassword", "magentoegypt123456ajstore")
            storeFile = rootProject.file("../configs/${envProps.getProperty("storeFile", "ajstore-keystore.jks")}")
        }
    }

    buildTypes {
//        release {
//            // TODO: Add your own signing config for the release build.
//            // Signing with the debug keys for now, so `flutter run --release` works.
//            signingConfig = signingConfigs.getByName("debug")
//        }
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4") // Use latest
    implementation("com.google.android.material:material:1.12.0")
}
