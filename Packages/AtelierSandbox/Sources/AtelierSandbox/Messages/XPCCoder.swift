import Foundation

/// JSON encode/decode helper for XPC transport.
///
/// Caseless enum — no instances, just static methods.
public enum XPCCoder {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            throw SandboxError.encodingFailed(String(describing: error))
        }
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw SandboxError.decodingFailed(String(describing: error))
        }
    }
}
