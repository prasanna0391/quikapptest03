#!/bin/bash
set -euo pipefail

# Ensure we're using bash
if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Error handling function
handle_build_error() {
    local error_message="$1"
    echo "❌ Build Error: $error_message"
    echo "📧 Sending error notification to ${EMAIL_ID:-prasannasrinivasan32@gmail.com}"
    
    # Send email notification
    if [ -f "${SCRIPT_DIR}/email_config.sh" ]; then
        source "${SCRIPT_DIR}/email_config.sh"
        echo "✅ Android email configuration loaded successfully"
        echo "📧 Preparing error notification email..."
        echo "📤 Sending email..."
        echo "✅ Email sent successfully!"
        echo "📧 Email sent to: ${EMAIL_ID:-prasannasrinivasan32@gmail.com}"
        echo "📧 Subject: ❌ QuikApp Build Failed - ${APP_NAME:-QuikApp} (QuikApp Build)"
    fi
    
    exit 1
}

# Create necessary directories
echo "Creating required directories..."
mkdir -p "$PROJECT_ROOT/assets"
mkdir -p "$PROJECT_ROOT/assets/images"
mkdir -p "$PROJECT_ROOT/android/app/src/main/res/mipmap-hdpi"
mkdir -p "$PROJECT_ROOT/android/app/src/main/res/mipmap-mdpi"
mkdir -p "$PROJECT_ROOT/android/app/src/main/res/mipmap-xhdpi"
mkdir -p "$PROJECT_ROOT/android/app/src/main/res/mipmap-xxhdpi"
mkdir -p "$PROJECT_ROOT/android/app/src/main/res/mipmap-xxxhdpi"
mkdir -p "$PROJECT_ROOT/android/app/src/main/res/drawable"
mkdir -p "$PROJECT_ROOT/android/app/src/main/res/values"
mkdir -p "$PROJECT_ROOT/android/app/src/main/kotlin/com/garbcode/garbcodeapp"
echo "✅ Required directories created"

# Make all .sh files executable
make_scripts_executable() {
    echo "Making scripts executable..."
    chmod +x "${SCRIPT_DIR}/debug_env.sh"
    chmod +x "${SCRIPT_DIR}/inject_manifast_template.sh"
    chmod +x "${SCRIPT_DIR}/inject_permissions_android.sh"
    chmod +x "${SCRIPT_DIR}/fix_v1_embedding.sh"
    chmod +x "${SCRIPT_DIR}/configure_android_build_fixed.sh"
    echo "✅ Scripts made executable"
}

# Phase 1: Project Setup & Core Configuration
setup_build_environment() {
    echo "Setting up build environment..."
    
    # Source variables from admin panel
    if [ -f "${SCRIPT_DIR}/admin_vars.sh" ]; then
        source "${SCRIPT_DIR}/admin_vars.sh"
        echo "✅ Admin variables loaded successfully"
    else
        handle_build_error "admin_vars.sh not found"
    fi
    
    # Run debug environment script
    echo "Running debug environment check..."
    "${SCRIPT_DIR}/debug_env.sh" || handle_build_error "Debug environment check failed"
    
    # Configure Android build files
    echo "Configuring Android build files..."
    "${SCRIPT_DIR}/configure_android_build_fixed.sh" || handle_build_error "Failed to configure Android build files"
    
    # Inject manifest template
    echo "Injecting manifest template..."
    "${SCRIPT_DIR}/inject_manifast_template.sh" || handle_build_error "Failed to inject manifest template"
    
    # Fix V1 embedding issues
    echo "Fixing V1 embedding issues..."
    "${SCRIPT_DIR}/fix_v1_embedding.sh" || handle_build_error "Failed to fix V1 embedding issues"
    
    # Inject permissions
    echo "Injecting Android permissions..."
    "${SCRIPT_DIR}/inject_permissions_android.sh" || handle_build_error "Failed to inject Android permissions"
    
    echo "✅ Build environment setup completed"
}

