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
    compileSdk = 37
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
            // Store .so files uncompressed and page-aligned inside the APK
            // so the OS can mmap them directly. This is REQUIRED for
            // Android 15+ devices that use 16 KB pages (e.g. Pixel 10 Pro XL)
            // and fixes the "Android App Compatibility / RELRO alignment"
            // warning that appears when plugin prebuilt .so files (camera,
            // flutter_image_compress, datastore, etc.) aren't aligned.
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

    signingConfigs {
        // Global release config — fallback for flavors without their own key
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
        // Per-flavor keystores: android/keystore/<flavor>/<flavor>.properties
        // Add a folder + properties file for any new flavor — no code change needed.
        val brandFlavors = extra["brandFlavors"] as List<Map<String, Any?>>
        brandFlavors.forEach { brand ->
            val flavorName = brand["name"] as String
            val propsFile = rootProject.file("keystore/$flavorName/$flavorName.properties")
            if (propsFile.exists()) {
                val props = Properties().apply { load(FileInputStream(propsFile)) }
                create(flavorName) {
                    keyAlias = props["keyAlias"] as String
                    keyPassword = props["keyPassword"] as String
                    storeFile = rootProject.file(props["storeFile"] as String)
                    storePassword = props["storePassword"] as String
                }
            }
        }
    }

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
                // Flavor-specific key wins; fallback to global release or debug key.
                signingConfig = signingConfigs.findByName(name)
                    ?: if (keystorePropertiesFile.exists()) signingConfigs.getByName("release")
                    else signingConfigs.getByName("debug")
            }
        }
    }

    buildTypes {
        release {
            // signingConfig is set per-flavor in productFlavors above — not here.
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

// ────────────────────────────────────────────────────────────────────────────
// 16 KB page-size compatibility (Android 15+ requirement)
// ────────────────────────────────────────────────────────────────────────────
// Pixel 10 Pro XL and other devices running Android 15+ use 16 KB memory pages.
// The OS refuses to load .so files whose PT_LOAD / PT_GNU_RELRO program-header
// p_align is not at least 0x4000, showing the "Android App Compatibility /
// RELRO alignment" dialog.
//
// To fix prebuilt libraries shipped by older Flutter plugins (camera,
// flutter_image_compress, datastore, etc.) without needing each plugin author
// to release a new build, we run Google's `realign_elf` shim AFTER mergeJniLibs
// for every variant. See scripts/realign_elf_16kb.py for the implementation.
afterEvaluate {
    val realignScript = rootProject.file("scripts/realign_elf_16kb.py")
    if (!realignScript.exists()) {
        logger.warn("16KB: scripts/realign_elf_16kb.py not found — skipping ELF realignment.")
    } else {
        android.applicationVariants.all {
            val mergeTask = tasks.findByName("merge${name.capitalize()}JniLibs")
            if (mergeTask != null) {
                mergeTask.doLast {
                    val jniRoot = file("$buildDir/intermediates/merged_native_libs/${name}/out/lib")
                    if (!jniRoot.exists()) return@doLast
                    val soFiles = jniRoot.walkTopDown().filter { it.extension == "so" }.toList()
                    if (soFiles.isNotEmpty()) {
                        logger.lifecycle("16KB: realigning ${soFiles.size} .so file(s) in ${jniRoot.path}")
                        exec {
                            commandLine(
                                "python3", realignScript.absolutePath,
                                "--lib-dir", jniRoot.absolutePath,
                                "--ndk", "${android.sdkDirectory}/ndk/${android.ndkVersion}"
                            )
                        }
                    }
                }
            }
        }
    }
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


