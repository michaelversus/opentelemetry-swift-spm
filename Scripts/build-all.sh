#!/bin/bash

# Master script that runs the complete build and release process
# Usage: build-all.sh [version] [repo] [dry-run]

set -e

VERSION="${1:-1.15.0}"
REPO="${2:-}"
DRY_RUN="${3:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "OpenTelemetry Swift XCFramework Build Process"
echo "Version: ${VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Build XCFrameworks
echo "Step 1: Building XCFrameworks..."
./Scripts/build-xcframeworks.sh "${VERSION}" || {
    echo "Error: Failed to build XCFrameworks"
    exit 1
}

# Step 2: Calculate checksums
echo ""
echo "Step 2: Calculating checksums..."
./Scripts/calculate-checksums.sh || {
    echo "Error: Failed to calculate checksums"
    exit 1
}

# Step 3: Upload to release (if not dry run)
if [ "$DRY_RUN" != "true" ]; then
    echo ""
    echo "Step 3: Uploading to GitHub release..."
    if [ -z "$REPO" ]; then
        # Try to detect repo
        if [ -d "${PROJECT_ROOT}/.git" ]; then
            REPO=$(cd "$PROJECT_ROOT" && git remote get-url origin 2>/dev/null | sed -E 's/.*github.com[:/](.*)\.git/\1/' || echo "")
        fi
    fi
    
    if [ -n "$REPO" ]; then
        ./Scripts/upload-release.sh "${VERSION}" "${PROJECT_ROOT}/build/xcframeworks" "${REPO}" false || {
            echo "Warning: Failed to upload to release"
        }
    else
        echo "Warning: Could not determine repository, skipping upload"
    fi
    
    # Step 4: Update Package.swift
    echo ""
    echo "Step 4: Updating Package.swift..."
    ./Scripts/update-package.sh || {
        echo "Warning: Failed to update Package.swift"
    }
else
    echo ""
    echo "Step 3: Skipping upload (dry run)"
    echo "Step 4: Skipping Package.swift update (dry run)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Build process complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
