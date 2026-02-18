# OpenTelemetry Swift SPM

A lightweight Swift Package Manager wrapper for [OpenTelemetry Swift](https://github.com/open-telemetry/opentelemetry-swift) version 1.15.0 that uses precompiled XCFrameworks instead of building from source.

## Why This Package?

The main [opentelemetry-swift](https://github.com/open-telemetry/opentelemetry-swift) repository is large (300+ MB with full git history), and Swift Package Manager always downloads the full repository with all git history. This can be slow and inefficient for projects that just need to use OpenTelemetry.

This package provides a lightweight alternative that:
- **Downloads quickly**: Only contains the Package.swift file (<500KB)
- **Builds faster**: Uses precompiled XCFrameworks, no compilation needed
- **Same functionality**: Points to OpenTelemetry Swift version 1.15.0

## Installation

### Swift Package Manager

Add this package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/YOUR_USERNAME/opentelemetry-swift-spm.git", from: "1.15.0")
]
```

Or add it in Xcode:
1. Select "File" → "Add Packages..."
2. Enter `https://github.com/YOUR_USERNAME/opentelemetry-swift-spm.git`
3. Select version 1.15.0

## Usage

Import the modules you need:

```swift
import OpenTelemetryApi
import OpenTelemetrySdk
import StdoutExporter
```

### Available Products

**Core:**
- `OpenTelemetryApi` - OpenTelemetry API protocols and no-op implementations
- `OpenTelemetrySdk` - Reference implementation of the API
- `OpenTelemetryConcurrency` - Concurrency support

**Exporters:**
- `StdoutExporter` - Export traces/metrics to stdout
- `PrometheusExporter` - Export metrics to Prometheus
- `OpenTelemetryProtocolExporter` - OTLP exporter (gRPC)
- `OpenTelemetryProtocolExporterHTTP` - OTLP exporter (HTTP)
- `PersistenceExporter` - Persistent storage exporter
- `InMemoryExporter` - In-memory exporter for testing
- `JaegerExporter` - Export traces to Jaeger (Darwin only)
- `ZipkinExporter` - Export traces to Zipkin (Darwin only)

**Instrumentation:**
- `URLSessionInstrumentation` - Automatic URLSession instrumentation (Darwin only)
- `NetworkStatus` - Network status monitoring (Darwin only)
- `SignPostIntegration` - OS Signpost integration (Darwin only)
- `ResourceExtension` - SDK resource extension (Darwin only)

**Bridges/Shims:**
- `SwiftMetricsShim` - Swift Metrics compatibility
- `OTelSwiftLog` - Swift Log integration
- `OpenTracingShim-experimental` - OpenTracing compatibility (Objective-C only)

**Contrib:**
- `BaggagePropagationProcessor` - Baggage propagation processor

**Utilities:**
- `DataCompression` - Data compression utilities

## Status

⚠️ **Note**: This package currently requires XCFrameworks to be built and released from the main [opentelemetry-swift](https://github.com/open-telemetry/opentelemetry-swift) repository. Once XCFrameworks are available in releases, update the `Package.swift` file to point to the correct download URLs and checksums.

## Related Packages

- [opentelemetry-swift](https://github.com/open-telemetry/opentelemetry-swift) - Main OpenTelemetry Swift repository (source-based)
- [opentelemetry-swift-core](https://github.com/open-telemetry/opentelemetry-swift-core) - Core OpenTelemetry Swift API and SDK

## License

This package follows the same license as OpenTelemetry Swift (Apache 2.0).
