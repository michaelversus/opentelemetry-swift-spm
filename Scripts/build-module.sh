#!/bin/bash

# Helper script to build an XCFramework for a single module
# Usage: build-module.sh <module-name> <source-dir> <output-dir>

set -e

MODULE_NAME="$1"
SOURCE_DIR="$2"
OUTPUT_DIR="$3"
BUILD_DIR="${OUTPUT_DIR}/build/${MODULE_NAME}"

if [ -z "$MODULE_NAME" ] || [ -z "$SOURCE_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 <module-name> <source-dir> <output-dir>"
    exit 1
fi

echo "Building XCFramework for ${MODULE_NAME}..."

# Create build directory
mkdir -p "${BUILD_DIR}"

# Platforms to build for
PLATFORMS=(
    "ios:iphoneos:arm64"
    "ios:iphonesimulator:arm64"
    "ios:iphonesimulator:x86_64"
    "macos:macosx:arm64"
    "macos:macosx:x86_64"
    "tvos:appletvos:arm64"
    "tvos:appletvsimulator:arm64"
    "tvos:appletvsimulator:x86_64"
    "watchos:watchos:arm64_32"
    "watchos:watchsimulator:arm64"
)

FRAMEWORK_PATHS=()

# Build for each platform
for PLATFORM_INFO in "${PLATFORMS[@]}"; do
    IFS=':' read -r PLATFORM SDK ARCH <<< "$PLATFORM_INFO"
    
    echo "  Building for ${PLATFORM} (${SDK}) ${ARCH}..."
    
    PLATFORM_BUILD_DIR="${BUILD_DIR}/${PLATFORM}-${ARCH}"
    mkdir -p "${PLATFORM_BUILD_DIR}"
    
    # Build the framework using xcodebuild
    xcodebuild archive \
        -scheme "${MODULE_NAME}" \
        -destination "generic/platform=${SDK}" \
        -archivePath "${PLATFORM_BUILD_DIR}/${MODULE_NAME}.xcarchive" \
        -derivedDataPath "${PLATFORM_BUILD_DIR}/DerivedData" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        -quiet || {
            echo "Warning: Failed to build ${MODULE_NAME} for ${PLATFORM} ${ARCH}, skipping..."
            continue
        }
    
    # Extract framework from archive
    FRAMEWORK_PATH="${PLATFORM_BUILD_DIR}/${MODULE_NAME}.xcarchive/Products/Library/Frameworks/${MODULE_NAME}.framework"
    
    if [ -d "$FRAMEWORK_PATH" ]; then
        FRAMEWORK_PATHS+=("-framework" "$FRAMEWORK_PATH")
        echo "    ✓ Built framework for ${PLATFORM} ${ARCH}"
    else
        echo "    ✗ Framework not found at ${FRAMEWORK_PATH}"
    fi
done

# Create XCFramework if we have at least one framework
if [ ${#FRAMEWORK_PATHS[@]} -eq 0 ]; then
    echo "Error: No frameworks were built successfully for ${MODULE_NAME}"
    exit 1
fi

XCFRAMEWORK_OUTPUT="${OUTPUT_DIR}/xcframeworks/${MODULE_NAME}.xcframework"

echo "  Creating XCFramework..."
xcodebuild -create-xcframework \
    "${FRAMEWORK_PATHS[@]}" \
    -output "${XCFRAMEWORK_OUTPUT}"

if [ -d "$XCFRAMEWORK_OUTPUT" ]; then
    echo "  ✓ Created XCFramework at ${XCFRAMEWORK_OUTPUT}"
    
    # Create zip archive
    ZIP_OUTPUT="${XCFRAMEWORK_OUTPUT}.zip"
    cd "$(dirname "$XCFRAMEWORK_OUTPUT")"
    zip -r "${ZIP_OUTPUT}" "$(basename "$XCFRAMEWORK_OUTPUT")" > /dev/null
    echo "  ✓ Created zip archive at ${ZIP_OUTPUT}"
else
    echo "  ✗ Failed to create XCFramework"
    exit 1
fi

echo "✓ Successfully built XCFramework for ${MODULE_NAME}"
