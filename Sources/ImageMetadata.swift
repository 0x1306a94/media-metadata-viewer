import Foundation
import ImageIO

enum ImageMetadataReader {
    static func readProperties(url: URL) throws -> [String: Any] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw MediaMetadataError.imageReadFailed(reason: "CGImageSourceCreateWithURL returned nil")
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            throw MediaMetadataError.imageReadFailed(reason: "CGImageSourceCopyPropertiesAtIndex returned nil")
        }
        return properties
    }
}
