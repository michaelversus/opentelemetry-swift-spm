#!/bin/bash

# Quick script to monitor the OpenTelemetryProtocolExporterCommon build

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Monitoring OpenTelemetryProtocolExporterCommon Build"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if build process is running
echo "1. Build Process Status:"
if ps aux | grep -E "xcodebuild.*OpenTelemetryProtocolExporter" | grep -v grep > /dev/null; then
    echo "   ✓ Build process is running"
    ps aux | grep -E "xcodebuild.*OpenTelemetryProtocolExporter" | grep -v grep | awk '{print "   PID:", $2, "CPU:", $3"%", "MEM:", $4"%"}'
else
    echo "   ✗ No active build process found"
fi
echo ""

# Check if XCFramework exists
echo "2. XCFramework Status:"
if [ -f "build/xcframeworks/OpenTelemetryProtocolExporterCommon.xcframework.zip" ]; then
    echo "   ✓ XCFramework created!"
    ls -lh build/xcframeworks/OpenTelemetryProtocolExporterCommon.xcframework.zip | awk '{print "   Size:", $5, "Modified:", $6, $7, $8}'
    CHECKSUM=$(shasum -a 256 build/xcframeworks/OpenTelemetryProtocolExporterCommon.xcframework.zip | awk '{print $1}')
    echo "   Checksum: $CHECKSUM"
else
    echo "   ✗ XCFramework not created yet"
fi
echo ""

# Check build directory
echo "3. Build Directory Status:"
if [ -d "build/OpenTelemetryProtocolExporterCommon" ]; then
    SIZE=$(du -sh build/OpenTelemetryProtocolExporterCommon/ 2>/dev/null | awk '{print $1}')
    echo "   Build directory size: $SIZE"
    
    # Check for frameworks
    FRAMEWORKS=$(find build/OpenTelemetryProtocolExporterCommon -name "*.framework" -type d 2>/dev/null | wc -l | xargs)
    echo "   Frameworks found: $FRAMEWORKS"
    
    # Check for archives
    ARCHIVES=$(find build/OpenTelemetryProtocolExporterCommon -name "*.xcarchive" -type d 2>/dev/null | wc -l | xargs)
    echo "   Archives found: $ARCHIVES"
else
    echo "   ✗ Build directory not found"
fi
echo ""

# Check recent build activity
echo "4. Recent Activity:"
if [ -d "build/OpenTelemetryProtocolExporterCommon" ]; then
    echo "   Most recently modified files:"
    find build/OpenTelemetryProtocolExporterCommon -type f -mmin -5 2>/dev/null | head -5 | while read file; do
        echo "   - $(basename $file) ($(stat -f "%Sm" -t "%H:%M:%S" "$file" 2>/dev/null || echo "unknown"))"
    done | head -5 || echo "   (no recent activity)"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Run this script again to check status: ./monitor-build.sh"
echo "Or watch continuously: watch -n 10 ./monitor-build.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
