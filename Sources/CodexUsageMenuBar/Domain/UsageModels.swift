import Foundation

struct UsageWindow: Equatable, Sendable {
    private static let maximumWindowSeconds = TimeInterval(10 * 365 * 24 * 60 * 60)
    private static let maximumUnixTimestamp = 253_402_300_799.0

    let usedPercent: Double?
    let limitWindowSeconds: Double?
    let resetAfterSeconds: Double?
    let resetAt: Date?

    var remainingPercent: Double? {
        guard let usedPercent else { return nil }
        return min(100, max(0, 100 - usedPercent))
    }

    init(value: APIJSONValue?) {
        let object = value?.objectValue ?? [:]
        usedPercent = object["used_percent"]?.numberValue.map { min(100, max(0, $0)) }
        limitWindowSeconds = Self.nonNegativeInterval(object["limit_window_seconds"])
        resetAfterSeconds = Self.nonNegativeInterval(object["reset_after_seconds"])
        resetAt = Self.date(from: object["reset_at"])
    }

    var hasUsableData: Bool {
        usedPercent != nil || limitWindowSeconds != nil || resetAfterSeconds != nil || resetAt != nil
    }

    private static func nonNegativeInterval(_ value: APIJSONValue?) -> TimeInterval? {
        guard let interval = value?.numberValue,
              interval >= 0,
              interval <= maximumWindowSeconds else {
            return nil
        }
        return interval
    }

    private static func date(from value: APIJSONValue?) -> Date? {
        if let seconds = value?.numberValue {
            return date(fromUnixTimestamp: seconds)
        }

        guard let string = value?.stringValue else { return nil }
        if let seconds = Double(string) {
            return date(fromUnixTimestamp: seconds)
        }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: string)
    }

    private static func date(fromUnixTimestamp value: TimeInterval) -> Date? {
        guard value.isFinite else { return nil }
        let timestamp = abs(value) > 100_000_000_000 ? value / 1_000 : value
        guard timestamp.isFinite, abs(timestamp) <= maximumUnixTimestamp else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}

struct AdditionalRateLimit: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let primaryWindow: UsageWindow?
    let secondaryWindow: UsageWindow?
}

struct UsageResponse: Decodable, Equatable, Sendable {
    let primaryWindow: UsageWindow?
    let secondaryWindow: UsageWindow?
    let additionalRateLimits: [AdditionalRateLimit]

    init(from decoder: Decoder) throws {
        let root = try APIJSONValue(from: decoder)
        let rootObject = root.objectValue ?? [:]
        let rateLimit = rootObject["rate_limit"]?.objectValue ?? [:]

        primaryWindow = Self.parseWindow(rateLimit["primary_window"])
        secondaryWindow = Self.parseWindow(rateLimit["secondary_window"])

        let collection = rootObject["additional_rate_limits"]
            ?? rateLimit["additional_rate_limits"]
        additionalRateLimits = Self.parseAdditionalLimits(collection)

        guard primaryWindow != nil || secondaryWindow != nil || !additionalRateLimits.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "No recognized usage windows")
            )
        }
    }

    private static func parseWindow(_ value: APIJSONValue?) -> UsageWindow? {
        guard let value else { return nil }
        let window = UsageWindow(value: value)
        return window.hasUsableData ? window : nil
    }

    private static func containsWindowFields(_ object: [String: APIJSONValue]) -> Bool {
        ["used_percent", "limit_window_seconds", "reset_after_seconds", "reset_at"]
            .contains { object[$0] != nil }
    }

    private static func parseAdditionalLimits(_ value: APIJSONValue?) -> [AdditionalRateLimit] {
        let entries: [(String?, APIJSONValue)]
        switch value {
        case .array(let values):
            entries = values.map { (nil, $0) }
        case .object(let values):
            entries = values.keys.sorted().compactMap { key in
                guard let value = values[key] else { return nil }
                return (key, value)
            }
        default:
            return []
        }

        return entries.enumerated().compactMap { index, entry in
            guard let object = entry.1.objectValue else { return nil }
            let rawID = object.firstValue(for: ["limit_name", "metered_limit_name", "name", "id"])?.stringValue
            let id: String
            if let rawID, !rawID.isEmpty {
                id = rawID
            } else {
                id = entry.0 ?? "additional-\(index + 1)"
            }
            let rawName = object.firstValue(
                for: ["display_name", "title", "name", "limit_name", "metered_limit_name"]
            )?.stringValue
            let name: String
            if let rawName, !rawName.isEmpty {
                name = rawName
            } else {
                name = id.replacingOccurrences(of: "_", with: " ")
            }

            let candidates = [
                object["rate_limit"]?.objectValue,
                object["rateLimit"]?.objectValue,
                object
            ].compactMap { $0 }
            var primary = candidates.firstValue(for: ["primary_window", "primaryWindow"])
                .flatMap { Self.parseWindow($0) }
            var secondary = candidates.firstValue(for: ["secondary_window", "secondaryWindow"])
                .flatMap { Self.parseWindow($0) }

            if primary == nil && secondary == nil {
                let directWindow: [String: APIJSONValue]?
                if Self.containsWindowFields(object) {
                    directWindow = object
                } else if let nested = object["window"]?.objectValue,
                          Self.containsWindowFields(nested) {
                    directWindow = nested
                } else if let nested = object["rate_limit"]?.objectValue,
                          Self.containsWindowFields(nested) {
                    directWindow = nested
                } else {
                    directWindow = nil
                }

                if let directWindow {
                    let parsedWindow = Self.parseWindow(.object(directWindow))
                    if let parsedWindow {
                        let duration = parsedWindow.limitWindowSeconds ?? 0
                        let identity = "\(id) \(rawName ?? "") \(name)".lowercased()
                        let weekly = identity.contains("weekly")
                            || identity.contains("secondary")
                            || identity.contains("reserve")
                            || duration >= 6 * 24 * 60 * 60
                        if weekly {
                            secondary = parsedWindow
                        } else {
                            primary = parsedWindow
                        }
                    }
                }
            }

            return AdditionalRateLimit(
                id: id,
                name: name,
                primaryWindow: primary,
                secondaryWindow: secondary
            )
        }
    }
}

