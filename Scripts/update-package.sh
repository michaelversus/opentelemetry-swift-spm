#!/bin/bash

# Script to update Package.swift with checksums from checksums.json
# Usage: update-package.sh [checksums-file] [package-file]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CHECKSUMS_FILE="${1:-${PROJECT_ROOT}/build/checksums.json}"
PACKAGE_FILE="${2:-${PROJECT_ROOT}/Package.swift}"

echo "Updating Package.swift with checksums from ${CHECKSUMS_FILE}"

if [ ! -f "$CHECKSUMS_FILE" ]; then
    echo "Error: Checksums file not found: ${CHECKSUMS_FILE}"
    exit 1
fi

if [ ! -f "$PACKAGE_FILE" ]; then
    echo "Error: Package.swift not found: ${PACKAGE_FILE}"
    exit 1
fi

# Check if jq is installed (for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed"
    echo "Install it with: brew install jq"
    exit 1
fi

# Create backup
cp "$PACKAGE_FILE" "${PACKAGE_FILE}.backup"
echo "Created backup: ${PACKAGE_FILE}.backup"

UPDATED_COUNT=0

# Read checksums and update Package.swift
while IFS="=" read -r module_name checksum; do
    # Remove quotes and clean up
    module_name=$(echo "$module_name" | sed 's/^"//;s/"$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    checksum=$(echo "$checksum" | sed 's/^"//;s/"$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [ -z "$module_name" ] || [ -z "$checksum" ]; then
        continue
    fi
    
    echo "  Updating checksum for ${module_name}..."
    
    # Find the binary target for this module and update its checksum
    # Pattern: let ...XCFramework = Target.binaryTarget(... checksum: "...")
    
    # Use sed to replace the checksum for this specific module
    # First, find the line with the module name, then find the checksum line after it
    # We'll use a more targeted approach with awk or perl
    
    # Try to find and replace using sed with a pattern that matches the module
    # This is tricky because we need to match across multiple lines
    
    # Use perl for multi-line matching
    if command -v perl &> /dev/null; then
        perl -i -pe "
            if (\$found_module) {
                if (s/checksum:\s*\"PLACEHOLDER_CHECKSUM_REPLACE_WHEN_XCFRAMEWORK_AVAILABLE\"/checksum: \"${checksum}\"/) {
                    \$found_module = 0;
                    \$updated = 1;
                }
            }
            if (/\b${module_name}\b/ && /binaryTarget/) {
                \$found_module = 1;
            }
        " "$PACKAGE_FILE" && {
            echo "    ✓ Updated ${module_name}"
            UPDATED_COUNT=$((UPDATED_COUNT + 1))
        } || echo "    ✗ Could not update ${module_name}"
    else
        # Fallback: simple sed replacement for placeholder
        # This will replace the first placeholder it finds
        if grep -q "\"${module_name}\"" "$PACKAGE_FILE"; then
            # Find the checksum line after the module name (within next 10 lines)
            sed -i.tmp -E "/let.*${module_name}.*XCFramework/,/checksum:/ {
                s/checksum:\s*\"PLACEHOLDER_CHECKSUM_REPLACE_WHEN_XCFRAMEWORK_AVAILABLE\"/checksum: \"${checksum}\"/
            }" "$PACKAGE_FILE" && {
                rm -f "${PACKAGE_FILE}.tmp"
                echo "    ✓ Updated ${module_name}"
                UPDATED_COUNT=$((UPDATED_COUNT + 1))
            } || echo "    ✗ Could not update ${module_name}"
        fi
    fi
    
done < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$CHECKSUMS_FILE")

# Alternative simpler approach: replace placeholders in order
if [ $UPDATED_COUNT -eq 0 ]; then
    echo "Trying alternative update method..."
    
    # Get checksums as array
    mapfile -t checksum_array < <(jq -r 'to_entries[] | "\(.key)|\(.value)"' "$CHECKSUMS_FILE")
    
    # Replace placeholders sequentially
    for entry in "${checksum_array[@]}"; do
        IFS='|' read -r module_name checksum <<< "$entry"
        
        # Replace first placeholder found
        if perl -i -pe "s/checksum:\s*\"PLACEHOLDER_CHECKSUM_REPLACE_WHEN_XCFRAMEWORK_AVAILABLE\"/checksum: \"${checksum}\"/ if !\$replaced++" "$PACKAGE_FILE" 2>/dev/null; then
            echo "  ✓ Updated checksum for ${module_name}"
            UPDATED_COUNT=$((UPDATED_COUNT + 1))
        fi
    done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Updated ${UPDATED_COUNT} checksums in Package.swift"
echo "Backup saved to: ${PACKAGE_FILE}.backup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verify no placeholders remain
REMAINING_PLACEHOLDERS=$(grep -c "PLACEHOLDER_CHECKSUM_REPLACE_WHEN_XCFRAMEWORK_AVAILABLE" "$PACKAGE_FILE" || echo "0")
if [ "$REMAINING_PLACEHOLDERS" -gt 0 ]; then
    echo "Warning: ${REMAINING_PLACEHOLDERS} placeholder checksums remain"
fi
