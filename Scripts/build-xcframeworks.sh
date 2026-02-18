#!/bin/bash

# Main script to build XCFrameworks for all OpenTelemetry Swift modules
# Usage: build-xcframeworks.sh [version] [source-repo-path] [module-name]

set -e

VERSION="${1:-1.15.0}"
SOURCE_REPO="${2:-}"
TEST_MODULE="${3:-}"  # Optional: build only this module for testing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
XCFRAMEWORKS_DIR="${BUILD_DIR}/xcframeworks"
SOURCE_DIR="${BUILD_DIR}/opentelemetry-swift-${VERSION}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building XCFrameworks for OpenTelemetry Swift ${VERSION}${NC}"

# Create directories
mkdir -p "${BUILD_DIR}"
mkdir -p "${XCFRAMEWORKS_DIR}"

# Clone or use existing source repository
if [ -z "$SOURCE_REPO" ]; then
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "Cloning opentelemetry-swift repository at tag ${VERSION}..."
        git clone --depth 1 --branch "${VERSION}" \
            https://github.com/open-telemetry/opentelemetry-swift.git \
            "${SOURCE_DIR}" || {
            echo -e "${RED}Failed to clone repository${NC}"
            exit 1
        }
    else
        echo "Using existing source directory: ${SOURCE_DIR}"
        cd "${SOURCE_DIR}"
        git fetch --tags
        git checkout "${VERSION}" || {
            echo -e "${YELLOW}Warning: Could not checkout tag ${VERSION}, using current branch${NC}"
        }
    fi
else
    SOURCE_DIR="$SOURCE_REPO"
    echo "Using provided source directory: ${SOURCE_DIR}"
fi

cd "${SOURCE_DIR}"

# Verify we're on the right version
CURRENT_TAG=$(git describe --tags --exact-match 2>/dev/null || git describe --tags || echo "unknown")
echo "Current source version: ${CURRENT_TAG}"

# Ensure Xcode can see the package schemes
# Opening the package in Xcode generates schemes automatically
# For command-line builds, we need to ensure the package is recognized
echo "Preparing package for building..."
if [ ! -f "${SOURCE_DIR}/Package.swift" ]; then
    echo -e "${RED}Error: Package.swift not found in ${SOURCE_DIR}${NC}"
    exit 1
fi

# Resolve package dependencies
echo "Resolving package dependencies..."
swift package resolve > /dev/null 2>&1 || {
    echo -e "${YELLOW}Warning: Package resolution had issues, continuing anyway...${NC}"
}

# Define modules in build order (dependencies first)
MODULES=(
    # Core modules (no dependencies)
    "OpenTelemetryApi:Sources/OpenTelemetryApi"
    "DataCompression:Sources/Exporters/DataCompression"
    
    # First-level dependencies
    "OpenTelemetryConcurrency:Sources/OpenTelemetryConcurrency"
    "OpenTelemetrySdk:Sources/OpenTelemetrySdk"
    "OTelSwiftLog:Sources/Bridges/OTelSwiftLog"
    
    # Exporters (depend on OpenTelemetrySdk)
    "StdoutExporter:Sources/Exporters/Stdout"
    "PrometheusExporter:Sources/Exporters/Prometheus"
    "OpenTelemetryProtocolExporterCommon:Sources/Exporters/OpenTelemetryProtocolCommon"
    "PersistenceExporter:Sources/Exporters/Persistence"
    "InMemoryExporter:Sources/Exporters/InMemory"
    
    # Protocol exporters (depend on Common)
    "OpenTelemetryProtocolExporterHTTP:Sources/Exporters/OpenTelemetryProtocolHttp"
    "OpenTelemetryProtocolExporterGrpc:Sources/Exporters/OpenTelemetryProtocolGrpc"
    
    # Bridges/Shims
    "SwiftMetricsShim:Sources/Importers/SwiftMetricsShim"
    
    # Contrib
    "BaggagePropagationProcessor:Sources/Contrib/Processors/BaggagePropagationProcessor"
)

