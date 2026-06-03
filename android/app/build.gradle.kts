plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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
        // Tenax — legacy flavor (not in brands.yaml)
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

        // Vantage — parent brand (has its own screen files)
        // Colors are in android/app/src/vantage/res/values/colors.xml
        create("vantage") {
            dimension = "brand"
            applicationId = "com.vantage.app"
            resValue("string", "app_name", "Vantage")
            buildConfigField("String", "FLAVOR", "\"vantage\"")
            manifestPlaceholders["FLAVOR"] = "vantage"
        }

        // Celestial — child brand (inherits Vantage's screen files, different colors/icons/URLs)
        create("celestial") {
            dimension = "brand"
            applicationId = "com.celestial.app"
            resValue("string", "app_name", "Celestial")
            buildConfigField("String", "FLAVOR", "\"celestial\"")
            manifestPlaceholders["FLAVOR"] = "celestial"
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
    // Vantage and Celestial flavors have no Firebase config.
    tasks.matching {
        (it.name.startsWith("processVantage") || it.name.startsWith("processCelestial")) &&
            it.name.endsWith("GoogleServices")
    }.configureEach {
        enabled = false
    }
}


