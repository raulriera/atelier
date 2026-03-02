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

    @Test func thinkingBlockStartParsesContentBlockType() throws {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"thinking"}}}
        """
        let data = json.data(using: .utf8)!
        let streamEvent = try decoder.decode(CLIStreamEvent.self, from: data)
        #expect(streamEvent.event.type == "content_block_start")
        #expect(streamEvent.event.contentBlock?.type == "thinking")
    }

    @Test func thinkingDeltaExtractsText() throws {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"Let me consider"}}}
        """
        let data = json.data(using: .utf8)!
        let streamEvent = try decoder.decode(CLIStreamEvent.self, from: data)
        #expect(streamEvent.event.type == "content_block_delta")
        #expect(streamEvent.event.delta?.type == "thinking_delta")
        #expect(streamEvent.event.delta?.thinking == "Let me consider")
    }

    @Test func toolUseBlockStartParsesIdAndName() throws {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_123","name":"Read"}}}
        """
        let data = json.data(using: .utf8)!
        let streamEvent = try decoder.decode(CLIStreamEvent.self, from: data)
        #expect(streamEvent.event.type == "content_block_start")
        #expect(streamEvent.event.index == 1)
        #expect(streamEvent.event.contentBlock?.type == "tool_use")
        #expect(streamEvent.event.contentBlock?.id == "toolu_123")
        #expect(streamEvent.event.contentBlock?.name == "Read")
    }

    @Test func inputJsonDeltaParsesPartialJson() throws {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\\"file_path\\":\\"src/"}}}
        """
        let data = json.data(using: .utf8)!
        let streamEvent = try decoder.decode(CLIStreamEvent.self, from: data)
        #expect(streamEvent.event.delta?.type == "input_json_delta")
        #expect(streamEvent.event.delta?.partialJson == "{\"file_path\":\"src/")
        #expect(streamEvent.event.index == 1)
    }

    @Test func contentBlockStopParsesIndex() throws {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_stop","index":1}}
        """
        let data = json.data(using: .utf8)!
        let streamEvent = try decoder.decode(CLIStreamEvent.self, from: data)
        #expect(streamEvent.event.type == "content_block_stop")
        #expect(streamEvent.event.index == 1)
    }

    @Test func textBlockStillParsesWithOptionalFields() throws {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"text"}}}
        """
        let data = json.data(using: .utf8)!
        let streamEvent = try decoder.decode(CLIStreamEvent.self, from: data)
        #expect(streamEvent.event.contentBlock?.type == "text")
        #expect(streamEvent.event.contentBlock?.id == nil)
        #expect(streamEvent.event.contentBlock?.name == nil)
    }
}
