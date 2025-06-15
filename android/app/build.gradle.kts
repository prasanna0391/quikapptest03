import java.util.Properties
import java.io.FileInputStream
import java.io.File

// Load local.properties for flutter.sdk path
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { input ->
        localProperties.load(input)
    }
}
val flutterRoot = localProperties.getProperty("flutter.sdk")
if (flutterRoot == null) {
    throw GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
}

// Load key.properties for signing credentials if keystore URL is present
val keystoreProperties = Properties()
val keystorePropertiesFile = file("../key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { input ->
        keystoreProperties.load(input)
    }
} else if (System.getenv("KEY_STORE") != null) {
    println("WARNING: android/key.properties not found but keystore URL is present")
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = System.getenv("PKG_NAME") ?: "com.example.app"
    compileSdk = (System.getenv("COMPILE_SDK_VERSION") ?: "35").toInt()

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = System.getenv("PKG_NAME") ?: "com.example.app"
        minSdk = (System.getenv("MIN_SDK_VERSION") ?: "21").toInt()
        targetSdk = (System.getenv("TARGET_SDK_VERSION") ?: "35").toInt()
        versionCode = (System.getenv("VERSION_CODE") ?: "1").toInt()
        versionName = System.getenv("VERSION_NAME") ?: "1.0"
    }

    signingConfigs {
        create("release") {
            if (System.getenv("KEY_STORE") != null && keystoreProperties.isNotEmpty()) {
                storeFile = file("../" + keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (System.getenv("KEY_STORE") != null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    // Configure output formats based on keystore URL presence
    if (System.getenv("KEY_STORE") != null) {
        buildTypes {
            getByName("release") {
                // Enable both APK and AAB for keystore builds
                isDebuggable = false
                isJniDebuggable = false
                isRenderscriptDebuggable = false
                isPseudoLocalesEnabled = false
                isZipAlignEnabled = true
            }
        }
    } else {
        buildTypes {
            getByName("release") {
                // Only APK for non-keystore builds
                isDebuggable = false
                isJniDebuggable = false
                isRenderscriptDebuggable = false
                isPseudoLocalesEnabled = false
                isZipAlignEnabled = true
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
