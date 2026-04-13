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

    /// Pixel dimensions from ImageIO top-level properties when present.
    static func resolutionPixels(from properties: [String: Any]) -> [String: Int]? {
        let widthKey = kCGImagePropertyPixelWidth as String
        let heightKey = kCGImagePropertyPixelHeight as String
        guard let widthNumber = properties[widthKey] as? NSNumber,
              let heightNumber = properties[heightKey] as? NSNumber
        else {
            return nil
        }
        let width = Int(widthNumber.doubleValue.rounded())
        let height = Int(heightNumber.doubleValue.rounded())
        guard width > 0, height > 0 else {
            return nil
        }
        return ["width": width, "height": height]
    }
}
