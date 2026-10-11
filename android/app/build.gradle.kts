plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.attasak.pdf_flip_reader"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.attasak.pagelume"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Upload key for Google Play. CI writes upload-keystore.jks from the
    // UPLOAD_KEYSTORE_BASE64 secret and passes UPLOAD_KEYSTORE_PASSWORD.
    // Without them, release builds use the debug key.
    val uploadPassword = System.getenv("UPLOAD_KEYSTORE_PASSWORD").orEmpty()
    signingConfigs {
        if (uploadPassword.isNotEmpty()) {
            create("upload") {
                storeFile = file("upload-keystore.jks")
                storePassword = uploadPassword
                keyAlias = "upload"
                keyPassword = uploadPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (uploadPassword.isNotEmpty()) "upload" else "debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // FileProvider, for putting copied page images on the clipboard.
    implementation("androidx.core:core:1.13.1")
}
