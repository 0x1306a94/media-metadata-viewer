@preconcurrency import AVFoundation
import CoreMedia
import Foundation

enum VideoMetadataReader {
    /// Upper bound on timed metadata groups per track (avoids huge outputs).
    private static let maxTimedMetadataGroups = 5000

    static func readPayload(url: URL) async throws -> [String: Any] {
        let asset = AVURLAsset(
            url: url,
            options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true,
            ]
        )

        try await loadAssetValues(
            asset,
            keys: ["duration", "tracks", "metadata", "commonMetadata"]
        )

        let containerMetadata = try await resolveMetadataItems(asset.metadata)
        let commonMetadata = try await resolveMetadataItems(asset.commonMetadata)

        let metadataTracks = asset.tracks(withMediaType: .metadata)
        var trackPayloads: [[String: Any]] = []
        for track in metadataTracks {
            try await loadTrackValues(track)
            var summary = trackSummary(track: track)
            let timedGroups = try await readMetadataTrackTimedGroups(asset: asset, track: track)
            summary["timedMetadataGroups"] = timedGroups
            trackPayloads.append(summary)
        }

        return [
            "container": [
                "metadata": containerMetadata,
                "commonMetadata": commonMetadata,
            ],
            "metadataTracks": trackPayloads,
        ]
    }

    private static func loadAssetValues(_ asset: AVAsset, keys: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            asset.loadValuesAsynchronously(forKeys: keys) {
                var failure: Error?
                for key in keys {
                    var error: NSError?
                    let status = asset.statusOfValue(forKey: key, error: &error)
                    if status == .failed {
                        failure = error ?? MediaMetadataError.videoReadFailed(reason: "Failed loading \(key)")
                        break
                    }
                }
                if let failure {
                    continuation.resume(throwing: failure)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func loadTrackValues(_ track: AVAssetTrack) async throws {
        // AVAssetTrack does not support KVO key "duration"; use timeRange.duration after loading timeRange.
        let keys = [
            "formatDescriptions",
            "estimatedDataRate",
            "totalSampleDataLength",
            "timeRange",
        ]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            track.loadValuesAsynchronously(forKeys: keys) {
                var failure: Error?
                for key in keys {
                    var error: NSError?
                    let status = track.statusOfValue(forKey: key, error: &error)
                    if status == .failed {
                        failure = error ?? MediaMetadataError.videoReadFailed(reason: "Failed loading track \(key)")
                        break
                    }
                }
                if let failure {
                    continuation.resume(throwing: failure)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func resolveMetadataItems(_ items: [AVMetadataItem]) async throws -> [[String: Any]] {
        var results: [[String: Any]] = []
        for item in items {
            try await loadMetadataItemValues(item)
            results.append(metadataItemDictionary(item))
        }
        return results
    }

    private static func loadMetadataItemValues(_ item: AVMetadataItem) async throws {
        let keys = [
            "value",
            "identifier",
            "key",
            "keySpace",
            "dataType",
            "extendedLanguageTag",
            "locale",
        ]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            item.loadValuesAsynchronously(forKeys: keys) {
                var failure: Error?
                for key in keys {
                    var error: NSError?
                    let status = item.statusOfValue(forKey: key, error: &error)
                    if status == .failed {
                        failure = error ?? MediaMetadataError.videoReadFailed(reason: "Failed loading metadata item \(key)")
                        break
                    }
                }
                if let failure {
                    continuation.resume(throwing: failure)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func metadataItemDictionary(_ item: AVMetadataItem) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let identifier = item.identifier {
            dict["identifier"] = identifier.rawValue
        }
        if let key = item.key {
            dict["key"] = String(describing: key)
        }
        if let keySpace = item.keySpace {
            dict["keySpace"] = keySpace.rawValue
        }
        if let value = item.value {
            dict["value"] = JSONCompatibleValue.convert(value)
        }
        if let stringValue = item.stringValue {
            dict["stringValue"] = stringValue
        }
        if let dataValue = item.dataValue {
            dict["dataValue"] = JSONCompatibleValue.convert(dataValue)
        }
        if let dateValue = item.dateValue {
            dict["dateValue"] = JSONCompatibleValue.convert(dateValue)
        }
        if let numberValue = item.numberValue {
            dict["numberValue"] = JSONCompatibleValue.convert(numberValue)
        }
        if let tag = item.extendedLanguageTag {
            dict["extendedLanguageTag"] = tag
        }
        if let locale = item.locale {
            dict["localeIdentifier"] = locale.identifier
        }
        return dict
    }

    private static func trackSummary(track: AVAssetTrack) -> [String: Any] {
        let dict: [String: Any] = [
            "trackID": track.trackID,
            "mediaType": track.mediaType.rawValue,
            "estimatedDataRate": jsonSafeDouble(Double(track.estimatedDataRate)),
            "totalSampleDataLength": track.totalSampleDataLength,
            "timeRange": [
                "startSeconds": jsonSafeSeconds(track.timeRange.start),
                "durationSeconds": jsonSafeSeconds(track.timeRange.duration),
            ],
            "formatDescriptions": formatDescriptionsSummary(track),
        ]
        return dict
    }

    /// JSONSerialization rejects NaN/inf; CMTimeGetSeconds can yield NaN for invalid times.
    private static func jsonSafeSeconds(_ time: CMTime) -> Any {
        guard CMTIME_IS_VALID(time), CMTIME_IS_NUMERIC(time) else {
            return NSNull()
        }
        let seconds = CMTimeGetSeconds(time)
        return jsonSafeDouble(seconds)
    }

    private static func jsonSafeDouble(_ value: Double) -> Any {
        guard value.isFinite else {
            return NSNull()
        }
        return value
    }

    private static func formatDescriptionsSummary(_ track: AVAssetTrack) -> [String] {
        track.formatDescriptions.map { description in
            let format = description as! CMFormatDescription
            let mediaType = CMFormatDescriptionGetMediaType(format)
            let mediaSubType = CMFormatDescriptionGetMediaSubType(format)
            return "\(fourCharCode(mediaType))/\(fourCharCode(mediaSubType))"
        }
    }

    private static func fourCharCode(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF),
        ]
        return String(bytes: bytes, encoding: .macOSRoman) ?? "????"
    }

    /// Reads timed metadata using `AVAssetReaderOutputMetadataAdaptor` (do not mix with `copyNextSampleBuffer` on the same track output).
    private static func readMetadataTrackTimedGroups(asset: AVAsset, track: AVAssetTrack) async throws -> [[String: Any]] {
        let reader = try AVAssetReader(asset: asset)
        let assetDuration = asset.duration
        let trackDuration = track.timeRange.duration
        let duration =
            CMTimeCompare(trackDuration, .zero) == 0 ? assetDuration : trackDuration
        let start = track.timeRange.start
        reader.timeRange = CMTimeRange(start: start, duration: duration)

        let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        trackOutput.alwaysCopiesSampleData = false
        // Must create the adaptor before `startReading`; must not call `copyNextSampleBuffer` on `trackOutput` after this.
        let metadataAdaptor = AVAssetReaderOutputMetadataAdaptor(assetReaderTrackOutput: trackOutput)
        reader.add(trackOutput)

        guard reader.startReading() else {
            let reason = reader.error?.localizedDescription ?? "Unknown AVAssetReader error"
            throw MediaMetadataError.videoReadFailed(reason: reason)
        }

        var groups: [[String: Any]] = []
        var index = 0
        while reader.status == .reading, let group = metadataAdaptor.nextTimedMetadataGroup() {
            if index >= maxTimedMetadataGroups {
                break
            }

            var groupDict: [String: Any] = [
                "index": index,
                "timeRange": [
                    "startSeconds": jsonSafeSeconds(group.timeRange.start),
                    "durationSeconds": jsonSafeSeconds(group.timeRange.duration),
                ],
            ]

            var items: [[String: Any]] = []
            for item in group.items {
                try await loadMetadataItemValues(item)
                items.append(metadataItemDictionary(item))
            }
            groupDict["items"] = items
            groups.append(groupDict)
            index += 1
        }

        if reader.status == .failed {
            let reason = reader.error?.localizedDescription ?? "AVAssetReader failed while reading metadata track"
            throw MediaMetadataError.videoReadFailed(reason: reason)
        }

        return groups
    }
}
