plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // Always last
}

android {
    namespace = "com.example.finance_gpt"   // ✅ MUST match app logic
    compileSdk = 35                         // ✅ Required for latest plugins

    defaultConfig {
        applicationId = "com.example.finance_gpt"
        minSdk = 21                         // ✅ safe default for most plugins
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // You can change this later
        }
    }

    // ✅ Add this to prevent plugin issues
    buildFeatures {
        buildConfig = true
    }
}

flutter {
    source = "../.."
}
