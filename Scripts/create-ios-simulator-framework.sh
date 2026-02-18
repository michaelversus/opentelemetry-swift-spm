#!/bin/bash

# Script to build and create iOS Simulator framework for OpenTelemetryApi

set -e

MODULE_NAME="OpenTelemetryApi"
SOURCE_DIR="/Users/m.karagiorgos/opentelemetry-swift-spm/build/opentelemetry-swift-1.15.0"
BUILD_DIR="/Users/m.karagiorgos/opentelemetry-swift-spm/build"

echo "Building ${MODULE_NAME} for iOS Simulator..."

cd "$SOURCE_DIR"

# Build for iOS Simulator
xcodebuild archive \
    -workspace .swiftpm/xcode/package.xcworkspace \
    -scheme "$MODULE_NAME" \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "${BUILD_DIR}/${MODULE_NAME}-ios-simulator.xcarchive" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    > /dev/null 2>&1

echo "Build complete. Finding artifacts..."

# Find DerivedData path (it will be similar but for simulator)
DERIVED_DATA_BASE="$HOME/Library/Developer/Xcode/DerivedData/opentelemetry-swift-1.15-"
DERIVED_DATA=$(find "$DERIVED_DATA_BASE"* -path "*/ArchiveIntermediates/${MODULE_NAME}/BuildProductsPath/Release-iphonesimulator" -type d 2>/dev/null | head -1)

if [ -z "$DERIVED_DATA" ]; then
    echo "Error: Could not find simulator build products"
    echo "Trying alternative location..."
    DERIVED_DATA=$(find "$DERIVED_DATA_BASE"* -path "*iphonesimulator*${MODULE_NAME}*" -type d 2>/dev/null | head -1)
fi

if [ -z "$DERIVED_DATA" ]; then
    echo "Error: Could not locate simulator build artifacts"
    exit 1
fi

echo "Found build products at: $DERIVED_DATA"

BUILD_PRODUCTS="$DERIVED_DATA"
INTERMEDIATE_BUILD=$(find "$DERIVED_DATA_BASE"* -path "*/ArchiveIntermediates/${MODULE_NAME}/IntermediateBuildFilesPath/opentelemetry-swift.build/Release-iphonesimulator/${MODULE_NAME}.build" -type d 2>/dev/null | head -1)

if [ -z "$INTERMEDIATE_BUILD" ]; then
    echo "Error: Could not find intermediate build directory"
    exit 1
fi

echo "Creating framework..."

# Create framework directory with module name (not platform-specific)
# This is required for xcodebuild -create-xcframework
FRAMEWORK_DIR="${BUILD_DIR}/simulator/${MODULE_NAME}.framework"
rm -rf "$FRAMEWORK_DIR"
mkdir -p "$(dirname "$FRAMEWORK_DIR")"
mkdir -p "$FRAMEWORK_DIR/Modules"
mkdir -p "$FRAMEWORK_DIR/Headers"

# Copy Swift module
if [ -d "${BUILD_PRODUCTS}/${MODULE_NAME}.swiftmodule" ]; then
    cp -R "${BUILD_PRODUCTS}/${MODULE_NAME}.swiftmodule" "$FRAMEWORK_DIR/Modules/"
    echo "✓ Swift module copied"
else
    echo "Error: Swift module not found"
    exit 1
fi

# Create static library
OUTPUT="${FRAMEWORK_DIR}/${MODULE_NAME}"
rm -f "$OUTPUT"

FIRST_FILE=$(find "${INTERMEDIATE_BUILD}/Objects-normal" -name "*.o" -type f | head -1)

if [ -z "$FIRST_FILE" ]; then
    echo "Error: No object files found"
    exit 1
fi

# iOS Simulator can have multiple architectures (x86_64 for Intel Macs, arm64 for Apple Silicon)
# We need to build separate libraries for each architecture and combine with lipo
ARCH_DIRS=$(find "${INTERMEDIATE_BUILD}/Objects-normal" -type d -mindepth 1 -maxdepth 1 2>/dev/null)

if [ -z "$ARCH_DIRS" ]; then
    echo "Error: No architecture directories found"
    exit 1
fi

# Build static library for each architecture, then combine with lipo
TEMP_LIBS=()
for ARCH_DIR in $ARCH_DIRS; do
    ARCH=$(basename "$ARCH_DIR")
    TEMP_LIB="/tmp/${MODULE_NAME}_${ARCH}.a"
    rm -f "$TEMP_LIB"
    
    OBJECT_FILES=$(find "$ARCH_DIR" -name "*.o" -type f)
    if [ -z "$OBJECT_FILES" ]; then
        continue
    fi
    
    FIRST_FILE=$(echo "$OBJECT_FILES" | head -1)
    OBJECT_COUNT=$(echo "$OBJECT_FILES" | wc -l | xargs)
    
    echo "  Creating ${ARCH} library from ${OBJECT_COUNT} object files..."
    
    # Create archive with first file
    ar rcs "$TEMP_LIB" "$FIRST_FILE"
    
    # Add remaining files in batches
    echo "$OBJECT_FILES" | tail -n +2 | xargs -n 50 ar r "$TEMP_LIB" 2>/dev/null
    
    # Index the archive
    ranlib "$TEMP_LIB"
    
    TEMP_LIBS+=("$TEMP_LIB")
done

# Combine architectures with lipo
if [ ${#TEMP_LIBS[@]} -eq 0 ]; then
    echo "Error: No static libraries created"
    exit 1
elif [ ${#TEMP_LIBS[@]} -eq 1 ]; then
    # Single architecture, just copy
    cp "${TEMP_LIBS[0]}" "$OUTPUT"
else
    # Multiple architectures, combine with lipo
    echo "  Combining architectures with lipo..."
    lipo -create "${TEMP_LIBS[@]}" -output "$OUTPUT"
fi

# Clean up temp files
rm -f "${TEMP_LIBS[@]}"

echo "✓ Static library created (architectures: $(lipo -info "$OUTPUT" 2>/dev/null | cut -d: -f3 | xargs || echo "unknown"))"

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
    <string>1.15.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>13.0</string>
</dict>
</plist>
EOF

echo "✓ Info.plist created"
echo ""
echo "Framework created: $FRAMEWORK_DIR"
ls -lh "$OUTPUT"
