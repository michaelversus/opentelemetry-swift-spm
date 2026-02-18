// Wrapper target to ensure dependencies are automatically linked
// This target re-exports OpenTelemetryProtocolExporterHttp and declares its dependencies
// so that SPM automatically includes DataCompression, OpenTelemetryProtocolExporterCommon, and SwiftProtobuf

@_exported import OpenTelemetryProtocolExporterHttp
@_exported import DataCompression
@_exported import OpenTelemetryProtocolExporterCommon
@_exported import OpenTelemetrySdk
@_exported import SwiftProtobuf
