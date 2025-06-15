#!/bin/bash
set -euo pipefail

# Ensure we're using bash
if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Validate required variables
validate_required_variables() {
    echo "Validating required variables..."
    
    # Only check essential variables that must be present
    local essential_vars=(
        "VERSION_NAME"
        "VERSION_CODE"
        "APP_NAME"
        "PKG_NAME"
        "BUNDLE_ID"
    )
    
    # Function to check variables
    check_variables() {
        local category=$1
        shift
        local missing=()
        
        for var in "$@"; do
            if [ -z "${!var:-}" ]; then
                missing+=("$var")
            fi
        done
        
        if [ ${#missing[@]} -gt 0 ]; then
            echo "⚠️ Missing $category variables:"
            printf '%s\n' "${missing[@]}"
            return 1
        fi
        return 0
    }
    
    # Check essential variables
    echo "Checking Essential Variables..."
    if ! check_variables "Essential" "${essential_vars[@]}"; then
        handle_build_error "Missing essential variables" 1 "$0" "${LINENO:-}"
    fi
    
    # Log available variables for debugging
    echo "📝 Available variables:"
    echo "App Info:"
    echo "- VERSION_NAME: ${VERSION_NAME:-}"
    echo "- VERSION_CODE: ${VERSION_CODE:-}"
    echo "- APP_NAME: ${APP_NAME:-}"
    echo "- PKG_NAME: ${PKG_NAME:-}"
    echo "- BUNDLE_ID: ${BUNDLE_ID:-}"
    
    echo "Feature Flags:"
    echo "- PUSH_NOTIFY: ${PUSH_NOTIFY:-}"
    echo "- IS_CHATBOT: ${IS_CHATBOT:-}"
    echo "- IS_DEEPLINK: ${IS_DEEPLINK:-}"
    echo "- IS_SPLASH: ${IS_SPLASH:-}"
    echo "- IS_PULLDOWN: ${IS_PULLDOWN:-}"
    echo "- IS_BOTTOMMENU: ${IS_BOTTOMMENU:-}"
    echo "- IS_LOAD_IND: ${IS_LOAD_IND:-}"
    
    echo "Build Mode:"
    echo "- BUILD_MODE: ${BUILD_MODE:-}"
    echo "- FLUTTER_VERSION: ${FLUTTER_VERSION:-}"
    echo "- GRADLE_VERSION: ${GRADLE_VERSION:-}"
    
    echo "✅ Variable validation completed"
}

# Load environment variables from admin_vars.sh
load_env_variables() {
    echo "Loading environment variables..."
    
    # Source admin variables
    if [ -f "${SCRIPT_DIR}/admin_vars.sh" ]; then
        source "${SCRIPT_DIR}/admin_vars.sh"
        echo "✅ Admin variables loaded successfully"
    else
        handle_build_error "admin_vars.sh not found" 1 "$0" "${LINENO:-}"
    fi
    
    # Validate essential variables
    validate_required_variables
}

# Enhanced error handling function
handle_build_error() {
    local error_message="$1"
    local error_code="${2:-1}"
    local error_file="${3:-}"
    local error_line="${4:-}"
    
    echo "❌ Build Error: $error_message"
    if [ -n "$error_file" ] && [ -n "$error_line" ]; then
        echo "📄 Error location: $error_file:$error_line"
    fi
    
    # Capture build logs
    echo "📝 Capturing build logs..."
    "${SCRIPT_DIR}/capture_build_logs.sh" || echo "⚠️ Failed to capture build logs"
    
    # Send error notification
    echo "📧 Sending error notification to ${EMAIL_ID:-}"
    if [ -f "${SCRIPT_DIR}/send_error_email.sh" ]; then
        "${SCRIPT_DIR}/send_error_email.sh" "$error_message" "$error_code" "$error_file" "$error_line" || {
            echo "⚠️ Failed to send error email"
        }
    fi
    
    exit "$error_code"
}

# Create necessary directories with error handling
create_directories() {
    echo "Creating required directories..."
    local dirs=(
        "$PROJECT_ROOT/assets"
        "$PROJECT_ROOT/assets/images"
        "$PROJECT_ROOT/android/app/src/main/res/mipmap-hdpi"
        "$PROJECT_ROOT/android/app/src/main/res/mipmap-mdpi"
        "$PROJECT_ROOT/android/app/src/main/res/mipmap-xhdpi"
        "$PROJECT_ROOT/android/app/src/main/res/mipmap-xxhdpi"
        "$PROJECT_ROOT/android/app/src/main/res/mipmap-xxxhdpi"
        "$PROJECT_ROOT/android/app/src/main/res/drawable"
        "$PROJECT_ROOT/android/app/src/main/res/values"
        "$PROJECT_ROOT/android/app/src/main/kotlin/com/garbcode/garbcodeapp"
    )
    
    for dir in "${dirs[@]}"; do
        if ! mkdir -p "$dir"; then
            handle_build_error "Failed to create directory: $dir" 1 "$0" "${LINENO:-}"
        fi
    done
    echo "✅ Required directories created"
}

# Make scripts executable with error handling
make_scripts_executable() {
    echo "Making scripts executable..."
    local scripts=(
        "${SCRIPT_DIR}/debug_env.sh"
        "${SCRIPT_DIR}/inject_manifast_template.sh"
        "${SCRIPT_DIR}/inject_permissions_android.sh"
        "${SCRIPT_DIR}/fix_v1_embedding.sh"
        "${SCRIPT_DIR}/configure_android_build_fixed.sh"
        "${SCRIPT_DIR}/inject_keystore.sh"
        "${SCRIPT_DIR}/update_version.sh"
        "${SCRIPT_DIR}/change_app_name.sh"
        "${SCRIPT_DIR}/get_logo.sh"
        "${SCRIPT_DIR}/get_splash.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if ! chmod +x "$script"; then
                handle_build_error "Failed to make script executable: $script" 1 "$0" "${LINENO:-}"
            fi
        else
            echo "⚠️ Script not found: $script"
        fi
    done
    echo "✅ Scripts made executable"
}

# Initialize Flutter Android project with enhanced error handling
initialize_flutter_android() {
    echo "Initializing Flutter Android project..."
    
    # Create a temporary directory
    TEMP_DIR=$(mktemp -d)
    echo "Created temporary directory: $TEMP_DIR"
    
    # Create a new Flutter project in the temp directory
    cd "$TEMP_DIR" || handle_build_error "Failed to change to temp directory" 1 "$0" "${LINENO:-}"
    
    echo "Creating Flutter project in temporary directory..."
    if ! flutter create --org com.garbcode --project-name garbcodeapp .; then
        cd "$PROJECT_ROOT"
        rm -rf "$TEMP_DIR"
        handle_build_error "Failed to create Flutter project" 1 "$0" "${LINENO:-}"
    fi
    
    # Copy Android configuration files
    echo "Copying Android configuration files..."
    if [ -d "$TEMP_DIR/android" ]; then
        if ! cp -rv "$TEMP_DIR/android/"* "$PROJECT_ROOT/android/"; then
            cd "$PROJECT_ROOT"
            rm -rf "$TEMP_DIR"
            handle_build_error "Failed to copy Android files" 1 "$0" "${LINENO:-}"
        fi
    else
        cd "$PROJECT_ROOT"
        rm -rf "$TEMP_DIR"
        handle_build_error "Android directory not found in temporary Flutter project" 1 "$0" "${LINENO:-}"
    fi
    
    # Clean up
    cd "$PROJECT_ROOT"
    rm -rf "$TEMP_DIR"
    
    # Update build.gradle configuration
    echo "Updating build.gradle configuration..."
    local BUILD_GRADLE_FILE
    if [ -f "$PROJECT_ROOT/android/app/build.gradle.kts" ]; then
        BUILD_GRADLE_FILE="$PROJECT_ROOT/android/app/build.gradle.kts"
    elif [ -f "$PROJECT_ROOT/android/app/build.gradle" ]; then
        BUILD_GRADLE_FILE="$PROJECT_ROOT/android/app/build.gradle"
    else
        handle_build_error "build.gradle or build.gradle.kts not found" 1 "$0" "${LINENO:-}"
    fi
    
    # Update version and application ID
    "${SCRIPT_DIR}/update_version.sh" "$BUILD_GRADLE_FILE" || {
        handle_build_error "Failed to update version in build.gradle" 1 "$0" "${LINENO:-}"
    }
    
    echo "✅ Flutter Android project initialized"
}

# Handle build mode configuration
configure_build_mode() {
    echo "Configuring build mode..."
    
    # Set default build mode if not specified
    BUILD_MODE="${BUILD_MODE:-basic}"
    
    # Validate build mode
    case "${BUILD_MODE}" in
        "basic"|"firebase"|"release"|"aab"|"app-store")
            echo "✅ Build mode set to: ${BUILD_MODE}"
            ;;
        *)
            handle_build_error "Invalid build mode: ${BUILD_MODE}" 1 "$0" "${LINENO:-}"
            ;;
    esac
    
    # Configure build parameters based on mode
    case "${BUILD_MODE}" in
        "basic")
            BUILD_TYPE="apk"
            BUILD_FLAVOR="basic"
            ;;
        "firebase")
            BUILD_TYPE="apk"
            BUILD_FLAVOR="firebase"
            ;;
        "release"|"app-store")
            BUILD_TYPE="apk"
            BUILD_FLAVOR="release"
            ;;
        "aab")
            BUILD_TYPE="appbundle"
            BUILD_FLAVOR="release"
            ;;
    esac
    
    echo "📦 Build configuration:"
    echo "- Type: ${BUILD_TYPE}"
    echo "- Flavor: ${BUILD_FLAVOR}"
    echo "- Mode: ${BUILD_MODE}"
}

