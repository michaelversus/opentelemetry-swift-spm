#!/bin/bash

# Calculate SHA256 checksums for all XCFramework zip files
# Usage: calculate-checksums.sh [xcframeworks-dir] [output-file]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
XCFRAMEWORKS_DIR="${1:-${PROJECT_ROOT}/build/xcframeworks}"
OUTPUT_FILE="${2:-${PROJECT_ROOT}/build/checksums.json}"

echo "Calculating checksums for XCFrameworks in: ${XCFRAMEWORKS_DIR}"

if [ ! -d "$XCFRAMEWORKS_DIR" ]; then
    echo "Error: Directory ${XCFRAMEWORKS_DIR} does not exist"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Start JSON object
echo "{" > "$OUTPUT_FILE"

FIRST=true

# Find all zip files and calculate checksums
for ZIP_FILE in "${XCFRAMEWORKS_DIR}"/*.xcframework.zip; do
    if [ ! -f "$ZIP_FILE" ]; then
        continue
    fi
    
    MODULE_NAME=$(basename "$ZIP_FILE" .xcframework.zip)
    
    echo "  Calculating checksum for ${MODULE_NAME}..."
    
    # Calculate SHA256 checksum
    CHECKSUM=$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')
    
    # Add comma if not first entry
    if [ "$FIRST" = false ]; then
        echo "," >> "$OUTPUT_FILE"
    fi
    FIRST=false
    
    # Add entry to JSON
    echo "  \"${MODULE_NAME}\": \"${CHECKSUM}\"" >> "$OUTPUT_FILE"
    
    echo "    ✓ ${MODULE_NAME}: ${CHECKSUM}"
done

# Close JSON object
echo "}" >> "$OUTPUT_FILE"

echo ""
echo "Checksums saved to: ${OUTPUT_FILE}"

# Also create a human-readable summary
SUMMARY_FILE="${PROJECT_ROOT}/build/checksums.txt"
echo "OpenTelemetry Swift XCFramework Checksums" > "$SUMMARY_FILE"
echo "Generated: $(date)" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

for ZIP_FILE in "${XCFRAMEWORKS_DIR}"/*.xcframework.zip; do
    if [ ! -f "$ZIP_FILE" ]; then
        continue
    fi
    
    MODULE_NAME=$(basename "$ZIP_FILE" .xcframework.zip)
    CHECKSUM=$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')
    FILE_SIZE=$(du -h "$ZIP_FILE" | awk '{print $1}')
    
    echo "${MODULE_NAME}:" >> "$SUMMARY_FILE"
    echo "  Checksum: ${CHECKSUM}" >> "$SUMMARY_FILE"
    echo "  Size: ${FILE_SIZE}" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"
done

echo "Summary saved to: ${SUMMARY_FILE}"
