# Manual Framework Creation Guide

This guide walks through manually creating an XCFramework for `OpenTelemetryApi` module, which can then be automated for all modules.

## Module: OpenTelemetryApi

**Why this module?**
- No dependencies (simplest to start with)
- Core module that others depend on
- Good test case for the process

## Prerequisites

- Xcode installed
- Source repository cloned at version 1.15.0
- Terminal access

## Step-by-Step Process

### Step 1: Build the Module for iOS Device

```bash
cd /Users/m.karagiorgos/opentelemetry-swift-spm/build/opentelemetry-swift-1.15.0

# Build for iOS device (arm64)
xcodebuild archive \
    -workspace .swiftpm/xcode/package.xcworkspace \
    -scheme OpenTelemetryApi \
    -destination "generic/platform=iOS" \
    -archivePath ../OpenTelemetryApi-ios-device.xcarchive \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO
```

### Step 2: Locate Built Artifacts

After building, find the built products:

```bash
# Find the DerivedData location
DERIVED_DATA=$(xcodebuild -showBuildSettings \
    -workspace .swiftpm/xcode/package.xcworkspace \
    -scheme OpenTelemetryApi \
    -destination "generic/platform=iOS" 2>/dev/null | \
    grep -m1 "BUILD_DIR" | cut -d'=' -f2 | xargs)

# Or check the default DerivedData location
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/opentelemetry-swift-1.15-*/Build/Intermediates.noindex/ArchiveIntermediates/OpenTelemetryApi"

# Find Swift modules
find "$DERIVED_DATA" -path "*/BuildProductsPath/Release-iphoneos/OpenTelemetryApi.swiftmodule" -type d

# Find static library (if built)
find "$DERIVED_DATA" -name "libOpenTelemetryApi.a" -o -name "OpenTelemetryApi.a"
```

### Step 3: Create Framework Structure

Create the framework directory structure:

```bash
FRAMEWORK_DIR="../OpenTelemetryApi-ios-device.framework"
mkdir -p "$FRAMEWORK_DIR"
mkdir -p "$FRAMEWORK_DIR/Modules"
mkdir -p "$FRAMEWORK_DIR/Headers"
```

### Step 4: Copy Swift Modules

Copy the Swift module files:

```bash
# Find the Swift module directory
SWIFT_MODULE=$(find "$DERIVED_DATA" -path "*/BuildProductsPath/Release-iphoneos/OpenTelemetryApi.swiftmodule" -type d | head -1)

# Copy the entire Swift module directory
cp -R "$SWIFT_MODULE" "$FRAMEWORK_DIR/Modules/"

# Verify
ls -la "$FRAMEWORK_DIR/Modules/OpenTelemetryApi.swiftmodule/"
```

You should see files like:
- `arm64-apple-ios.swiftmodule`
- `arm64-apple-ios.swiftinterface`
- `arm64-apple-ios.private.swiftinterface`
- `Project/` directory with module map

### Step 5: Create or Copy the Binary

For a static library, you have two options:

**Option A: Use the static library directly**
```bash
# Find the static library
STATIC_LIB=$(find "$DERIVED_DATA" -name "libOpenTelemetryApi.a" | head -1)

# Create a dynamic library from the static library (if needed)
# Or copy the static library
cp "$STATIC_LIB" "$FRAMEWORK_DIR/OpenTelemetryApi"
```

**Option B: Build as dynamic library**
Modify the build to create a dynamic library by adding build settings:
```bash
xcodebuild archive \
    -workspace .swiftpm/xcode/package.xcworkspace \
    -scheme OpenTelemetryApi \
    -destination "generic/platform=iOS" \
    -archivePath ../OpenTelemetryApi-ios-device.xcarchive \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    MACH_O_TYPE=mh_dylib \
    DYLIB_INSTALL_NAME_BASE="@rpath" \
    INSTALL_PATH="@rpath"
```

### Step 6: Create Info.plist

Create the framework's Info.plist:

```bash
cat > "$FRAMEWORK_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>OpenTelemetryApi</string>
    <key>CFBundleIdentifier</key>
    <string>com.opentelemetry.OpenTelemetryApi</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OpenTelemetryApi</string>
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
```

### Step 7: Create Headers Directory (if needed)

For Swift-only frameworks, headers are auto-generated. But create the directory structure:

```bash
# Headers are usually in the Swift module's Project directory
# Copy if they exist
if [ -d "$FRAMEWORK_DIR/Modules/OpenTelemetryApi.swiftmodule/Project" ]; then
    cp -R "$FRAMEWORK_DIR/Modules/OpenTelemetryApi.swiftmodule/Project" "$FRAMEWORK_DIR/Headers/" 2>/dev/null || true
fi
```

