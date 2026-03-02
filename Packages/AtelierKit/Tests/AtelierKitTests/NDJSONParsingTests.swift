import Foundation
import Testing
@testable import AtelierKit

@Suite("NDJSON parsing")
struct NDJSONParsingTests {
    private let decoder = JSONDecoder()

    @Test("System init extracts session ID")
    func systemInitExtractsSessionId() throws {
        let json = """
        {"type":"system","subtype":"init","session_id":"sess-abc-123","tools":[],"mcp_servers":[]}
        """
        let data = Data(json.utf8)
        let envelope = try decoder.decode(CLIMessage.self, from: data)
        #expect(envelope.type == "system")
        #expect(envelope.subtype == "init")

        let initEvent = try decoder.decode(CLISystemInit.self, from: data)
        #expect(initEvent.sessionId == "sess-abc-123")
    }

    @Test("Text delta extracts chunk")
    func textDeltaExtractsChunk() throws {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}}
        """
        let data = Data(json.utf8)
        let envelope = try decoder.decode(CLIMessage.self, from: data)
        #expect(envelope.type == "stream_event")

        let streamEvent = try decoder.decode(CLIStreamEvent.self, from: data)
        #expect(streamEvent.event.type == "content_block_delta")
        #expect(streamEvent.event.delta?.type == "text_delta")
        #expect(streamEvent.event.delta?.text == "Hello")
    }

    @Test("Result extracts usage")
    func resultExtractsUsage() throws {
        let json = """
        {"type":"result","subtype":"success","is_error":false,"usage":{"input_tokens":42,"output_tokens":17},"result":"Done"}
        """
        let data = Data(json.utf8)
        let result = try decoder.decode(CLIResult.self, from: data)
        #expect(result.isError == false)
        #expect(result.usage?.inputTokens == 42)
        #expect(result.usage?.outputTokens == 17)
        #expect(result.result == "Done")
    }

    @Test("Result detects error")
    func resultDetectsError() throws {
        let json = """
        {"type":"result","subtype":"error_unknown","is_error":true,"result":"Something went wrong"}
        """
        let data = Data(json.utf8)
        let result = try decoder.decode(CLIResult.self, from: data)
        #expect(result.isError == true)
        #expect(result.result == "Something went wrong")
    }

    @Test("Unknown event type decodes envelope")
    func unknownEventTypeDecodesEnvelope() throws {
        let json = """
        {"type":"assistant","message":{"role":"assistant"}}
        """
        let data = Data(json.utf8)
        let envelope = try decoder.decode(CLIMessage.self, from: data)
        #expect(envelope.type == "assistant")
        #expect(envelope.subtype == nil)
    }

    @Test("Thinking block start parses content block type")
    func thinkingBlockStartParsesContentBlockType() throws {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"thinking"}}}
        """
        let data = Data(json.utf8)
        let streamEvent = try decoder.decode(CLIStreamEvent.self, from: data)
        #expect(streamEvent.event.type == "content_block_start")
        #expect(streamEvent.event.contentBlock?.type == "thinking")
    }

    @Test("Thinking delta extracts text")
    func thinkingDeltaExtractsText() throws {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"Let me consider"}}}
        """
        let data = Data(json.utf8)
        let streamEvent = try decoder.decode(CLIStreamEvent.self, from: data)
        #expect(streamEvent.event.type == "content_block_delta")
        #expect(streamEvent.event.delta?.type == "thinking_delta")
        #expect(streamEvent.event.delta?.thinking == "Let me consider")
    }

    @Test("Tool use block start parses ID and name")
    func toolUseBlockStartParsesIdAndName() throws {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_123","name":"Read"}}}
        """
        let data = Data(json.utf8)
        let streamEvent = try decoder.decode(CLIStreamEvent.self, from: data)
        #expect(streamEvent.event.type == "content_block_start")
        #expect(streamEvent.event.index == 1)
        #expect(streamEvent.event.contentBlock?.type == "tool_use")
        #expect(streamEvent.event.contentBlock?.id == "toolu_123")
        #expect(streamEvent.event.contentBlock?.name == "Read")
    }

    @Test("Input JSON delta parses partial JSON")
    func inputJsonDeltaParsesPartialJson() throws {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\\"file_path\\":\\"src/"}}}
        """
        let data = Data(json.utf8)
        let streamEvent = try decoder.decode(CLIStreamEvent.self, from: data)
        #expect(streamEvent.event.delta?.type == "input_json_delta")
        #expect(streamEvent.event.delta?.partialJson == "{\"file_path\":\"src/")
        #expect(streamEvent.event.index == 1)
    }

    @Test("Content block stop parses index")
    func contentBlockStopParsesIndex() throws {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_stop","index":1}}
        """
        let data = Data(json.utf8)
        let streamEvent = try decoder.decode(CLIStreamEvent.self, from: data)
        #expect(streamEvent.event.type == "content_block_stop")
        #expect(streamEvent.event.index == 1)
    }

    @Test("User message with tool_result parses content blocks")
    func userMessageWithToolResultParsesContentBlocks() throws {
        let json = """
        {"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_abc","content":"file contents here"}]}}
        """
        let data = Data(json.utf8)
        let envelope = try decoder.decode(CLIMessage.self, from: data)
        #expect(envelope.type == "user")

        let userMsg = try decoder.decode(CLIUserMessage.self, from: data)
        #expect(userMsg.message.content.count == 1)
        let block = userMsg.message.content[0]
        #expect(block.type == "tool_result")
        #expect(block.toolUseId == "toolu_abc")
        #expect(block.content?.text == "file contents here")
    }

    @Test("Tool result with array content parses parts")
    func toolResultWithArrayContentParsesParts() throws {
        let json = """
        {"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_xyz","content":[{"type":"text","text":"line 1"},{"type":"text","text":"line 2"}]}]}}
        """
        let data = Data(json.utf8)
        let userMsg = try decoder.decode(CLIUserMessage.self, from: data)
        let block = userMsg.message.content[0]
        #expect(block.toolUseId == "toolu_xyz")
        #expect(block.content?.text == "line 1line 2")
    }

    @Test("Tool result with no content parses as nil")
    func toolResultWithNoContentParsesAsNil() throws {
        let json = """
        {"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_empty"}]}}
        """
        let data = Data(json.utf8)
        let userMsg = try decoder.decode(CLIUserMessage.self, from: data)
        let block = userMsg.message.content[0]
        #expect(block.toolUseId == "toolu_empty")
        #expect(block.content == nil)
    }

    @Test("Text block parses with optional fields absent")
    func textBlockStillParsesWithOptionalFields() throws {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"text"}}}
        """
        let data = Data(json.utf8)
        let streamEvent = try decoder.decode(CLIStreamEvent.self, from: data)
        #expect(streamEvent.event.contentBlock?.type == "text")
        #expect(streamEvent.event.contentBlock?.id == nil)
        #expect(streamEvent.event.contentBlock?.name == nil)
    }
}