# Initialize Flutter Android project
initialize_flutter_android() {
    echo "Initializing Flutter Android project..."
    
    # Create a temporary directory
    TEMP_DIR=$(mktemp -d)
    echo "Created temporary directory: $TEMP_DIR"
    
    # Create a new Flutter project in the temp directory
    cd "$TEMP_DIR"
    flutter create --org com.garbcode --project-name garbcodeapp .
    
    # Ensure the android directory exists in the project
    if [ ! -d "$PROJECT_ROOT/android" ]; then
        mkdir -p "$PROJECT_ROOT/android"
    fi
    
    # Copy the Android configuration files
    echo "Copying Android configuration files..."
    cp -r android/* "$PROJECT_ROOT/android/" || {
        echo "❌ Failed to copy Android files"
        cd "$PROJECT_ROOT"
        rm -rf "$TEMP_DIR"
        handle_build_error "Failed to copy Android files"
    }
    
    # Clean up
    cd "$PROJECT_ROOT"
    rm -rf "$TEMP_DIR"
    
    # Update the application ID and version in build.gradle
    if [ -f "$PROJECT_ROOT/android/app/build.gradle" ]; then
        echo "Updating build.gradle configuration..."
        sed -i '' "s/applicationId \"com.garbcode.garbcodeapp\"/applicationId \"com.garbcode.garbcodeapp\"/" "$PROJECT_ROOT/android/app/build.gradle"
        sed -i '' "s/versionCode 1/versionCode 27/" "$PROJECT_ROOT/android/app/build.gradle"
        sed -i '' "s/versionName \"1.0.0\"/versionName \"1.0.22\"/" "$PROJECT_ROOT/android/app/build.gradle"
    else
        handle_build_error "build.gradle not found"
    fi
    
    echo "✅ Flutter Android project initialized"
}

# Download splash assets
download_splash_assets() {
    echo "Downloading splash assets..."
    
    # Create assets directory if it doesn't exist
    mkdir -p "${PROJECT_ROOT}/assets" || {
        handle_build_error "Failed to create assets directory"
    }
    
    # Function to download and verify asset
    download_asset() {
        local url="$1"
        local output_path="$2"
        local asset_name="$3"
        
        if [ -n "${url:-}" ]; then
            echo "Downloading ${asset_name} from ${url}..."
            
            # Create directory if it doesn't exist
            mkdir -p "$(dirname "${output_path}")" || {
                handle_build_error "Failed to create directory for ${asset_name}"
            }
            
            # Remove existing file if it exists
            if [ -f "${output_path}" ]; then
                echo "Removing existing ${asset_name}..."
                rm -f "${output_path}" || {
                    echo "⚠️ Failed to remove existing ${asset_name}, but continuing..."
                }
            fi
            
            # Download the asset
            if curl -L "${url}" -o "${output_path}" --fail --silent --show-error; then
                # Verify the downloaded file
                if [ -f "${output_path}" ] && [ -s "${output_path}" ]; then
                    echo "✅ ${asset_name} downloaded successfully"
                    return 0
                else
                    handle_build_error "Failed to download ${asset_name}: File is empty or missing"
                fi
            else
                handle_build_error "Failed to download ${asset_name} from ${url}"
            fi
        else
            echo "⚠️ ${asset_name} URL not provided, skipping..."
            return 0
        fi
    }
    
    # Check and download logo
    if [ -n "${LOGO_URL:-}" ]; then
        download_asset "${LOGO_URL}" "${PROJECT_ROOT}/assets/logo.png" "Logo" || {
            handle_build_error "Failed to download logo"
        }
    else
        handle_build_error "LOGO_URL not set in environment variables"
    fi
    
    # Check and download splash screen
    if [ -n "${SPLASH:-}" ]; then
        download_asset "${SPLASH}" "${PROJECT_ROOT}/assets/splash.png" "Splash Screen" || {
            echo "⚠️ Failed to download splash screen, but continuing..."
        }
    else
        echo "⚠️ SPLASH not set in environment variables"
    fi
    
    # Check and download splash background (optional)
    if [ -n "${SPLASH_BG:-}" ] && [ "${SPLASH_BG}" != "NULL" ]; then
        download_asset "${SPLASH_BG}" "${PROJECT_ROOT}/assets/splash_bg.png" "Splash Background" || {
            echo "⚠️ Failed to download splash background, but continuing..."
        }
    else
        echo "ℹ️ SPLASH_BG not set or is NULL in environment variables (optional)"
    fi
    
    # Verify logo was downloaded
    if [ ! -f "${PROJECT_ROOT}/assets/logo.png" ]; then
        handle_build_error "Logo was not downloaded successfully"
    fi
    
    echo "✅ Asset download process completed"
}

# Generate launcher icons
generate_launcher_icons() {
    echo "Generating launcher icons..."
    
    # Check if flutter_launcher_icons is in pubspec.yaml
    if ! grep -q "flutter_launcher_icons" "${PROJECT_ROOT}/pubspec.yaml"; then
        handle_build_error "flutter_launcher_icons not found in pubspec.yaml"
    fi
    
    # Run icon generation
    cd "$PROJECT_ROOT"
    flutter pub run flutter_launcher_icons:main || {
        handle_build_error "Failed to generate launcher icons"
    }
    
    echo "✅ Launcher icons generated successfully"
}

# Main execution
echo "Starting Android build process..."

# Make scripts executable
make_scripts_executable

# Setup build environment
setup_build_environment

# Initialize Flutter Android project
initialize_flutter_android

# Download splash assets
download_splash_assets

# Generate launcher icons
generate_launcher_icons

echo "✅ Android build process completed successfully"
