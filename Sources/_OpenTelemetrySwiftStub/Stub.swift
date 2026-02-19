// This is a stub target to work around Swift Package Manager issue #6069
// https://github.com/apple/swift-package-manager/issues/6069
//
// Without at least one regular (non-binary) target, binary-only packages don't show up
// in Xcode under "Frameworks, Libraries, and Embedded Content", preventing proper
// embedding in the app product.
//
// Additionally, importing the modules here ensures the static libraries are linked
// when this package is used through transitive dependencies.

import Foundation
@_exported import OpenTelemetryApi
@_exported import OpenTelemetrySdk
@_exported import DataCompression
@_exported import OpenTelemetryProtocolExporterCommon
@_exported import OpenTelemetryProtocolExporterHttp
@_exported import SwiftProtobuf

// Empty stub - the actual implementation comes from the binary XCFramework
// The imports above ensure the static libraries are linked