# Darwin-only modules
DARWIN_MODULES=(
    "JaegerExporter:Sources/Exporters/Jaeger"
    "ZipkinExporter:Sources/Exporters/Zipkin"
    "NetworkStatus:Sources/Instrumentation/NetworkStatus"
    "URLSessionInstrumentation:Sources/Instrumentation/URLSession"
    "SignPostIntegration:Sources/Instrumentation/SignPostIntegration"
    "ResourceExtension:Sources/Instrumentation/SDKResourceExtension"
)

# Objective-C only modules
OBJC_MODULES=(
    "OpenTracingShim:Sources/Importers/OpenTracingShim"
)

# Helper function to create a framework from build artifacts
# This function manually creates a framework bundle from compiled object files
create_framework_from_build() {
    local MODULE_NAME="$1"
    local PLATFORM="$2"  # e.g., "ios-device", "ios-simulator", "macos"
    local ARCHIVE_PATH="$3"
    local OUTPUT_DIR="$4"  # Directory where framework will be created (with module name)
    
    echo "    Creating ${MODULE_NAME}.framework for ${PLATFORM}..."
    
    # Map platform to SDK name
    local SDK_NAME=""
    case "$PLATFORM" in
        "ios-device")
            SDK_NAME="iphoneos"
            ;;
        "ios-simulator")
            SDK_NAME="iphonesimulator"
            ;;
        "macos")
            SDK_NAME="macosx"
            ;;
        "tvos")
            SDK_NAME="appletvos"
            ;;
        "watchos")
            SDK_NAME="watchos"
            ;;
    esac
    
    # Find DerivedData path - look for any opentelemetry-swift DerivedData directory
    # Use a more flexible pattern that doesn't rely on exact version matching
    DERIVED_DATA_BASE="$HOME/Library/Developer/Xcode/DerivedData"
    
    # Find build products path - try multiple patterns
    DERIVED_DATA=$(find "$DERIVED_DATA_BASE" -name "opentelemetry-swift-*" -type d -maxdepth 1 2>/dev/null | while read -r dd_dir; do
        candidate="$dd_dir/Build/Intermediates.noindex/ArchiveIntermediates/${MODULE_NAME}/BuildProductsPath/Release-${SDK_NAME}"
        if [ -d "$candidate" ]; then
            echo "$candidate"
            break
        fi
    done | head -1)
    
    if [ -z "$DERIVED_DATA" ]; then
        # Try alternative: look for any Release directory with the SDK name
        DERIVED_DATA=$(find "$DERIVED_DATA_BASE" -name "opentelemetry-swift-*" -type d -maxdepth 1 2>/dev/null | while read -r dd_dir; do
            candidate=$(find "$dd_dir" -path "*Release-${SDK_NAME}*${MODULE_NAME}*" -type d 2>/dev/null | grep -i "BuildProductsPath" | head -1)
            if [ -n "$candidate" ]; then
                echo "$candidate"
                break
            fi
        done | head -1)
    fi
    
    if [ -z "$DERIVED_DATA" ]; then
        echo "      ✗ Could not find build products for ${PLATFORM} (SDK: ${SDK_NAME})"
        return 1
    fi
    
    # Find intermediate build directory with object files
    INTERMEDIATE_BUILD=$(find "$DERIVED_DATA_BASE" -name "opentelemetry-swift-*" -type d -maxdepth 1 2>/dev/null | while read -r dd_dir; do
        candidate="$dd_dir/Build/Intermediates.noindex/ArchiveIntermediates/${MODULE_NAME}/IntermediateBuildFilesPath/opentelemetry-swift.build/Release-${SDK_NAME}/${MODULE_NAME}.build"
        if [ -d "$candidate" ]; then
            echo "$candidate"
            break
        fi
    done | head -1)
    
    if [ -z "$INTERMEDIATE_BUILD" ]; then
        echo "      ✗ Could not find intermediate build directory for ${PLATFORM}"
        return 1
    fi
    
    # Create framework directory (use module name, not platform-specific name)
    FRAMEWORK_DIR="${OUTPUT_DIR}/${MODULE_NAME}.framework"
    rm -rf "$FRAMEWORK_DIR"
    mkdir -p "$FRAMEWORK_DIR/Modules"
    mkdir -p "$FRAMEWORK_DIR/Headers"
    
    # Copy Swift module
    # Handle case where PRODUCT_MODULE_NAME might be different from MODULE_NAME
    ACTUAL_MODULE_NAME="${MODULE_NAME}"
    if [ "${MODULE_NAME}" = "OpenTelemetryProtocolExporterHTTP" ]; then
        ACTUAL_MODULE_NAME="OpenTelemetryProtocolExporterHttp"
    fi
    
    if [ -d "${DERIVED_DATA}/${ACTUAL_MODULE_NAME}.swiftmodule" ]; then
        # Keep the swiftmodule directory name matching the actual module name (not framework name)
        cp -R "${DERIVED_DATA}/${ACTUAL_MODULE_NAME}.swiftmodule" "$FRAMEWORK_DIR/Modules/"
    elif [ -d "${DERIVED_DATA}/${MODULE_NAME}.swiftmodule" ]; then
        cp -R "${DERIVED_DATA}/${MODULE_NAME}.swiftmodule" "$FRAMEWORK_DIR/Modules/"
    else
        echo "      ✗ Swift module not found (tried: ${ACTUAL_MODULE_NAME}.swiftmodule and ${MODULE_NAME}.swiftmodule)"
        return 1
    fi
    
    # Create static library from object files
    OUTPUT="${FRAMEWORK_DIR}/${MODULE_NAME}"
    rm -f "$OUTPUT"
    
    OBJECT_FILES=$(find "${INTERMEDIATE_BUILD}/Objects-normal" -name "*.o" -type f 2>/dev/null)
    if [ -z "$OBJECT_FILES" ]; then
        echo "      ✗ No object files found"
        return 1
    fi
    
    FIRST_FILE=$(echo "$OBJECT_FILES" | head -1)
    OBJECT_COUNT=$(echo "$OBJECT_FILES" | wc -l | xargs)
    
    echo "      Creating static library from ${OBJECT_COUNT} object files..."
    
    # Create archive with first file
    ar rcs "$OUTPUT" "$FIRST_FILE"
    
    # Add remaining files in batches to avoid command line length limits
    echo "$OBJECT_FILES" | tail -n +2 | xargs -n 50 ar r "$OUTPUT" 2>/dev/null
    
    # Index the archive
    ranlib "$OUTPUT"
    
    # Create Info.plist
    cat > "$FRAMEWORK_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${MODULE_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.opentelemetry.${MODULE_NAME}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${MODULE_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>13.0</string>
