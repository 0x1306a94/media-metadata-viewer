import ArgumentParser
import Foundation

enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
    case text
    case json
}

enum MetadataOutput {
    static func write(_ value: Any, format: OutputFormat) throws {
        let converted = JSONCompatibleValue.convert(value)
        switch format {
        case .json:
            let data = try JSONSerialization.data(
                withJSONObject: converted,
                options: [.prettyPrinted, .sortedKeys]
            )
            guard let string = String(data: data, encoding: .utf8) else {
                throw MediaMetadataError.videoReadFailed(reason: "Failed to encode UTF-8 JSON")
            }
            print(string)
        case .text:
            print(textBlock(from: converted, indent: 0), terminator: "")
        }
    }

    private static func textBlock(from value: Any, indent: Int) -> String {
        let pad = String(repeating: "  ", count: indent)
        switch value {
        case let dictionary as [String: Any]:
            if isDataDictionary(dictionary) {
                return "\(pad)\(dataSummary(dictionary))\n"
            }
            if dictionary.isEmpty {
                return "\(pad){}\n"
            }
            return dictionary.keys.sorted().map { key in
                let nested = dictionary[key]!
                if nested is [String: Any] {
                    return "\(pad)\(key):\n" + textBlock(from: nested, indent: indent + 1)
                }
                if nested is [Any] {
                    return "\(pad)\(key):\n" + textBlock(from: nested, indent: indent + 1)
                }
                return "\(pad)\(key): \(scalarString(nested))\n"
            }.joined()

        case let array as [Any]:
            if array.isEmpty {
                return "\(pad)[]\n"
            }
            return array.enumerated().map { index, element in
                let label = "\(pad)[\(index)]"
                if element is [String: Any] {
                    return "\(label):\n" + textBlock(from: element, indent: indent + 1)
                }
                if element is [Any] {
                    return "\(label):\n" + textBlock(from: element, indent: indent + 1)
                }
                return "\(label): \(scalarString(element))\n"
            }.joined()

        default:
            return "\(pad)\(scalarString(value))\n"
        }
    }

    private static func isDataDictionary(_ value: [String: Any]) -> Bool {
        value["_type"] as? String == "data" && value["base64"] is String
    }

    private static func dataSummary(_ value: [String: Any]) -> String {
        let length = value["byteLength"] as? Int ?? 0
        return "data(\(length) bytes; use --format json for base64)"
    }

    private static func scalarString(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return "\(number)"
        case is NSNull:
            return "null"
        case let dictionary as [String: Any]:
            if let base64 = dictionary["base64"] as? String, dictionary["_type"] as? String == "data" {
                let length = dictionary["byteLength"] as? Int ?? base64.count
                return "data(\(length) bytes, base64 omitted in text; use --format json)"
            }
            return String(describing: dictionary)
        default:
            return String(describing: value)
        }
    }
}
