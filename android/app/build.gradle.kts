plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.pipze"
    compileSdk = 36
    ndkVersion = "29.0.14206865"

    compileOptions {
        // Flutter plugins (e.g. shared_preferences_android) now compile with Java 17.
        // Align the app module toolchain to avoid classpath/compilation issues.
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }


    buildFeatures {
        buildConfig = true
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "com.pipze.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Version is automatically synced from pubspec.yaml by Flutter
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "brand"
    
    productFlavors {
        create("tenax") {
            dimension = "brand"
            applicationId = "com.tenax.app"
            resValue("string", "app_name", "Tenax")
            resValue("color", "primary_color", "#4A0C54")
            resValue("color", "secondary_color", "#E8F5E8")
            resValue("color", "accent_color", "#4A0C54")
            buildConfigField("String", "FLAVOR", "\"tenax\"")
            manifestPlaceholders["FLAVOR"] = "tenax"
        }

        create("vantage") {
            dimension = "brand"
            // Keep same ID unless you have a final applicationId for Vantage.
            applicationId = "com.vantage.app"
            resValue("string", "app_name", "Vantage")
            resValue("color", "primary_color", "#5F259E")
            resValue("color", "secondary_color", "#F8F3FF")
            resValue("color", "accent_color", "#FFC93C")
            buildConfigField("String", "FLAVOR", "\"vantage\"")
            manifestPlaceholders["FLAVOR"] = "vantage"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            isDebuggable = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Android 12+ splash screen customization (disable default app icon splash)
    implementation("androidx.core:core-splashscreen:1.0.1")
}

// Skip Google Services task for flavors without Firebase config
// to avoid requiring google-services.json.
afterEvaluate {
  // Vantage flavor currently has no Firebase config.
  tasks.matching {
    it.name.startsWith("processVantage") && it.name.endsWith("GoogleServices")
  }.configureEach {
    enabled = false
  }
}


