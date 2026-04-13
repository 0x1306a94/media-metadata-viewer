import ArgumentParser
import Foundation

@main
struct MediaMetadataViewer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print image EXIF (ImageIO) or video metadata (AVFoundation) for a local file."
    )

    @Option(name: .shortAndLong, help: "Path to the media file.")
    var path: String

    @Option(name: .shortAndLong, help: "Output format.")
    var format: OutputFormat = .text

    func run() async throws {
        let url = URL(fileURLWithPath: path, isDirectory: false)
        let utType = try TypeDetection.resolvedUTType(for: url)
        let mediaKind = try TypeDetection.mediaKind(for: utType)

        let payload: [String: Any]
        switch mediaKind {
        case .image:
            let properties = try ImageMetadataReader.readProperties(url: url)
            payload = [
                "mediaKind": mediaKind.rawValue,
                "utType": utType.identifier,
                "properties": JSONCompatibleValue.convert(properties),
            ]
        case .video:
            let videoPayload = try await VideoMetadataReader.readPayload(url: url)
            payload = [
                "mediaKind": mediaKind.rawValue,
                "utType": utType.identifier,
                "video": videoPayload,
            ]
        }

        try MetadataOutput.write(payload, format: format)
    }
}
