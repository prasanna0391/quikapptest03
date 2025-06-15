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
    
    # App Configuration Variables
    local required_vars=(
        "VERSION_NAME"
        "VERSION_CODE"
        "APP_NAME"
        "ORG_NAME"
        "WEB_URL"
        "PKG_NAME"
        "BUNDLE_ID"
        "EMAIL_ID"
    )
    
    # Feature Flags
    local feature_flags=(
        "PUSH_NOTIFY"
        "IS_CHATBOT"
        "IS_DEEPLINK"
        "IS_SPLASH"
        "IS_PULLDOWN"
        "IS_BOTTOMMENU"
        "IS_LOAD_IND"
    )
    
    # Permission Flags
    local permission_flags=(
        "IS_CAMERA"
        "IS_LOCATION"
        "IS_MIC"
        "IS_NOTIFICATION"
        "IS_CONTACT"
        "IS_BIOMETRIC"
        "IS_CALENDAR"
        "IS_STORAGE"
    )
    
    # Branding Variables
    local branding_vars=(
        "LOGO_URL"
        "SPLASH_URL"
        "SPLASH_BG"
        "SPLASH_BG_COLOR"
        "SPLASH_TAGLINE"
        "SPLASH_TAGLINE_COLOR"
        "SPLASH_ANIMATION"
        "SPLASH_DURATION"
    )
    
    # UI Configuration
    local ui_config_vars=(
        "BOTTOMMENU_ITEMS"
        "BOTTOMMENU_BG_COLOR"
        "BOTTOMMENU_ICON_COLOR"
        "BOTTOMMENU_TEXT_COLOR"
        "BOTTOMMENU_FONT"
        "BOTTOMMENU_FONT_SIZE"
        "BOTTOMMENU_FONT_BOLD"
        "BOTTOMMENU_FONT_ITALIC"
        "BOTTOMMENU_ACTIVE_TAB_COLOR"
        "BOTTOMMENU_ICON_POSITION"
        "BOTTOMMENU_VISIBLE_ON"
    )
    
    # Firebase Configuration
    local firebase_vars=(
        "FIREBASE_CONFIG_ANDROID"
        "FIREBASE_CONFIG_IOS"
    )
    
    # Android Keystore Variables
    local keystore_vars=(
        "KEY_STORE"
        "CM_KEYSTORE_PASSWORD"
        "CM_KEY_ALIAS"
        "CM_KEY_PASSWORD"
    )
    
    # Admin Variables
    local admin_vars=(
        "CM_BUILD_DIR"
        "BUILD_MODE"
        "FLUTTER_VERSION"
        "GRADLE_VERSION"
        "JAVA_VERSION"
        "ANDROID_COMPILE_SDK"
        "ANDROID_MIN_SDK"
        "ANDROID_TARGET_SDK"
        "ANDROID_BUILD_TOOLS"
        "ANDROID_NDK_VERSION"
        "ANDROID_CMDLINE_TOOLS"
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
    
    # Check all variable categories
    local has_errors=0
    
    echo "Checking App Configuration Variables..."
    check_variables "App Configuration" "${required_vars[@]}" || has_errors=1
    
    echo "Checking Feature Flags..."
    check_variables "Feature Flags" "${feature_flags[@]}" || has_errors=1
    
    echo "Checking Permission Flags..."
    check_variables "Permission Flags" "${permission_flags[@]}" || has_errors=1
    
    echo "Checking Branding Variables..."
    check_variables "Branding" "${branding_vars[@]}" || has_errors=1
    
    echo "Checking UI Configuration Variables..."
    check_variables "UI Configuration" "${ui_config_vars[@]}" || has_errors=1
    
    # Check Firebase variables if push notifications are enabled
    if [ "${PUSH_NOTIFY:-}" = "true" ]; then
        echo "Checking Firebase Configuration..."
        check_variables "Firebase" "${firebase_vars[@]}" || has_errors=1
    fi
    
    # Check Keystore variables if needed
    if [ "${PUSH_NOTIFY:-}" = "true" ] || [ "${KEY_STORE:-}" != "" ]; then
        echo "Checking Keystore Variables..."
        check_variables "Keystore" "${keystore_vars[@]}" || has_errors=1
    fi
    
    echo "Checking Admin Variables..."
    check_variables "Admin" "${admin_vars[@]}" || has_errors=1
    
    if [ $has_errors -eq 1 ]; then
        handle_build_error "Missing required variables" 1 "$0" "${LINENO:-}"
    fi
    
    echo "✅ All required variables validated"
}

# Load environment variables from API with improved error handling
load_env_variables() {
    echo "Loading environment variables from API..."
    
    # Try to load from API first
    if [ -n "${API_URL:-}" ]; then
        echo "Fetching variables from API..."
        API_RESPONSE=$(curl -s "${API_URL}/config" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${API_TOKEN:-}")
        
        if [ $? -eq 0 ] && [ -n "$API_RESPONSE" ]; then
            # Export variables from API response
            eval "$(echo "$API_RESPONSE" | jq -r 'to_entries | .[] | "export \(.key)=\(.value)"')"
            echo "✅ Environment variables loaded from API"
        else
            echo "⚠️ Failed to load variables from API, using defaults"
            source "${SCRIPT_DIR}/admin_vars.sh"
        fi
    else
        echo "⚠️ API_URL not set, using defaults"
        source "${SCRIPT_DIR}/admin_vars.sh"
    fi
    
    # Validate all required variables
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
    
    case "${BUILD_MODE:-}" in
        "basic_apk")
            echo "Configuring Basic APK build..."
            export PUSH_NOTIFY="false"
            export KEY_STORE=""
            export OUTPUT_TYPES="apk"
            ;;
        "firebase_apk")
            echo "Configuring Firebase APK build..."
            export PUSH_NOTIFY="true"
            export KEY_STORE=""
            export OUTPUT_TYPES="apk"
            ;;
        "full_release")
            echo "Configuring Full Release build..."
            export PUSH_NOTIFY="true"
            export OUTPUT_TYPES="apk,aab"
            ;;
        "aab_only")
            echo "Configuring AAB Only build..."
            export PUSH_NOTIFY="false"
            export OUTPUT_TYPES="aab"
            ;;
        *)
            handle_build_error "Invalid build mode: ${BUILD_MODE:-}" 1 "$0" "${LINENO:-}"
            ;;
    esac
    
    echo "✅ Build mode configured: ${BUILD_MODE:-}"
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

# Main build process
main() {
    echo "🚀 Starting Android build process..."
    
    # Load environment variables
    load_env_variables
    
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
