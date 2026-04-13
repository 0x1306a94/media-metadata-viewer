import Foundation

enum MediaMetadataError: LocalizedError {
    case fileNotFound(path: String)
    case fileNotReadable(path: String)
    case unsupportedMediaType(description: String)
    case imageReadFailed(reason: String)
    case videoReadFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileNotReadable(let path):
            return "File not readable: \(path)"
        case .unsupportedMediaType(let description):
            return "Unsupported media type: \(description)"
        case .imageReadFailed(let reason):
            return "Failed to read image metadata: \(reason)"
        case .videoReadFailed(let reason):
            return "Failed to read video metadata: \(reason)"
        }
    }
}
