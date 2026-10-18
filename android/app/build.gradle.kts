import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// APP_ROLE is set in gradle.properties before each build
val appRole: String = project.findProperty("APP_ROLE") as? String ?: ""

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

android {
    namespace = "com.example.housefoods"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = when (appRole) {
            "customer" -> "app.mealin.customer"
            "chef" -> "app.mealin.kitchen"
            "delivery_partner" -> "app.mealin.delivery"
            else -> "app.mealin"
        }
        minSdk = 24
        // Pinned explicitly rather than via flutter.minSdkVersion /
        // flutter.targetSdkVersion. Flutter 3.47.7 resolves both to 24/36
        // anyway (see FlutterExtension.kt), so this changes no behaviour — it
        // makes the Google Play policy floor explicit and stops a Flutter
        // upgrade from silently moving it. Play's Aug 2026 policy requires a
        // recent targetSdk; 36 satisfies that.
        targetSdk = 36
        compileSdk = 36
        multiDexEnabled = true
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Supply via the MAPS_API_KEY environment variable, or -PMAPS_API_KEY=... in CI.
        val mapsApiKey = System.getenv("MAPS_API_KEY")
            ?: project.findProperty("MAPS_API_KEY")?.toString()
            ?: ""
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
        manifestPlaceholders["APP_LABEL"] = when (appRole) {
            "customer" -> "MEALIN"
            "chef" -> "MEALIN RESTO"
            "delivery_partner" -> "MEALIN RIDER"
            else -> "MEALIN"
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String?
            keyPassword = keyProperties["keyPassword"] as String?
            storeFile = keyProperties["storeFile"]?.let { file(it.toString()) } ?: file("mealin-release.keystore")
            storePassword = keyProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Never ship an APK/AAB signed with the debug certificate. Release
            // credentials must be supplied through the ignored key.properties.
            // buildTypes is evaluated for every variant, so only enforce this
            // when a release variant is actually being assembled.
            val buildingRelease = gradle.startParameter.taskNames.any {
                it.contains("release", ignoreCase = true)
            }
            if (buildingRelease && !keyPropertiesFile.exists()) {
                throw GradleException("Missing android/key.properties: release signing is required")
            }
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
