import Foundation

/// A type-erased Codable value for JSON-RPC params and results.
///
/// Handles the dynamic JSON structures in the MCP protocol where
/// params and results can be strings, numbers, booleans, arrays,
/// dictionaries, or null.
public enum AnyCodableValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dict([String: AnyCodableValue])
    case array([AnyCodableValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode([String: AnyCodableValue].self) {
            self = .dict(v)
        } else if let v = try? container.decode([AnyCodableValue].self) {
            self = .array(v)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .dict(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }

    /// Extracts the string value, or nil if this is not a `.string`.
    public var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    /// Extracts the integer value, or nil if this is not an `.int`.
    public var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    /// Extracts the boolean value, or nil if this is not a `.bool`.
    public var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    /// Extracts the dictionary value, or nil if this is not a `.dict`.
    public var dictValue: [String: AnyCodableValue]? {
        if case .dict(let v) = self { return v }
        return nil
    }

    /// Extracts the array value, or nil if this is not an `.array`.
    public var arrayValue: [AnyCodableValue]? {
        if case .array(let v) = self { return v }
        return nil
    }
}
