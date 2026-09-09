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
        // A new Play listing, deliberately separate from the live app.locafy
        // one. Needs its own signing key and its own Firebase client.
        applicationId = "app.locafy.customer"
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
            // Prefer the environment, so the upload key and its passwords never have
            // to live in the repo. configs/env.props stays as the local fallback, but
            // it still points at the old ajstore key: Play binds an app to whichever
            // key first signs it, so a fallback build must never be uploaded.
            val envStore = System.getenv("ANDROID_KEYSTORE_PATH")
            if (envStore != null) {
                storeFile = File(envStore)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            } else {
                project.logger.warn(
                    "WARNING: no ANDROID_KEYSTORE_PATH set - signing with the bundled " +
                    "ajstore key from configs/env.props. Do not upload this build to Play."
                )
                storeFile = rootProject.file("../configs/${envProps.getProperty("storeFile", "ajstore-keystore.jks")}")
                storePassword = envProps.getProperty("storePassword")
                keyAlias = envProps.getProperty("keyAlias")
                keyPassword = envProps.getProperty("keyPassword")
            }
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
            // The unminified build ships ~30 MB of dex to every device, which no
            // amount of ABI splitting removes. R8 is the only lever on that.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
