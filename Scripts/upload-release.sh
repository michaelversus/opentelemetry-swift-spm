#!/bin/bash

# Upload XCFrameworks to GitHub release
# Usage: upload-release.sh [version] [xcframeworks-dir] [repo] [dry-run]

set -e

VERSION="${1:-1.15.0}"
XCFRAMEWORKS_DIR="${2:-}"
REPO="${3:-}"
DRY_RUN="${4:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -z "$XCFRAMEWORKS_DIR" ]; then
    XCFRAMEWORKS_DIR="${PROJECT_ROOT}/build/xcframeworks"
fi

if [ -z "$REPO" ]; then
    # Try to detect repo from git remote
    if [ -d "${PROJECT_ROOT}/.git" ]; then
        REPO=$(cd "$PROJECT_ROOT" && git remote get-url origin 2>/dev/null | sed -E 's/.*github.com[:/](.*)\.git/\1/' || echo "")
    fi
    
    if [ -z "$REPO" ]; then
        echo "Error: Could not determine repository. Please provide repo as third argument."
        echo "Usage: $0 [version] [xcframeworks-dir] [repo] [dry-run]"
        exit 1
    fi
fi

echo "Uploading XCFrameworks to GitHub release ${VERSION} in ${REPO}"
echo "XCFrameworks directory: ${XCFRAMEWORKS_DIR}"

if [ ! -d "$XCFRAMEWORKS_DIR" ]; then
    echo "Error: Directory ${XCFRAMEWORKS_DIR} does not exist"
    exit 1
fi

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi

# Check if release exists
RELEASE_EXISTS=$(gh release view "${VERSION}" --repo "$REPO" 2>/dev/null && echo "yes" || echo "no")

if [ "$RELEASE_EXISTS" = "no" ]; then
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would create release ${VERSION}"
    else
        echo "Creating release ${VERSION}..."
        gh release create "${VERSION}" \
            --repo "$REPO" \
            --title "OpenTelemetry Swift ${VERSION} - XCFrameworks" \
            --notes "Precompiled XCFrameworks for OpenTelemetry Swift ${VERSION}" \
            --draft
    fi
else
    echo "Release ${VERSION} already exists"
fi

# Upload each zip file
UPLOADED=0
FAILED=0

for ZIP_FILE in "${XCFRAMEWORKS_DIR}"/*.xcframework.zip; do
    if [ ! -f "$ZIP_FILE" ]; then
        continue
    fi
    
    FILE_NAME=$(basename "$ZIP_FILE")
    FILE_SIZE=$(du -h "$ZIP_FILE" | awk '{print $1}')
    
    echo ""
    echo "Uploading ${FILE_NAME} (${FILE_SIZE})..."
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would upload: ${ZIP_FILE}"
        UPLOADED=$((UPLOADED + 1))
    else
        # Check if asset already exists
        ASSET_EXISTS=$(gh release view "${VERSION}" --repo "$REPO" --json assets --jq ".assets[] | select(.name == \"${FILE_NAME}\") | .name" 2>/dev/null || echo "")
        
        if [ -n "$ASSET_EXISTS" ]; then
            echo "  Asset ${FILE_NAME} already exists, skipping..."
            continue
        fi
        
        if gh release upload "${VERSION}" "${ZIP_FILE}" --repo "$REPO" --clobber; then
            echo "  ✓ Uploaded ${FILE_NAME}"
            UPLOADED=$((UPLOADED + 1))
        else
            echo "  ✗ Failed to upload ${FILE_NAME}"
            FAILED=$((FAILED + 1))
        fi
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$DRY_RUN" = "true" ]; then
    echo "[DRY RUN] Summary:"
    echo "  Would upload: ${UPLOADED} files"
else
    echo "Upload Summary:"
    echo "  Uploaded: ${UPLOADED} files"
    if [ $FAILED -gt 0 ]; then
        echo "  Failed: ${FAILED} files"
    fi
    echo ""
    echo "Release URL: https://github.com/${REPO}/releases/tag/${VERSION}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
