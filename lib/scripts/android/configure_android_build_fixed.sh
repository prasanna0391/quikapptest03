#!/usr/bin/env bash

set -euo pipefail
echo "🛠️ Configuring a complete and modern Android build..."

# --- START: SDK Version Configuration ---
export PKG_NAME="${PKG_NAME:-com.example.app}"
export COMPILE_SDK_VERSION="${COMPILE_SDK_VERSION:-35}"
export MIN_SDK_VERSION="${MIN_SDK_VERSION:-21}"
export TARGET_SDK_VERSION="${TARGET_SDK_VERSION:-35}"
# --- END: SDK Version Configuration ---

echo "Using PKG_NAME: $PKG_NAME"
echo "Using COMPILE_SDK_VERSION: $COMPILE_SDK_VERSION"

# Determine build configuration
PUSH_NOTIFY="${PUSH_NOTIFY:-false}"
HAS_KEYSTORE_URL="${KEY_STORE:-}"

echo "Build Configuration:"
echo "- Push Notifications: ${PUSH_NOTIFY}"
echo "- Keystore URL: ${HAS_KEYSTORE_URL:+Present}"

# Get Flutter SDK path from local.properties
FLUTTER_SDK_PATH=""
if [ -f "android/local.properties" ]; then
    FLUTTER_SDK_PATH=$(grep "flutter.sdk" android/local.properties | cut -d'=' -f2)
    # Remove any quotes if present
    FLUTTER_SDK_PATH=$(echo "$FLUTTER_SDK_PATH" | tr -d '"')
fi

if [ -z "$FLUTTER_SDK_PATH" ]; then
    echo "❌ Error: Flutter SDK path not found in local.properties"
    exit 1
fi

echo "Using Flutter SDK path: $FLUTTER_SDK_PATH"

# Added debugging to verify file locations
echo "-------------------------------------------------"
echo "🔍 Listing contents of the /android/ directory to verify file locations..."
ls -laR android/
echo "-------------------------------------------------"

# --- Common Gradle Configuration ---
echo "✍️ Writing root Gradle files..."

# Create settings.gradle.kts
cat > android/settings.gradle.kts << EOF
pluginManagement {
    includeBuild("$FLUTTER_SDK_PATH/packages/flutter_tools/gradle")
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.3.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.23" apply false
EOF

if [ "${PUSH_NOTIFY}" = "true" ]; then
    echo '    id("com.google.gms.google-services") version "4.4.2" apply false' >> android/settings.gradle.kts
fi

cat >> android/settings.gradle.kts << 'EOF'
}
include(":app")
EOF

# Create build.gradle.kts
cat > android/build.gradle.kts << 'EOF'
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
EOF

# Create app/build.gradle.kts
cat > android/app/build.gradle.kts << 'EOF'
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
EOF

if [ "${PUSH_NOTIFY}" = "true" ]; then
    echo '    id("com.google.gms.google-services")' >> android/app/build.gradle.kts
fi

cat >> android/app/build.gradle.kts << 'EOF'
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
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.23")
EOF

if [ "${PUSH_NOTIFY}" = "true" ]; then
    echo '    implementation(platform("com.google.firebase:firebase-bom:32.7.4"))' >> android/app/build.gradle.kts
fi

cat >> android/app/build.gradle.kts << 'EOF'
}
EOF

# Create gradle.properties
cat > android/gradle.properties << 'EOF'
org.gradle.jvmargs=-Xmx1536M
android.useAndroidX=true
android.enableJetifier=true
android.defaults.buildfeatures.buildconfig=true
android.nonTransitiveRClass=false
android.nonFinalResIds=false
EOF

