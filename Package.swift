// swift-tools-version:5.9

import PackageDescription

/// Precompiled XCFrameworks for OpenTelemetry Swift version 1.15.13
/// Contains core modules and dependencies: OpenTelemetryApi, OpenTelemetrySdk, OpenTelemetryProtocolExporterHttp, DataCompression, and OpenTelemetryProtocolExporterCommon
/// All naming is consistent: binary target names match zip filenames, XCFramework directory names, and framework directory/binary names
/// OpenTelemetryProtocolExporterHttp uses a wrapper target to automatically link its dependencies
/// All XCFrameworks include universal iOS Simulator slices (ios-arm64_x86_64-simulator) for Apple Silicon and Intel Mac compatibility

// Core modules
let openTelemetryApiXCFramework = Target.binaryTarget(
    name: "OpenTelemetryApi",
    url: "https://github.com/michaelversus/opentelemetry-swift-spm/releases/download/1.15.13/OpenTelemetryApi.xcframework.zip",
    checksum: "b9753d84bc9a7f76d2642a9ac63239c5404fef1d5639d377de5724a6c854edd1"
)

let openTelemetrySdkXCFramework = Target.binaryTarget(
    name: "OpenTelemetrySdk",
    url: "https://github.com/michaelversus/opentelemetry-swift-spm/releases/download/1.15.13/OpenTelemetrySdk.xcframework.zip",
    checksum: "5298c0c9cff41e5d2e0ee4a6bc77712ebda9da12009e2d438da8fe3123dc421c"
)

// Dependencies
let dataCompressionXCFramework = Target.binaryTarget(
    name: "DataCompression",
    url: "https://github.com/michaelversus/opentelemetry-swift-spm/releases/download/1.15.13/DataCompression.xcframework.zip",
    checksum: "f3fd74025c853ff005ae361495f33434d4925ea7403e89f137a21be46ea506b2"
)

let openTelemetryProtocolExporterCommonXCFramework = Target.binaryTarget(
    name: "OpenTelemetryProtocolExporterCommon",
    url: "https://github.com/michaelversus/opentelemetry-swift-spm/releases/download/1.15.13/OpenTelemetryProtocolExporterCommon.xcframework.zip",
    checksum: "c7dfd515d8a454fd0bd3e94c0e832bf9336083c97a5b8f381d58595b9e642a7f"
)

let openTelemetryProtocolExporterHttpXCFramework = Target.binaryTarget(
    name: "OpenTelemetryProtocolExporterHttp",
    url: "https://github.com/michaelversus/opentelemetry-swift-spm/releases/download/1.15.13/OpenTelemetryProtocolExporterHttp.xcframework.zip",
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
        // OpenTelemetrySdk depends on OpenTelemetryApi, so include it in the product targets
        .library(name: "OpenTelemetrySdk", targets: ["OpenTelemetrySdk", "OpenTelemetryApi", "_OpenTelemetrySwiftStub"]),
        .library(name: "DataCompression", targets: ["DataCompression", "_OpenTelemetrySwiftStub"]),
        // OpenTelemetryProtocolExporterCommon depends on OpenTelemetrySdk and OpenTelemetryApi
        .library(name: "OpenTelemetryProtocolExporterCommon", targets: ["OpenTelemetryProtocolExporterCommon", "OpenTelemetrySdk", "OpenTelemetryApi", "_OpenTelemetrySwiftStub"]),
        // OpenTelemetryProtocolExporterHttp depends on OpenTelemetryProtocolExporterCommon, OpenTelemetrySdk, and OpenTelemetryApi
        .library(name: "OpenTelemetryProtocolExporterHttp", targets: ["OpenTelemetryProtocolExporterHttpWrapper", "OpenTelemetryProtocolExporterCommon", "OpenTelemetrySdk", "OpenTelemetryApi", "_OpenTelemetrySwiftStub"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", "1.33.3"..<"1.34.0"),
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
        //
        // Additionally, by depending on all binary targets, we ensure the static libraries
        // are linked when this package is used through transitive dependencies.
        // SwiftProtobuf is included here because the OpenTelemetryProtocolExporterHttp binary
        // target's .swiftinterface file imports it, and it must be available when building.
        .target(
            name: "_OpenTelemetrySwiftStub",
            dependencies: [
                "OpenTelemetryApi",
                "OpenTelemetrySdk",
                "DataCompression",
                "OpenTelemetryProtocolExporterCommon",
                "OpenTelemetryProtocolExporterHttp",
                .product(name: "SwiftProtobuf", package: "swift-protobuf")
            ]
        ),
    ]
)
