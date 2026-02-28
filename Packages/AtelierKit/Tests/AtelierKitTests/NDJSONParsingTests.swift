import Foundation
import Testing
@testable import AtelierKit

struct NDJSONParsingTests {
    private let decoder = JSONDecoder()

    @Test func systemInitExtractsSessionId() throws {
        let json = """
        {"type":"system","subtype":"init","session_id":"sess-abc-123","tools":[],"mcp_servers":[]}
        """
        let data = json.data(using: .utf8)!
        let envelope = try decoder.decode(CLIMessage.self, from: data)
        #expect(envelope.type == "system")
        #expect(envelope.subtype == "init")

        let initEvent = try decoder.decode(CLISystemInit.self, from: data)
        #expect(initEvent.sessionId == "sess-abc-123")
    }

    @Test func textDeltaExtractsChunk() throws {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}}
        """
        let data = json.data(using: .utf8)!
        let envelope = try decoder.decode(CLIMessage.self, from: data)
        #expect(envelope.type == "stream_event")

        let streamEvent = try decoder.decode(CLIStreamEvent.self, from: data)
        #expect(streamEvent.event.type == "content_block_delta")
        #expect(streamEvent.event.delta?.type == "text_delta")
        #expect(streamEvent.event.delta?.text == "Hello")
    }

    @Test func resultExtractsUsage() throws {
        let json = """
        {"type":"result","subtype":"success","is_error":false,"usage":{"input_tokens":42,"output_tokens":17},"result":"Done"}
        """
        let data = json.data(using: .utf8)!
        let result = try decoder.decode(CLIResult.self, from: data)
        #expect(result.isError == false)
        #expect(result.usage?.inputTokens == 42)
        #expect(result.usage?.outputTokens == 17)
        #expect(result.result == "Done")
    }

    @Test func resultDetectsError() throws {
        let json = """
        {"type":"result","subtype":"error_unknown","is_error":true,"result":"Something went wrong"}
        """
        let data = json.data(using: .utf8)!
        let result = try decoder.decode(CLIResult.self, from: data)
        #expect(result.isError == true)
        #expect(result.result == "Something went wrong")
    }

    @Test func unknownEventTypeDecodesEnvelope() throws {
        let json = """
        {"type":"assistant","message":{"role":"assistant"}}
        """
        let data = json.data(using: .utf8)!
        let envelope = try decoder.decode(CLIMessage.self, from: data)
        #expect(envelope.type == "assistant")
        #expect(envelope.subtype == nil)
    }
}