### Step 8: Verify Framework Structure

Check that your framework has the correct structure:

```bash
tree "$FRAMEWORK_DIR" -L 2
```

Expected structure:
```
OpenTelemetryApi-ios-device.framework/
├── Info.plist
├── OpenTelemetryApi (binary)
├── Modules/
│   └── OpenTelemetryApi.swiftmodule/
│       ├── arm64-apple-ios.swiftmodule
│       ├── arm64-apple-ios.swiftinterface
│       └── Project/
└── Headers/ (optional)
```

### Step 9: Build for iOS Simulator

Repeat steps 1-8 for iOS Simulator:

```bash
xcodebuild archive \
    -workspace .swiftpm/xcode/package.xcworkspace \
    -scheme OpenTelemetryApi \
    -destination "generic/platform=iOS Simulator" \
    -archivePath ../OpenTelemetryApi-ios-simulator.xcarchive \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO

# Create simulator framework (same steps as above)
# Name it: OpenTelemetryApi-ios-simulator.framework
```

### Step 10: Create XCFramework

Once you have frameworks for multiple platforms, combine them:

```bash
cd /Users/m.karagiorgos/opentelemetry-swift-spm/build

xcodebuild -create-xcframework \
    -framework OpenTelemetryApi-ios-device.framework \
    -framework OpenTelemetryApi-ios-simulator.framework \
    -output xcframeworks/OpenTelemetryApi.xcframework
```

### Step 11: Verify XCFramework

```bash
# Check structure
ls -la xcframeworks/OpenTelemetryApi.xcframework/

# Should show:
# - ios-arm64/
# - ios-arm64_x86_64-simulator/
```

### Step 12: Create Zip Archive

```bash
cd xcframeworks
zip -r OpenTelemetryApi.xcframework.zip OpenTelemetryApi.xcframework
```

## Quick Test Script

Here's a complete script to test with OpenTelemetryApi:

```bash
#!/bin/bash
set -e

SOURCE_DIR="/Users/m.karagiorgos/opentelemetry-swift-spm/build/opentelemetry-swift-1.15.0"
BUILD_DIR="/Users/m.karagiorgos/opentelemetry-swift-spm/build"
MODULE_NAME="OpenTelemetryApi"

cd "$SOURCE_DIR"

echo "Building for iOS device..."
xcodebuild archive \
    -workspace .swiftpm/xcode/package.xcworkspace \
    -scheme "$MODULE_NAME" \
    -destination "generic/platform=iOS" \
    -archivePath "$BUILD_DIR/${MODULE_NAME}-ios-device.xcarchive" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    > /dev/null 2>&1

echo "Finding built artifacts..."
# Find DerivedData
ARCHIVE_PATH="$BUILD_DIR/${MODULE_NAME}-ios-device.xcarchive"
# The actual build products are in DerivedData, not in the archive
# We need to find them differently

echo "Check DerivedData location:"
echo "$HOME/Library/Developer/Xcode/DerivedData/opentelemetry-swift-1.15-*/Build/Intermediates.noindex/ArchiveIntermediates/${MODULE_NAME}/BuildProductsPath/Release-iphoneos/"
```

## Key Points to Document

As you go through this process, note:

1. **Where are the Swift modules located?** 
   - Usually in: `DerivedData/.../BuildProductsPath/Release-{platform}/{Module}.swiftmodule/`

2. **Where is the binary/library?**
   - Static library: `lib{Module}.a` or `{Module}.a`
   - Dynamic library: `lib{Module}.dylib` or `{Module}`

3. **What architecture files are created?**
   - iOS device: `arm64-apple-ios.*`
   - iOS Simulator: `arm64-apple-ios-simulator.*` or `x86_64-apple-ios-simulator.*`

4. **What's in the Swift module directory?**
   - `.swiftmodule` files (binary)
   - `.swiftinterface` files (text)
   - `.private.swiftinterface` files
   - `Project/` directory with module map

## Next Steps After Manual Creation

Once you've successfully created one framework manually:

1. Document the exact paths and file locations
2. Create a script function that automates this process
3. Test with another module (like `DataCompression` - also no dependencies)
4. Then automate for all modules

## Troubleshooting

**Issue: Can't find Swift modules**
- Check DerivedData path: `~/Library/Developer/Xcode/DerivedData/`
- Look for folders matching `opentelemetry-swift-1.15-*`
- Search for `.swiftmodule` directories

**Issue: Framework structure is wrong**
- Ensure `Info.plist` is at the root
- Binary should be executable
- Modules directory should contain the `.swiftmodule` folder

**Issue: XCFramework creation fails**
- Ensure all frameworks have the same structure
- Check that binaries are for correct architectures
- Verify Info.plist is correct
