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

    // The three roles ship from one codebase, so the launcher icon used to be
    // the customer app's orange mark on every device. Each role now owns its
    // own launcher assets under src/<role>/res and exactly one of them is
    // added to the build. `res.srcDir` appends rather than overrides, which is
    // why the shared copies were removed from src/main/res — leaving them there
    // would make every pair a "Duplicate resources" error.
    sourceSets {
        val roleRes = when (appRole) {
            "customer" -> "src/customer/res"
            "chef" -> "src/chef/res"
            "delivery_partner" -> "src/delivery/res"
            else -> "src/customer/res"
        }
        getByName("main").res.srcDir(roleRes)
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
