#!/bin/bash
# Monitor build progress every 5 minutes

BUILD_DIR="/Users/m.karagiorgos/opentelemetry-swift-spm/build"
XCFRAMEWORKS_DIR="${BUILD_DIR}/xcframeworks"

while true; do
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Build Monitor - $(date)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Check if build process is running
    if ps aux | grep -E "build-xcframeworks" | grep -v grep > /dev/null; then
        echo "✓ Build process is RUNNING"
    else
        echo "✗ Build process is NOT running (may have completed or failed)"
    fi
    echo ""
    
    # Count completed XCFrameworks
    COMPLETED=$(ls -1 "${XCFRAMEWORKS_DIR}"/*.xcframework.zip 2>/dev/null | wc -l | xargs)
    echo "Completed XCFrameworks: ${COMPLETED}"
    echo ""
    
    if [ "$COMPLETED" -gt 0 ]; then
        echo "Completed modules:"
        ls -1 "${XCFRAMEWORKS_DIR}"/*.xcframework.zip 2>/dev/null | xargs -n1 basename | sed 's/.xcframework.zip//' | sort | column
        echo ""
    fi
    
    # Check for any errors in recent output
    if [ -f "${BUILD_DIR}/build.log" ]; then
        echo "Recent errors (last 5):"
        tail -100 "${BUILD_DIR}/build.log" 2>/dev/null | grep -i "error\|failed" | tail -5 || echo "  None found"
        echo ""
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Next check in 5 minutes... (Press Ctrl+C to stop)"
    echo ""
    
    sleep 300  # 5 minutes
done