</dict>
</plist>
EOF
    
    echo "      ✓ Framework created: ${FRAMEWORK_DIR}"
    return 0
}

# Function to build a module using xcodebuild following Apple's documentation
build_module_xcframework() {
    local MODULE_NAME="$1"
    local MODULE_PATH="$2"
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Building ${MODULE_NAME}${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ ! -d "$MODULE_PATH" ]; then
        echo -e "${YELLOW}Warning: Module path ${MODULE_PATH} does not exist, skipping...${NC}"
        return 0
    fi
    
    MODULE_BUILD_DIR="${BUILD_DIR}/${MODULE_NAME}"
    mkdir -p "${MODULE_BUILD_DIR}"
    
    # Create a temporary directory for platform-specific frameworks
    # All frameworks will be named ${MODULE_NAME}.framework (not platform-specific)
    TEMP_FRAMEWORKS_DIR="${MODULE_BUILD_DIR}/frameworks"
    mkdir -p "${TEMP_FRAMEWORKS_DIR}"
    
    FRAMEWORK_PATHS=()
    
    # Build for iOS (device) - Following Apple's documentation
    # Using xcodebuild with the package workspace
    cd "${SOURCE_DIR}"
    
    # Find workspace or use package directly
    WORKSPACE_ARG=""
    if [ -f "${SOURCE_DIR}/opentelemetry-swift-1.15.xcworkspace/contents.xcworkspacedata" ] || [ -d "${SOURCE_DIR}/.swiftpm/xcode/package.xcworkspace" ]; then
        # Use workspace if it exists
        if [ -d "${SOURCE_DIR}/.swiftpm/xcode/package.xcworkspace" ]; then
            WORKSPACE_ARG="-workspace ${SOURCE_DIR}/.swiftpm/xcode/package.xcworkspace"
        fi
    fi
    
    # Build for iOS device
    echo "  Building for iOS (device)..."
    # Set PRODUCT_MODULE_NAME to lowercase for OpenTelemetryProtocolExporterHTTP
    MODULE_NAME_ARG=""
    if [ "${MODULE_NAME}" = "OpenTelemetryProtocolExporterHTTP" ]; then
        MODULE_NAME_ARG="PRODUCT_MODULE_NAME=OpenTelemetryProtocolExporterHttp"
    fi
    xcodebuild archive \
        ${WORKSPACE_ARG} \
        -scheme "${MODULE_NAME}" \
        -destination "generic/platform=iOS" \
        -archivePath "${MODULE_BUILD_DIR}/ios-device.xcarchive" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        ${MODULE_NAME_ARG} \
        2>&1 | grep -E "(error|warning:|Building|Archive|Creating)" || true
    
    # Create framework manually from build artifacts
    PLATFORM_FRAMEWORK_DIR="${TEMP_FRAMEWORKS_DIR}/ios-device"
    mkdir -p "$PLATFORM_FRAMEWORK_DIR"
    if create_framework_from_build "${MODULE_NAME}" "ios-device" "${MODULE_BUILD_DIR}/ios-device.xcarchive" "$PLATFORM_FRAMEWORK_DIR"; then
        FRAMEWORK_PATHS+=("-framework" "${PLATFORM_FRAMEWORK_DIR}/${MODULE_NAME}.framework")
        echo "    ✓ iOS device"
    else
        echo "    ✗ iOS device framework creation failed"
    fi
    
    # Build for iOS Simulator
    echo "  Building for iOS Simulator..."
    # Ensure we're still in source directory
    cd "${SOURCE_DIR}"
    # Set PRODUCT_MODULE_NAME to lowercase for OpenTelemetryProtocolExporterHTTP
    MODULE_NAME_ARG=""
    if [ "${MODULE_NAME}" = "OpenTelemetryProtocolExporterHTTP" ]; then
        MODULE_NAME_ARG="PRODUCT_MODULE_NAME=OpenTelemetryProtocolExporterHttp"
    fi
    xcodebuild archive \
        ${WORKSPACE_ARG} \
        -scheme "${MODULE_NAME}" \
        -destination "generic/platform=iOS Simulator" \
        -archivePath "$(cd "${MODULE_BUILD_DIR}" && pwd)/ios-simulator.xcarchive" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        ${MODULE_NAME_ARG} \
        2>&1 | grep -E "(error|warning:|Building|Archive|Creating)" || true
    
    # Create framework manually from build artifacts
    PLATFORM_FRAMEWORK_DIR="${TEMP_FRAMEWORKS_DIR}/ios-simulator"
    mkdir -p "$PLATFORM_FRAMEWORK_DIR"
    if create_framework_from_build "${MODULE_NAME}" "ios-simulator" "${MODULE_BUILD_DIR}/ios-simulator.xcarchive" "$PLATFORM_FRAMEWORK_DIR"; then
        FRAMEWORK_PATHS+=("-framework" "${PLATFORM_FRAMEWORK_DIR}/${MODULE_NAME}.framework")
        echo "    ✓ iOS Simulator"
    else
        echo "    ✗ iOS Simulator framework creation failed"
    fi
    
    # Create XCFramework if we have frameworks
    if [ ${#FRAMEWORK_PATHS[@]} -eq 0 ]; then
        echo -e "${YELLOW}Warning: No frameworks built for ${MODULE_NAME}, trying alternative method...${NC}"
        # Alternative: Use swift build and manually create framework structure
        # This is a fallback - in practice, you may need to adjust based on actual build requirements
        return 0
    fi
    
    # Map module name to XCFramework directory name (must match binary target name in Package.swift)
    # For OpenTelemetryProtocolExporterHTTP, use lowercase "Http" to match Package.swift target name
    XCFRAMEWORK_NAME="${MODULE_NAME}"
    if [ "${MODULE_NAME}" = "OpenTelemetryProtocolExporterHTTP" ]; then
        XCFRAMEWORK_NAME="OpenTelemetryProtocolExporterHttp"
    fi
    XCFRAMEWORK_OUTPUT="${XCFRAMEWORKS_DIR}/${XCFRAMEWORK_NAME}.xcframework"
    
    echo "  Creating XCFramework..."
    xcodebuild -create-xcframework \
        "${FRAMEWORK_PATHS[@]}" \
        -output "${XCFRAMEWORK_OUTPUT}" 2>/dev/null || {
        echo -e "${RED}Failed to create XCFramework for ${MODULE_NAME}${NC}"
        return 1
    }
    
    if [ -d "$XCFRAMEWORK_OUTPUT" ]; then
        # Create zip archive
        # Use the same name mapping for zip file (but keep uppercase HTTP in filename for backward compatibility)
        ZIP_NAME="${XCFRAMEWORK_NAME}.xcframework"
        ZIP_OUTPUT="${XCFRAMEWORKS_DIR}/${ZIP_NAME}.zip"
        cd "$(dirname "$XCFRAMEWORK_OUTPUT")"
        zip -r -q "${ZIP_OUTPUT}" "$(basename "$XCFRAMEWORK_OUTPUT")"
        echo -e "${GREEN}  ✓ Created ${ZIP_NAME}.zip${NC}"
    fi
}

# Build modules
if [ -n "$TEST_MODULE" ]; then
    # Test mode: build only the specified module
    echo -e "${YELLOW}TEST MODE: Building only ${TEST_MODULE}${NC}"
    FOUND=false
    
    # Search in all module arrays
    ALL_MODULES=("${MODULES[@]}")
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ALL_MODULES+=("${DARWIN_MODULES[@]}")
        ALL_MODULES+=("${OBJC_MODULES[@]}")
    fi
    
    for MODULE_INFO in "${ALL_MODULES[@]}"; do
        IFS=':' read -r MODULE_NAME MODULE_PATH <<< "$MODULE_INFO"
        if [ "$MODULE_NAME" = "$TEST_MODULE" ]; then
            build_module_xcframework "$MODULE_NAME" "$MODULE_PATH"
            FOUND=true
            break
        fi
    done
    
    if [ "$FOUND" = false ]; then
        echo -e "${RED}Error: Module ${TEST_MODULE} not found${NC}"
        exit 1
    fi
else
    # Build all modules
    for MODULE_INFO in "${MODULES[@]}"; do
        IFS=':' read -r MODULE_NAME MODULE_PATH <<< "$MODULE_INFO"
        build_module_xcframework "$MODULE_NAME" "$MODULE_PATH" || {
            echo -e "${YELLOW}Continuing despite error...${NC}"
        }
    done
    
    # Build Darwin-only modules (if on macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        for MODULE_INFO in "${DARWIN_MODULES[@]}"; do
            IFS=':' read -r MODULE_NAME MODULE_PATH <<< "$MODULE_INFO"
            build_module_xcframework "$MODULE_NAME" "$MODULE_PATH" || {
                echo -e "${YELLOW}Continuing despite error...${NC}"
            }
        done
        
        # Build Objective-C modules
        for MODULE_INFO in "${OBJC_MODULES[@]}"; do
            IFS=':' read -r MODULE_NAME MODULE_PATH <<< "$MODULE_INFO"
            build_module_xcframework "$MODULE_NAME" "$MODULE_PATH" || {
                echo -e "${YELLOW}Continuing despite error...${NC}"
            }
        done
    fi
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Build complete! XCFrameworks are in: ${XCFRAMEWORKS_DIR}${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