echo "✅ All Android Gradle files configured successfully."
echo "Build Configuration Summary:"
echo "- Push Notifications: ${PUSH_NOTIFY}"
echo "- Keystore URL: ${HAS_KEYSTORE_URL:+Present}"
echo "- Output Formats: ${HAS_KEYSTORE_URL:+APK, AAB}${HAS_KEYSTORE_URL:-APK only}"
##!/usr/bin/env bash
#
#set -euo pipefail
#echo "🛠️ Configuring a complete and modern Android build..."
#
## --- START: SDK Version Configuration ---
#export PKG_NAME="${PKG_NAME:-com.example.app}"
#export COMPILE_SDK_VERSION="${COMPILE_SDK_VERSION:-35}"
#export MIN_SDK_VERSION="${MIN_SDK_VERSION:-21}"
#export TARGET_SDK_VERSION="${TARGET_SDK_VERSION:-35}"
## --- END: SDK Version Configuration ---
#
#echo "Using PKG_NAME: $PKG_NAME"
#echo "Using COMPILE_SDK_VERSION: $COMPILE_SDK_VERSION"
#
## Determine build configuration
#PUSH_NOTIFY="${PUSH_NOTIFY:-false}"
#HAS_KEYSTORE_URL="${KEY_STORE:-}"
#
#echo "Build Configuration:"
#echo "- Push Notifications: ${PUSH_NOTIFY}"
#echo "- Keystore URL: ${HAS_KEYSTORE_URL:+Present}"
#
## Get Flutter SDK path from local.properties
#FLUTTER_SDK_PATH=""
#if [ -f "android/local.properties" ]; then
#    FLUTTER_SDK_PATH=$(grep "flutter.sdk" android/local.properties | cut -d'=' -f2)
#    # Remove any quotes if present
#    FLUTTER_SDK_PATH=$(echo "$FLUTTER_SDK_PATH" | tr -d '"')
#fi
#
#if [ -z "$FLUTTER_SDK_PATH" ]; then
#    echo "❌ Error: Flutter SDK path not found in local.properties"
#    exit 1
#fi
#
#echo "Using Flutter SDK path: $FLUTTER_SDK_PATH"
#
## Added debugging to verify file locations
#echo "-------------------------------------------------"
#echo "🔍 Listing contents of the /android/ directory to verify file locations..."
#ls -laR android/
#echo "-------------------------------------------------"
#
## --- Common Gradle Configuration ---
#echo "✍️ Writing root Gradle files..."
#
## Create settings.gradle.kts
#cat > android/settings.gradle.kts << EOF
#pluginManagement {
#    includeBuild("$FLUTTER_SDK_PATH/packages/flutter_tools/gradle")
#    repositories {
#        google()
#        mavenCentral()
#        gradlePluginPortal()
#    }
#}
#plugins {
#    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
#    id("com.android.application") version "8.3.0" apply false
#    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
#EOF
#
#if [ "${PUSH_NOTIFY}" = "true" ]; then
#    echo '    id("com.google.gms.google-services") version "4.4.2" apply false' >> android/settings.gradle.kts
#fi
#
#cat >> android/settings.gradle.kts << 'EOF'
#}
#include(":app")
#EOF
#
## Create build.gradle.kts
#cat > android/build.gradle.kts << 'EOF'
#allprojects {
#    repositories {
#        google()
#        mavenCentral()
#    }
#}
#tasks.register<Delete>("clean") {
#    delete(rootProject.buildDir)
#}
#EOF
#
## Create app/build.gradle.kts
#cat > android/app/build.gradle.kts << 'EOF'
#import java.util.Properties
#import java.io.FileInputStream
#import java.io.File
#
#// Load local.properties for flutter.sdk path
#val localProperties = Properties()
#val localPropertiesFile = rootProject.file("local.properties")
#if (localPropertiesFile.exists()) {
#    localPropertiesFile.inputStream().use { input ->
#        localProperties.load(input)
#    }
#}
#val flutterRoot = localProperties.getProperty("flutter.sdk")
#if (flutterRoot == null) {
#    throw GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
#}
#
#// Load key.properties for signing credentials if keystore URL is present
#val keystoreProperties = Properties()
#val keystorePropertiesFile = file("../key.properties")
#if (keystorePropertiesFile.exists()) {
#    keystorePropertiesFile.inputStream().use { input ->
#        keystoreProperties.load(input)
#    }
#} else if (System.getenv("KEY_STORE") != null) {
#    println("WARNING: android/key.properties not found but keystore URL is present")
#}
#
#plugins {
#    id("com.android.application")
#    id("org.jetbrains.kotlin.android")
#    id("dev.flutter.flutter-gradle-plugin")
#EOF
#
#if [ "${PUSH_NOTIFY}" = "true" ]; then
#    echo '    id("com.google.gms.google-services")' >> android/app/build.gradle.kts
#fi
#
#cat >> android/app/build.gradle.kts << 'EOF'
#}
#
#android {
#    namespace = System.getenv("PKG_NAME") ?: "com.example.app"
#    compileSdk = (System.getenv("COMPILE_SDK_VERSION") ?: "35").toInt()
#
#    compileOptions {
#        sourceCompatibility = JavaVersion.VERSION_11
#        targetCompatibility = JavaVersion.VERSION_11
#        isCoreLibraryDesugaringEnabled = true
#    }
#
#    kotlinOptions {
#        jvmTarget = "11"
#    }
#
#    defaultConfig {
#        applicationId = System.getenv("PKG_NAME") ?: "com.example.app"
#        minSdk = (System.getenv("MIN_SDK_VERSION") ?: "21").toInt()
#        targetSdk = (System.getenv("TARGET_SDK_VERSION") ?: "35").toInt()
#        versionCode = (System.getenv("VERSION_CODE") ?: "1").toInt()
#        versionName = System.getenv("VERSION_NAME") ?: "1.0"
#    }
#
#    signingConfigs {
#        create("release") {
#            if (System.getenv("KEY_STORE") != null && keystoreProperties.isNotEmpty()) {
#                storeFile = file("../" + keystoreProperties.getProperty("storeFile"))
#                storePassword = keystoreProperties.getProperty("storePassword")
#                keyAlias = keystoreProperties.getProperty("keyAlias")
#                keyPassword = keystoreProperties.getProperty("keyPassword")
#            }
#        }
#    }
#
#    buildTypes {
#        release {
#            isMinifyEnabled = true
#            isShrinkResources = true
#            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
#            if (System.getenv("KEY_STORE") != null) {
#                signingConfig = signingConfigs.getByName("release")
#            }
#        }
#    }
#
#    // Configure output formats based on keystore URL presence
#    if (System.getenv("KEY_STORE") != null) {
#        buildTypes {
#            getByName("release") {
#                // Enable both APK and AAB for keystore builds
#                isDebuggable = false
#                isJniDebuggable = false
#                isRenderscriptDebuggable = false
#                isPseudoLocalesEnabled = false
#                isZipAlignEnabled = true
#            }
#        }
#    } else {
#        buildTypes {
#            getByName("release") {
#                // Only APK for non-keystore builds
#                isDebuggable = false
#                isJniDebuggable = false
#                isRenderscriptDebuggable = false
#                isPseudoLocalesEnabled = false
#                isZipAlignEnabled = true
#            }
#        }
#    }
#}
#
#flutter {
#    source = "../.."
#}
#
#dependencies {
#    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
#    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.22")
#EOF
#
#if [ "${PUSH_NOTIFY}" = "true" ]; then
#    echo '    implementation(platform("com.google.firebase:firebase-bom:32.7.4"))' >> android/app/build.gradle.kts
#fi
#
#cat >> android/app/build.gradle.kts << 'EOF'
#}
#EOF
#
## Create gradle.properties
#cat > android/gradle.properties << 'EOF'
#org.gradle.jvmargs=-Xmx1536M
#android.useAndroidX=true
#android.enableJetifier=true
#android.defaults.buildfeatures.buildconfig=true
#android.nonTransitiveRClass=false
#android.nonFinalResIds=false
#EOF
#
#echo "✅ All Android Gradle files configured successfully."
#echo "Build Configuration Summary:"
#echo "- Push Notifications: ${PUSH_NOTIFY}"
#echo "- Keystore URL: ${HAS_KEYSTORE_URL:+Present}"
#echo "- Output Formats: ${HAS_KEYSTORE_URL:+APK, AAB}${HAS_KEYSTORE_URL:-APK only}"