# Setup output directories
setup_output_directories() {
    echo "Setting up output directories..."
    
    # Create output directory structure
    local output_dirs=(
        "${PROJECT_ROOT}/output"
        "${PROJECT_ROOT}/output/apk"
        "${PROJECT_ROOT}/output/aab"
        "${PROJECT_ROOT}/output/logs"
    )
    
    for dir in "${output_dirs[@]}"; do
        if ! mkdir -p "$dir"; then
            handle_build_error "Failed to create output directory: $dir" 1 "$0" "${LINENO:-}"
        fi
    done
    
    # Set output paths
    export APK_OUTPUT_PATH="${PROJECT_ROOT}/output/apk"
    export AAB_OUTPUT_PATH="${PROJECT_ROOT}/output/aab"
    export LOG_OUTPUT_PATH="${PROJECT_ROOT}/output/logs"
    
    echo "✅ Output directories configured"
}

# Handle build outputs
handle_build_outputs() {
    echo "Handling build outputs..."
    
    # Move APK if needed
    if [[ "${OUTPUT_TYPES:-}" == *"apk"* ]]; then
        echo "Moving APK to output directory..."
        if ! mv "${PROJECT_ROOT}/build/app/outputs/flutter-apk/app-release.apk" "${APK_OUTPUT_PATH}/app-${VERSION_NAME:-}-${VERSION_CODE:-}.apk"; then
            handle_build_error "Failed to move APK to output directory" 1 "$0" "${LINENO:-}"
        fi
    fi
    
    # Move AAB if needed
    if [[ "${OUTPUT_TYPES:-}" == *"aab"* ]]; then
        echo "Moving AAB to output directory..."
        if ! mv "${PROJECT_ROOT}/build/app/outputs/bundle/release/app-release.aab" "${AAB_OUTPUT_PATH}/app-${VERSION_NAME:-}-${VERSION_CODE:-}.aab"; then
            handle_build_error "Failed to move AAB to output directory" 1 "$0" "${LINENO:-}"
        fi
    fi
    
    # Copy build logs
    echo "Copying build logs..."
    if ! cp "${PROJECT_ROOT}/build.log" "${LOG_OUTPUT_PATH}/build-${VERSION_NAME:-}-${VERSION_CODE:-}.log"; then
        echo "⚠️ Failed to copy build logs, but continuing..."
    fi
    
    echo "✅ Build outputs handled"
}

