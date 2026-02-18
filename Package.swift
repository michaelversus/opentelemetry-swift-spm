// swift-tools-version:5.9

import PackageDescription

/// Precompiled XCFrameworks for OpenTelemetry Swift version 1.15.6
/// Contains core modules and dependencies: OpenTelemetryApi, OpenTelemetrySdk, OpenTelemetryProtocolExporterHttp, DataCompression, and OpenTelemetryProtocolExporterCommon
/// All naming is consistent: binary target names match zip filenames, XCFramework directory names, and framework directory/binary names
/// OpenTelemetryProtocolExporterHttp uses a wrapper target to automatically link its dependencies

// Core modules
let openTelemetryApiXCFramework = Target.binaryTarget(
    name: "OpenTelemetryApi",
    url: "https://github.com/michaelversus/opentelemetry-swift-spm/releases/download/1.15.5/OpenTelemetryApi.xcframework.zip",
    checksum: "b9753d84bc9a7f76d2642a9ac63239c5404fef1d5639d377de5724a6c854edd1"
)

let openTelemetrySdkXCFramework = Target.binaryTarget(
    name: "OpenTelemetrySdk",
    url: "https://github.com/michaelversus/opentelemetry-swift-spm/releases/download/1.15.5/OpenTelemetrySdk.xcframework.zip",
    checksum: "7eb41880ec343a5e8595efe6da5b788f8f6d4e1d4c55571a0081124f57fc8a8e"
)

// Dependencies
let dataCompressionXCFramework = Target.binaryTarget(
    name: "DataCompression",
    url: "https://github.com/michaelversus/opentelemetry-swift-spm/releases/download/1.15.5/DataCompression.xcframework.zip",
    checksum: "f3fd74025c853ff005ae361495f33434d4925ea7403e89f137a21be46ea506b2"
)

let openTelemetryProtocolExporterCommonXCFramework = Target.binaryTarget(
    name: "OpenTelemetryProtocolExporterCommon",
    url: "https://github.com/michaelversus/opentelemetry-swift-spm/releases/download/1.15.5/OpenTelemetryProtocolExporterCommon.xcframework.zip",
    checksum: "c7dfd515d8a454fd0bd3e94c0e832bf9336083c97a5b8f381d58595b9e642a7f"
)

let openTelemetryProtocolExporterHttpXCFramework = Target.binaryTarget(
    name: "OpenTelemetryProtocolExporterHttp",
    url: "https://github.com/michaelversus/opentelemetry-swift-spm/releases/download/1.15.5/OpenTelemetryProtocolExporterHttp.xcframework.zip",
    checksum: "a894789bc3a8138e18000300fa197202336dc4a7d846411959444ef0a43a311e"
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
        .library(name: "DataCompression", targets: ["DataCompression", "_OpenTelemetrySwiftStub"]),
        .library(name: "OpenTelemetryProtocolExporterCommon", targets: ["OpenTelemetryProtocolExporterCommon", "_OpenTelemetrySwiftStub"]),
        .library(name: "OpenTelemetryProtocolExporterHttp", targets: ["OpenTelemetryProtocolExporterHttpWrapper", "_OpenTelemetrySwiftStub"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.20.2"),
    ],
    targets: [
        // Binary targets
        openTelemetryApiXCFramework,
        openTelemetrySdkXCFramework,
        dataCompressionXCFramework,
        openTelemetryProtocolExporterCommonXCFramework,
        openTelemetryProtocolExporterHttpXCFramework,
        
        // Wrapper target for OpenTelemetryProtocolExporterHttp that declares dependencies
        // This ensures DataCompression, OpenTelemetryProtocolExporterCommon, and SwiftProtobuf are automatically linked
        .target(
            name: "OpenTelemetryProtocolExporterHttpWrapper",
            dependencies: [
                "OpenTelemetryProtocolExporterHttp",
                "DataCompression",
                "OpenTelemetryProtocolExporterCommon",
                "OpenTelemetrySdk",
                .product(name: "SwiftProtobuf", package: "swift-protobuf")
            ],
            path: "Sources/OpenTelemetryProtocolExporterHttpWrapper"
        ),
        
        // Without at least one regular (non-binary) target, this package doesn't show up
        // in Xcode under "Frameworks, Libraries, and Embedded Content". That prevents
        // the frameworks from being embedded in the app product, causing the app to crash when
        // ran on a physical device. As a workaround, we can include a stub target
        // with at least one source file.
        // https://github.com/apple/swift-package-manager/issues/6069
        .target(name: "_OpenTelemetrySwiftStub"),
    ]
)
