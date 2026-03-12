import Testing
@testable import MCPHelperKit

@Suite("JXA utilities")
struct JXATests {

    struct EscapeCase: CustomTestStringConvertible, Sendable {
        let input: String
        let expected: String
        let label: String
        var testDescription: String { label }
    }

    static let escapeCases: [EscapeCase] = [
        EscapeCase(input: "hello", expected: "hello", label: "plain text unchanged"),
        EscapeCase(input: "say \"hi\"", expected: "say \\\"hi\\\"", label: "escapes double quotes"),
        EscapeCase(input: "back\\slash", expected: "back\\\\slash", label: "escapes backslashes"),
        EscapeCase(input: "line\none", expected: "line\\none", label: "escapes newlines"),
        EscapeCase(input: "col\tone", expected: "col\\tone", label: "escapes tabs"),
        EscapeCase(input: "ret\rone", expected: "ret\\rone", label: "escapes carriage returns"),
    ]

    @Test("jxaEscape handles", arguments: escapeCases)
    func escapes(c: EscapeCase) {
        #expect(jxaEscape(c.input) == c.expected)
    }
}