# Configure email settings
configure_email_settings() {
    echo "Configuring email settings..."
    
    # SMTP Configuration
    export EMAIL_SMTP_SERVER="smtp.gmail.com"
    export EMAIL_SMTP_PORT="587"
    export EMAIL_SMTP_USER="${Notifi_E_ID:-prasannasrie@gmail.com}"
    export EMAIL_SMTP_PASS="jbbf nzhm zoay lbwb"
    
    # Email notification settings
    export NOTIFICATION_EMAIL_FROM="${EMAIL_SMTP_USER}"
    export NOTIFICATION_EMAIL_TO="${EMAIL_ID:-}"
    export NOTIFICATION_EMAIL_SUBJECT="QuikApp Build Status - ${APP_NAME:-QuikApp}"
    
    # Verify email configuration
    if [ -z "${EMAIL_SMTP_SERVER:-}" ] || [ -z "${EMAIL_SMTP_PORT:-}" ] || [ -z "${EMAIL_SMTP_USER:-}" ] || [ -z "${EMAIL_SMTP_PASS:-}" ]; then
        echo "⚠️ Warning: Incomplete email configuration"
    else
        echo "✅ Email configuration completed"
    fi
}

# Setup build environment
setup_build_environment() {
    echo "Setting up build environment..."
    
    # Set Gradle version
    if [ -n "${GRADLE_VERSION:-}" ]; then
        echo "Using Gradle version: ${GRADLE_VERSION}"
        sed -i '' "s/gradle-.*-all.zip/gradle-${GRADLE_VERSION}-all.zip/g" android/gradle/wrapper/gradle-wrapper.properties
    fi
    
    # Set Java version
    if [ -n "${JAVA_VERSION:-}" ]; then
        echo "Using Java version: ${JAVA_VERSION}"
        export JAVA_HOME=$(/usr/libexec/java_home -v ${JAVA_VERSION})
    fi
    
    # Set Android SDK versions
    if [ -n "${ANDROID_COMPILE_SDK:-}" ]; then
        echo "Using Android compile SDK: ${ANDROID_COMPILE_SDK}"
        sed -i '' "s/compileSdkVersion .*/compileSdkVersion ${ANDROID_COMPILE_SDK}/g" android/app/build.gradle
    fi
    
    if [ -n "${ANDROID_MIN_SDK:-}" ]; then
        echo "Using Android min SDK: ${ANDROID_MIN_SDK}"
        sed -i '' "s/minSdkVersion .*/minSdkVersion ${ANDROID_MIN_SDK}/g" android/app/build.gradle
    fi
    
    if [ -n "${ANDROID_TARGET_SDK:-}" ]; then
        echo "Using Android target SDK: ${ANDROID_TARGET_SDK}"
        sed -i '' "s/targetSdkVersion .*/targetSdkVersion ${ANDROID_TARGET_SDK}/g" android/app/build.gradle
    fi
    
    # Set build tools version
    if [ -n "${ANDROID_BUILD_TOOLS:-}" ]; then
        echo "Using Android build tools: ${ANDROID_BUILD_TOOLS}"
        sed -i '' "s/buildToolsVersion .*/buildToolsVersion \"${ANDROID_BUILD_TOOLS}\"/g" android/app/build.gradle
    fi
    
    # Set NDK version
    if [ -n "${ANDROID_NDK_VERSION:-}" ]; then
        echo "Using Android NDK version: ${ANDROID_NDK_VERSION}"
        sed -i '' "s/ndkVersion .*/ndkVersion \"${ANDROID_NDK_VERSION}\"/g" android/app/build.gradle
    fi
    
    # Set command line tools version
    if [ -n "${ANDROID_CMDLINE_TOOLS:-}" ]; then
        echo "Using Android command line tools: ${ANDROID_CMDLINE_TOOLS}"
        sed -i '' "s/cmdline-tools;.*/cmdline-tools;${ANDROID_CMDLINE_TOOLS}/g" android/app/build.gradle
    fi
    
    # Update app configuration
    if [ -n "${APP_NAME:-}" ]; then
        echo "Setting app name: ${APP_NAME}"
        sed -i '' "s/applicationId .*/applicationId \"${PKG_NAME}\"/g" android/app/build.gradle
        sed -i '' "s/label: .*/label: \"${APP_NAME}\"/g" android/app/src/main/AndroidManifest.xml
    fi
    
    # Update version information
    if [ -n "${VERSION_NAME:-}" ]; then
        echo "Setting version name: ${VERSION_NAME}"
        sed -i '' "s/versionName .*/versionName \"${VERSION_NAME}\"/g" android/app/build.gradle
    fi
    
    if [ -n "${VERSION_CODE:-}" ]; then
        echo "Setting version code: ${VERSION_CODE}"
        sed -i '' "s/versionCode .*/versionCode ${VERSION_CODE}/g" android/app/build.gradle
    fi
    
    # Configure keystore if provided
    if [ -n "${KEY_STORE:-}" ]; then
        echo "Configuring keystore..."
        cat > android/key.properties << EOL
storePassword=${CM_KEYSTORE_PASSWORD}
keyPassword=${CM_KEY_PASSWORD}
keyAlias=${CM_KEY_ALIAS}
storeFile=${KEY_STORE}
EOL
    fi
    
    echo "✅ Build environment setup completed"
}

# Main build process
main() {
    echo "🚀 Starting Android build process..."
    
    # Load environment variables
    load_env_variables
    
    # Configure email settings
    configure_email_settings
    
    # Configure build mode
    configure_build_mode
    
    # Setup output directories
    setup_output_directories
    
    # Create directories
    create_directories
    
    # Make scripts executable
    make_scripts_executable
    
    # Initialize Flutter Android project
    initialize_flutter_android
    
    # Setup build environment
    setup_build_environment
    
    # Download assets
    download_splash_assets
    
    # Configure keystore if needed
    if [ "${PUSH_NOTIFY:-}" = "true" ] || [ "${KEY_STORE:-}" != "" ]; then
        echo "Configuring keystore..."
        "${SCRIPT_DIR}/inject_keystore.sh" || {
            handle_build_error "Failed to configure keystore" 1 "$0" "${LINENO:-}"
        }
    fi
    
    # Build the app
    echo "Building Android app..."
    "${SCRIPT_DIR}/build.sh" || {
        handle_build_error "Build failed" 1 "$0" "${LINENO:-}"
    }
    
    # Handle build outputs
    handle_build_outputs
    
    echo "✅ Android build completed successfully"
}

# Run main function
main
