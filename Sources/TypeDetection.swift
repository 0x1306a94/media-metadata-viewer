import Foundation
import UniformTypeIdentifiers

enum MediaKind: String, Sendable {
    case image
    case video
}

enum TypeDetection {
    /// Resolves a `UTType` using extended attributes / extension / optional sniff.
    static func resolvedUTType(for url: URL) throws -> UTType {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            if !FileManager.default.fileExists(atPath: url.path) {
                throw MediaMetadataError.fileNotFound(path: url.path)
            }
            throw MediaMetadataError.fileNotReadable(path: url.path)
        }

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw MediaMetadataError.fileNotReadable(path: url.path)
        }

        let values = try url.resourceValues(forKeys: [.contentTypeKey])
        if let contentType = values.contentType {
            return contentType
        }

        if let ext = url.pathExtension.isEmpty ? nil : url.pathExtension,
           let byExtension = UTType(filenameExtension: ext) {
            if byExtension != .data {
                return byExtension
            }
        }

        return try sniffUTType(url: url) ?? .data
    }

    /// Maps a `UTType` to image vs AVFoundation-backed inspection.
    static func mediaKind(for utType: UTType) throws -> MediaKind {
        if utType.conforms(to: .image) {
            return .image
        }
        if utType.conforms(to: .movie)
            || utType.conforms(to: .video)
            || utType.conforms(to: .audiovisualContent)
            || utType.conforms(to: .audio)
        {
            return .video
        }
        throw MediaMetadataError.unsupportedMediaType(
            description:
                "Type \(utType.identifier) is not a known image or audiovisual type. Expected image/* or common video/audio containers."
        )
    }

    /// Reads a small prefix and infers `UTType` for ambiguous files (e.g. extension missing).
    private static func sniffUTType(url: URL) throws -> UTType? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let prefix = try handle.read(upToCount: 512) ?? Data()
        if prefix.isEmpty {
            return nil
        }

        if prefix.starts(with: Data([0xFF, 0xD8, 0xFF])) {
            return .jpeg
        }
        if prefix.starts(with: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
            return .png
        }
        if prefix.count >= 12, String(data: prefix.subdata(in: 4..<8), encoding: .ascii) == "ftyp" {
            let brand = String(data: prefix.subdata(in: 8..<12), encoding: .ascii) ?? ""
            if brand.hasPrefix("qt") || brand == "M4V " || brand == "M4A " || brand == "mp41" || brand == "mp42"
                || brand == "isom" || brand.hasPrefix("3gp")
            {
                return .mpeg4Movie
            }
            if brand == "heic" || brand == "heix" || brand == "hevc" || brand == "heim" || brand == "heis" {
                return .heic
            }
        }
        if prefix.starts(with: Data("GIF87a".utf8)) || prefix.starts(with: Data("GIF89a".utf8)) {
            return .gif
        }
        if prefix.starts(with: Data([0x52, 0x49, 0x46, 0x46])) && prefix.count >= 12 {
            let riffType = String(data: prefix.subdata(in: 8..<12), encoding: .ascii) ?? ""
            if riffType == "WEBP" {
                return .webP
            }
        }
        if prefix.starts(with: Data([0x49, 0x49, 0x2A, 0x00]))
            || prefix.starts(with: Data([0x4D, 0x4D, 0x00, 0x2A]))
        {
            return .tiff
        }

        return nil
    }
}
