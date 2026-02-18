# Build Scripts Documentation

This directory contains scripts to build XCFrameworks for OpenTelemetry Swift modules and prepare them for distribution via Swift Package Manager.

## Overview

The build process consists of several steps:

1. **Build XCFrameworks** - Compile all modules into XCFrameworks for multiple platforms
2. **Calculate Checksums** - Generate SHA256 checksums for verification
3. **Upload to Releases** - Upload XCFrameworks to GitHub releases
4. **Update Package.swift** - Update Package.swift with checksums

## Prerequisites

Before running the build scripts, ensure you have:

- **Xcode 14+** (for `xcodebuild` command)
- **Swift 5.9+**
- **Git** (for cloning the source repository)
- **GitHub CLI** (`gh`) - Install from https://cli.github.com/
- **jq** - Install with `brew install jq` (for JSON parsing)
- **perl** - Usually pre-installed on macOS

### Installing Prerequisites

```bash
# Install GitHub CLI
brew install gh

# Install jq
brew install jq

# Authenticate with GitHub
gh auth login
```

## Scripts

### 1. `build-xcframeworks.sh`

Main orchestrator script that builds XCFrameworks for all OpenTelemetry Swift modules.

**Usage:**
```bash
./Scripts/build-xcframeworks.sh [version] [source-repo-path]
```

**Parameters:**
- `version` (optional): Version to build (default: `1.15.0`)
- `source-repo-path` (optional): Path to existing source repository (default: clones from GitHub)

**Example:**
```bash
# Build version 1.15.0 (clones repository)
./Scripts/build-xcframeworks.sh 1.15.0

# Build using existing local repository
./Scripts/build-xcframeworks.sh 1.15.0 /path/to/opentelemetry-swift
```

**What it does:**
- Clones the OpenTelemetry Swift repository at the specified version
- Builds XCFrameworks for each module in dependency order
- Creates zip archives for each XCFramework
- Outputs to `build/xcframeworks/`

**Output:**
- `build/xcframeworks/{ModuleName}.xcframework.zip` - One zip file per module

### 2. `build-module.sh`

Helper script to build an XCFramework for a single module.

**Usage:**
```bash
./Scripts/build-module.sh <module-name> <source-dir> <output-dir>
```

**Example:**
```bash
./Scripts/build-module.sh OpenTelemetryApi /path/to/source build
```

### 3. `calculate-checksums.sh`

Calculates SHA256 checksums for all XCFramework zip files.

**Usage:**
```bash
./Scripts/calculate-checksums.sh [xcframeworks-dir] [output-file]
```

**Parameters:**
- `xcframeworks-dir` (optional): Directory containing XCFramework zip files (default: `build/xcframeworks`)
- `output-file` (optional): JSON file to write checksums (default: `build/checksums.json`)

**Example:**
```bash
./Scripts/calculate-checksums.sh
```

**Output:**
- `build/checksums.json` - JSON file with module names and checksums
- `build/checksums.txt` - Human-readable summary

**Format of checksums.json:**
```json
{
  "OpenTelemetryApi": "abc123...",
  "OpenTelemetrySdk": "def456...",
  ...
}
```

### 4. `upload-release.sh`

Uploads XCFrameworks to a GitHub release.

**Usage:**
```bash
./Scripts/upload-release.sh [version] [xcframeworks-dir] [repo] [dry-run]
```

**Parameters:**
- `version` (optional): Release version (default: `1.15.0`)
- `xcframeworks-dir` (optional): Directory containing zip files (default: `build/xcframeworks`)
- `repo` (optional): GitHub repository (default: detected from git remote)
- `dry-run` (optional): Set to `true` to simulate without uploading

**Example:**
```bash
# Upload to release (dry run first)
./Scripts/upload-release.sh 1.15.0 build/xcframeworks your-username/opentelemetry-swift-spm true

# Actually upload
./Scripts/upload-release.sh 1.15.0 build/xcframeworks your-username/opentelemetry-swift-spm false
```

**What it does:**
- Creates a GitHub release if it doesn't exist
- Uploads each XCFramework zip file as a release asset
- Skips files that already exist in the release

### 5. `update-package.sh`

Updates Package.swift with checksums from checksums.json.

**Usage:**
```bash
./Scripts/update-package.sh [checksums-file] [package-file]
```

**Parameters:**
- `checksums-file` (optional): Path to checksums.json (default: `build/checksums.json`)
- `package-file` (optional): Path to Package.swift (default: `Package.swift`)

**Example:**
```bash
./Scripts/update-package.sh
```

