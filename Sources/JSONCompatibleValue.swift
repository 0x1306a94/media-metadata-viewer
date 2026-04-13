import CoreFoundation
import Foundation

/// Recursively converts property-list / CoreFoundation values into JSON-serializable Swift values.
enum JSONCompatibleValue {
    static func convert(_ value: Any) -> Any {
        switch value {
        case let dict as NSDictionary:
            var output: [String: Any] = [:]
            for (key, nested) in dict {
                let stringKey = stringKey(from: key)
                output[stringKey] = convert(nested)
            }
            return output
        case let array as NSArray:
            return array.map { convert($0) }
        case let data as Data:
            return [
                "_type": "data",
                "base64": data.base64EncodedString(),
                "byteLength": data.count,
            ]
        case let date as Date:
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.string(from: date)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue
            }
            if CFNumberIsFloatType(number) {
                let double = number.doubleValue
                if double.isFinite {
                    return double
                }
                return NSNull()
            }
            return number.int64Value
        case is NSNull:
            return NSNull()
        case let string as String:
            return string
        case let url as URL:
            return url.absoluteString
        case let double as Double:
            return double.isFinite ? double : NSNull()
        case let float as Float:
            return float.isFinite ? Double(float) : NSNull()
        default:
            return String(describing: value)
        }
    }

    private static func stringKey(from key: Any) -> String {
        if let string = key as? String {
            return string
        }
        if let string = key as? NSString {
            return string as String
        }
        return String(describing: key)
    }
}
