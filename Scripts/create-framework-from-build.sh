#!/bin/bash

# Helper script to create a framework from SPM build artifacts
# Usage: create-framework-from-build.sh <module-name> <platform> <derived-data-path>

set -e

MODULE_NAME="${1:-OpenTelemetryApi}"
PLATFORM="${2:-iphoneos}"
DERIVED_DATA="${3:-}"

if [ -z "$DERIVED_DATA" ]; then
    echo "Error: DerivedData path required"
    echo "Usage: $0 <module-name> <platform> <derived-data-path>"
    exit 1
fi

BUILD_PRODUCTS="${DERIVED_DATA}/BuildProductsPath/Release-${PLATFORM}"
INTERMEDIATE_BUILD="${DERIVED_DATA}/IntermediateBuildFilesPath/opentelemetry-swift.build/Release-${PLATFORM}/${MODULE_NAME}.build"

echo "Creating framework for ${MODULE_NAME} (${PLATFORM})"
echo "Build products: ${BUILD_PRODUCTS}"
echo "Intermediate build: ${INTERMEDIATE_BUILD}"

# Create framework directory
FRAMEWORK_DIR="${MODULE_NAME}-${PLATFORM}.framework"
rm -rf "$FRAMEWORK_DIR"
mkdir -p "$FRAMEWORK_DIR/Modules"
mkdir -p "$FRAMEWORK_DIR/Headers"

# Step 1: Copy Swift module
if [ -d "${BUILD_PRODUCTS}/${MODULE_NAME}.swiftmodule" ]; then
    echo "Copying Swift module..."
    cp -R "${BUILD_PRODUCTS}/${MODULE_NAME}.swiftmodule" "$FRAMEWORK_DIR/Modules/"
    echo "✓ Swift module copied"
else
    echo "Error: Swift module not found at ${BUILD_PRODUCTS}/${MODULE_NAME}.swiftmodule"
    exit 1
fi

# Step 2: Create static library from object files
echo "Creating static library from object files..."
OBJECT_FILES=$(find "${INTERMEDIATE_BUILD}/Objects-normal" -name "*.o" -type f)

if [ -z "$OBJECT_FILES" ]; then
    echo "Error: No object files found"
    exit 1
fi

# Count object files
OBJ_COUNT=$(echo "$OBJECT_FILES" | wc -l | xargs)
echo "Found ${OBJ_COUNT} object files"

# Create static library using ar (more reliable for many files)
STATIC_LIB="${FRAMEWORK_DIR}/${MODULE_NAME}"

# Remove existing archive if present
rm -f "$STATIC_LIB"

# Create empty archive first
ar rcs "$STATIC_LIB"

# Add all object files to the archive
# Using find with -exec and {} + batches files to avoid command line length issues
# ar r = replace/add files (creates archive if needed)
find "${INTERMEDIATE_BUILD}/Objects-normal" -name "*.o" -type f -exec ar r "$STATIC_LIB" {} +

# Write symbol table index
ranlib "$STATIC_LIB"

if [ -f "$STATIC_LIB" ]; then
    echo "✓ Static library created: $(du -h "$STATIC_LIB" | cut -f1)"
else
    echo "Error: Failed to create static library"
    exit 1
fi

# Step 3: Create Info.plist
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

# Step 4: Verify framework structure
echo ""
echo "Framework structure:"
tree "$FRAMEWORK_DIR" -L 2 || find "$FRAMEWORK_DIR" -type f | head -10

echo ""
echo "✓ Framework created: ${FRAMEWORK_DIR}"
echo "  Size: $(du -sh "$FRAMEWORK_DIR" | cut -f1)"
