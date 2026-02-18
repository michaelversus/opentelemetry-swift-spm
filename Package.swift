// swift-tools-version:6.0

import PackageDescription

/// Precompiled XCFrameworks for OpenTelemetry Swift version 1.15.0
/// Contains only the core modules: OpenTelemetryApi, OpenTelemetrySdk, and OpenTelemetryProtocolExporterHttp

// Core modules
let openTelemetryApiXCFramework = Target.binaryTarget(
    name: "OpenTelemetryApi",
    url: "https://github.com/michaelversus/opentelemetry-swift-spm/releases/download/1.15.0/OpenTelemetryApi.xcframework.zip",
    checksum: "b9753d84bc9a7f76d2642a9ac63239c5404fef1d5639d377de5724a6c854edd1"
)

let openTelemetrySdkXCFramework = Target.binaryTarget(
    name: "OpenTelemetrySdk",
    url: "https://github.com/michaelversus/opentelemetry-swift-spm/releases/download/1.15.0/OpenTelemetrySdk.xcframework.zip",
    checksum: "7eb41880ec343a5e8595efe6da5b788f8f6d4e1d4c55571a0081124f57fc8a8e"
)

let openTelemetryProtocolExporterHttpXCFramework = Target.binaryTarget(
    name: "OpenTelemetryProtocolExporterHttp",
    url: "https://github.com/michaelversus/opentelemetry-swift-spm/releases/download/1.15.0/OpenTelemetryProtocolExporterHTTP.xcframework.zip",
    checksum: "97355327d48f1ff56a0daf17c66e08194875a0c0eb0ff02b71eea72390ae58d7"
)

let package = Package(
    name: "opentelemetry-swift-spm",
    platforms: [
        .macOS(.v12),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "OpenTelemetryApi", targets: ["OpenTelemetryApi", "_OpenTelemetrySwiftStub"]),
        .library(name: "OpenTelemetrySdk", targets: ["OpenTelemetrySdk", "_OpenTelemetrySwiftStub"]),
        .library(name: "OpenTelemetryProtocolExporterHttp", targets: ["OpenTelemetryProtocolExporterHttp", "_OpenTelemetrySwiftStub"]),
    ],
    targets: [
        // Binary targets
        openTelemetryApiXCFramework,
        openTelemetrySdkXCFramework,
        openTelemetryProtocolExporterHttpXCFramework,
        
        // Without at least one regular (non-binary) target, this package doesn't show up
        // in Xcode under "Frameworks, Libraries, and Embedded Content". That prevents
        // the frameworks from being embedded in the app product, causing the app to crash when
        // ran on a physical device. As a workaround, we can include a stub target
        // with at least one source file.
        // https://github.com/apple/swift-package-manager/issues/6069
        .target(name: "_OpenTelemetrySwiftStub"),
    ]
)