**What it does:**
- Reads checksums from checksums.json
- Updates Package.swift, replacing placeholder checksums
- Creates a backup file (`Package.swift.backup`)

## Complete Workflow

Here's the complete workflow to build and release XCFrameworks:

```bash
# 1. Build XCFrameworks
./Scripts/build-xcframeworks.sh 1.15.0

# 2. Calculate checksums
./Scripts/calculate-checksums.sh

# 3. Review checksums (optional)
cat build/checksums.txt

# 4. Upload to GitHub release (dry run first)
./Scripts/upload-release.sh 1.15.0 build/xcframeworks your-username/opentelemetry-swift-spm true

# 5. Actually upload
./Scripts/upload-release.sh 1.15.0 build/xcframeworks your-username/opentelemetry-swift-spm false

# 6. Update Package.swift with checksums
./Scripts/update-package.sh

# 7. Verify Package.swift
grep -c "PLACEHOLDER_CHECKSUM" Package.swift  # Should be 0

# 8. Commit and push changes
git add Package.swift
git commit -m "Update checksums for version 1.15.0"
git push
```

## Build Order

Modules are built in dependency order:

1. **Core modules** (no dependencies):
   - OpenTelemetryApi
   - DataCompression

2. **First-level dependencies**:
   - OpenTelemetryConcurrency
   - OpenTelemetrySdk
   - OTelSwiftLog

3. **Exporters** (depend on OpenTelemetrySdk):
   - StdoutExporter
   - PrometheusExporter
   - OpenTelemetryProtocolExporterCommon
   - PersistenceExporter
   - InMemoryExporter

4. **Protocol exporters** (depend on Common):
   - OpenTelemetryProtocolExporterHttp
   - OpenTelemetryProtocolExporterGrpc

5. **Bridges/Shims**:
   - SwiftMetricsShim

6. **Contrib**:
   - BaggagePropagationProcessor

7. **Darwin-only modules** (macOS/iOS/tvOS/watchOS):
   - JaegerExporter
   - ZipkinExporter
   - NetworkStatus
   - URLSessionInstrumentation
   - SignPostIntegration
   - ResourceExtension

8. **Objective-C modules**:
   - OpenTracingShim

## Platform Support

XCFrameworks are built for:

- **iOS**: Device (arm64) + Simulator (arm64, x86_64)
- **macOS**: arm64 + x86_64
- **tvOS**: Device + Simulator
- **watchOS**: Device + Simulator

## Troubleshooting

### Build Failures

If a module fails to build:

1. **Check dependencies**: Ensure all dependencies are built first
2. **Verify source**: Make sure the source repository is at the correct version
3. **Check Xcode version**: Ensure Xcode 14+ is installed
4. **Review logs**: Check build output for specific errors

### Checksum Mismatches

If checksums don't match:

1. Rebuild XCFrameworks
2. Recalculate checksums
3. Verify zip files are not corrupted

### Upload Failures

If upload fails:

1. **Check authentication**: Run `gh auth status`
2. **Verify permissions**: Ensure you have write access to the repository
3. **Check release exists**: Verify the release was created
4. **Review file sizes**: Large files may timeout

### Package.swift Update Issues

If checksums aren't updating:

1. **Check format**: Verify checksums.json format is correct
2. **Verify placeholders**: Ensure Package.swift has placeholder checksums
3. **Manual update**: Update checksums manually if needed

## Directory Structure

```
opentelemetry-swift-spm/
├── Scripts/
│   ├── build-xcframeworks.sh      # Main build script
│   ├── build-module.sh             # Single module builder
│   ├── calculate-checksums.sh     # Checksum calculator
│   ├── upload-release.sh          # GitHub uploader
│   ├── update-package.sh          # Package.swift updater
│   └── README.md                  # This file
├── build/                          # Build artifacts (gitignored)
│   ├── xcframeworks/              # XCFramework zip files
│   ├── checksums.json             # Generated checksums
│   └── checksums.txt              # Human-readable checksums
└── Package.swift                   # Updated with checksums
```

## Notes

- Build artifacts are stored in `build/` directory (gitignored)
- Source repository is cloned to `build/opentelemetry-swift-{version}/`
- XCFrameworks are archived as zip files for distribution
- Checksums use SHA256 algorithm
- Package.swift backup is created before updates

## Additional Resources

- [XCFramework Documentation](https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle)
- [Swift Package Manager Documentation](https://swift.org/package-manager/)
- [GitHub CLI Documentation](https://cli.github.com/manual/)
