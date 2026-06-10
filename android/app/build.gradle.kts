plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Properties
import java.io.FileInputStream

apply(from = rootProject.file("brand_flavors.gradle"))

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
        val brandFlavors = extra["brandFlavors"] as List<Map<String, Any?>>
        brandFlavors.forEach { brand ->
            val name = brand["name"] as String
            create(name) {
                dimension = "brand"
                applicationId = brand["appId"] as String
                resValue("string", "app_name", brand["appName"] as String)
                resValue("color", "primary_color", brand["primary"] as String)
                resValue("color", "secondary_color", brand["secondary"] as String)
                resValue("color", "accent_color", brand["accent"] as String)
                resValue("color", "my_splash_color", brand["splashColor"] as String)
                resValue("color", "ic_launcher_background", brand["launcherBackground"] as String)
                buildConfigField("String", "FLAVOR", "\"$name\"")
                manifestPlaceholders["FLAVOR"] = name
            }
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
    val brandFlavors = extra["brandFlavors"] as List<Map<String, Any?>>
    val flavorsWithoutFirebase = brandFlavors
        .map { it["name"] as String }
        .filter { name -> !file("src/$name/google-services.json").exists() }
        .map { name -> name.replaceFirstChar { char -> char.uppercaseChar() } }

    tasks.matching {
        flavorsWithoutFirebase.any { flavor -> it.name.startsWith("process$flavor") } &&
            it.name.endsWith("GoogleServices")
    }.configureEach {
        enabled = false
    }
}


