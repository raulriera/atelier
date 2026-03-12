import Foundation
import Testing
@testable import MCPHelperKit

@Suite("AnyCodableValue")
struct AnyCodableValueTests {

    @Test func decodesString() throws {
        let json = Data("\"hello\"".utf8)
        let value = try JSONDecoder().decode(AnyCodableValue.self, from: json)
        #expect(value.stringValue == "hello")
    }

    @Test func decodesInt() throws {
        let json = Data("42".utf8)
        let value = try JSONDecoder().decode(AnyCodableValue.self, from: json)
        #expect(value.intValue == 42)
    }

    @Test func decodesBool() throws {
        let json = Data("true".utf8)
        let value = try JSONDecoder().decode(AnyCodableValue.self, from: json)
        #expect(value.boolValue == true)
    }

    @Test func decodesNull() throws {
        let json = Data("null".utf8)
        let value = try JSONDecoder().decode(AnyCodableValue.self, from: json)
        guard case .null = value else {
            Issue.record("Expected .null, got \(value)")
            return
        }
    }

    @Test func decodesDict() throws {
        let json = Data("{\"key\":\"value\"}".utf8)
        let value = try JSONDecoder().decode(AnyCodableValue.self, from: json)
        #expect(value.dictValue?["key"]?.stringValue == "value")
    }

    @Test func decodesArray() throws {
        let json = Data("[1,2,3]".utf8)
        let value = try JSONDecoder().decode(AnyCodableValue.self, from: json)
        #expect(value.arrayValue?.count == 3)
    }

    @Test func roundTripsNestedStructure() throws {
        let original = AnyCodableValue.dict([
            "name": .string("test"),
            "count": .int(5),
            "active": .bool(true),
            "tags": .array([.string("a"), .string("b")]),
            "meta": .null
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        #expect(decoded.dictValue?["name"]?.stringValue == "test")
        #expect(decoded.dictValue?["count"]?.intValue == 5)
        #expect(decoded.dictValue?["active"]?.boolValue == true)
        #expect(decoded.dictValue?["tags"]?.arrayValue?.count == 2)
    }

    @Test func accessorsReturnNilForWrongType() {
        let value = AnyCodableValue.string("hello")
        #expect(value.intValue == nil)
        #expect(value.boolValue == nil)
        #expect(value.dictValue == nil)
        #expect(value.arrayValue == nil)
    }
}