struct ResetCredit: Equatable, Sendable {
    let status: String?
    let grantedAt: Date?
    let expiresAt: Date?

    init(value: APIJSONValue) {
        let object = value.objectValue ?? [:]
        status = object["status"]?.stringValue
        grantedAt = UsageWindow.dateValue(from: object["granted_at"])
        expiresAt = UsageWindow.dateValue(from: object["expires_at"])
    }
}

struct ResetCreditsResponse: Decodable, Equatable, Sendable {
    let availableCount: Int?
    let credits: [ResetCredit]?

    init(from decoder: Decoder) throws {
        let root = try APIJSONValue(from: decoder)
        let object = root.objectValue ?? [:]
        let parsedCount: Int?
        if let count = object["available_count"]?.numberValue,
           count >= 0,
           count < Double(Int.max),
           count.rounded(.towardZero) == count {
            parsedCount = Int(count)
        } else {
            parsedCount = nil
        }

        let records = ["credits", "items", "data"].compactMap { object[$0]?.arrayValue }
            .first(where: { $0.allSatisfy { $0.objectValue != nil } })

        guard parsedCount != nil || records != nil else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "No recognized reset credit fields")
            )
        }

        availableCount = parsedCount
        credits = records?.map(ResetCredit.init(value:))
    }
}

indirect enum APIJSONValue: Decodable, Equatable, Sendable {
    case object([String: APIJSONValue])
    case array([APIJSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if single.decodeNil() {
            self = .null
        } else if let value = try? single.decode(String.self) {
            self = .string(value)
        } else if let value = try? single.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? single.decode(Double.self) {
            self = .number(value)
        } else if let container = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var values: [String: APIJSONValue] = [:]
            for key in container.allKeys {
                values[key.stringValue] = try container.decode(APIJSONValue.self, forKey: key)
            }
            self = .object(values)
        } else if var container = try? decoder.unkeyedContainer() {
            var values: [APIJSONValue] = []
            while !container.isAtEnd {
                values.append(try container.decode(APIJSONValue.self))
            }
            self = .array(values)
        } else {
            throw DecodingError.dataCorruptedError(in: single, debugDescription: "Unsupported JSON value")
        }
    }

    var objectValue: [String: APIJSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    var arrayValue: [APIJSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .number(let value): return String(value)
        case .bool(let value): return String(value)
        default: return nil
        }
    }

    var numberValue: Double? {
        switch self {
        case .number(let value) where value.isFinite: return value
        case .string(let value):
            guard let number = Double(value), number.isFinite else { return nil }
            return number
        default: return nil
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private extension Dictionary where Key == String, Value == APIJSONValue {
    func firstValue(for keys: [String]) -> APIJSONValue? {
        for key in keys {
            if let value = self[key] { return value }
        }
        return nil
    }
}

private extension Array where Element == [String: APIJSONValue] {
    func firstValue(for keys: [String]) -> APIJSONValue? {
        for object in self {
            if let value = object.firstValue(for: keys) { return value }
        }
        return nil
    }
}

private extension UsageWindow {
    static func dateValue(from value: APIJSONValue?) -> Date? {
        UsageWindow(value: .object(["reset_at": value ?? .null])).resetAt
    }
}
