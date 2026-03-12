import Foundation
import Testing
@testable import MCPHelperKit

@Suite("MCPServer", .serialized)
struct MCPServerTests {

    // MARK: - handleInitialize

    @Test func initializeIncludesServerName() throws {
        let output = captureResponse {
            MCPServer.handleInitialize(id: .int(1), name: "safari")
        }
        let response = try decodeResponse(output)
        let result = try #require(response.result?.dictValue)
        let serverInfo = try #require(result["serverInfo"]?.dictValue)
        let serverName = try #require(serverInfo["name"]?.stringValue)
        #expect(serverName == "atelier-safari")
    }

    @Test func initializeIncludesProtocolVersion() throws {
        let output = captureResponse {
            MCPServer.handleInitialize(id: .int(1), name: "test")
        }
        let response = try decodeResponse(output)
        let result = try #require(response.result?.dictValue)
        let version = try #require(result["protocolVersion"]?.stringValue)
        #expect(version == "2024-11-05")
    }

    // MARK: - handleToolsList

    @Test func toolsListReturnsAllTools() throws {
        let tools = [
            ToolDefinition(name: "tool_a", description: "Does A", inputSchema: .dict([:])),
            ToolDefinition(name: "tool_b", description: "Does B", inputSchema: .dict([:])),
        ]
        let output = captureResponse {
            MCPServer.handleToolsList(id: .int(1), tools: tools)
        }
        let response = try decodeResponse(output)
        let result = try #require(response.result?.dictValue)
        let toolArray = try #require(result["tools"]?.arrayValue)
        #expect(toolArray.count == 2)
        #expect(toolArray[0].dictValue?["name"]?.stringValue == "tool_a")
        #expect(toolArray[1].dictValue?["name"]?.stringValue == "tool_b")
    }

    // MARK: - handleToolsCall

    @Test func toolsCallWrapsOutputInUntrustedDocument() throws {
        let output = captureResponse {
            MCPServer.handleToolsCall(
                id: .int(1),
                params: .dict([
                    "name": .string("read_page"),
                    "arguments": .dict([:])
                ]),
                serverName: "safari"
            ) { _, _ in ("page content here", false) }
        }
        let response = try decodeResponse(output)
        let text = response.result?.dictValue?["content"]?.arrayValue?.first?.dictValue?["text"]?.stringValue
        let expected = try #require(text)
        #expect(expected.contains("<untrusted_document source=\"safari:read_page\">"))
        #expect(expected.contains("page content here"))
        #expect(expected.contains("</untrusted_document>"))
    }

    @Test func toolsCallDoesNotWrapErrors() throws {
        let output = captureResponse {
            MCPServer.handleToolsCall(
                id: .int(1),
                params: .dict([
                    "name": .string("bad_tool"),
                    "arguments": .dict([:])
                ]),
                serverName: "safari"
            ) { _, _ in ("something went wrong", true) }
        }
        let response = try decodeResponse(output)
        let result = try #require(response.result?.dictValue)
        let content = try #require(result["content"]?.arrayValue)
        let text = try #require(content.first?.dictValue?["text"]?.stringValue)
        #expect(text == "something went wrong")
        #expect(result["isError"]?.boolValue == true)
    }

    @Test func toolsCallReturnsErrorForMissingToolName() throws {
        let output = captureResponse {
            MCPServer.handleToolsCall(
                id: .int(1),
                params: .dict([:]),
                serverName: "test"
            ) { _, _ in ("", false) }
        }
        let response = try decodeResponse(output)
        let error = try #require(response.error)
        #expect(error.code == -32602)
    }

    @Test func toolsCallPassesArguments() throws {
        var receivedArgs: [String: AnyCodableValue]?
        let output = captureResponse {
            MCPServer.handleToolsCall(
                id: .int(1),
                params: .dict([
                    "name": .string("my_tool"),
                    "arguments": .dict(["url": .string("https://example.com")])
                ]),
                serverName: "test"
            ) { _, args in
                receivedArgs = args
                return ("ok", false)
            }
        }
        #expect(receivedArgs?["url"]?.stringValue == "https://example.com")
    }

    // MARK: - respond / respondError

    @Test func respondWritesValidJSON() throws {
        let output = captureResponse {
            MCPServer.respond(id: .int(1), result: .string("hello"))
        }
        let response = try decodeResponse(output)
        #expect(response.jsonrpc == "2.0")
        let result = try #require(response.result)
        #expect(result.stringValue == "hello")
        #expect(response.error == nil)
    }

    @Test func respondErrorWritesErrorJSON() throws {
        let output = captureResponse {
            MCPServer.respondError(id: .int(1), code: -32601, message: "Not found")
        }
        let response = try decodeResponse(output)
        let error = try #require(response.error)
        #expect(error.code == -32601)
        #expect(error.message == "Not found")
        #expect(response.result == nil)
    }

    // MARK: - Helpers

    /// Captures stdout output from a closure by redirecting FileHandle.
    private func captureResponse(_ block: () -> Void) -> Data {
        let pipe = Pipe()
        let original = dup(STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        block()
        fflush(stdout)
        dup2(original, STDOUT_FILENO)
        close(original)
        pipe.fileHandleForWriting.closeFile()
        return pipe.fileHandleForReading.readDataToEndOfFile()
    }

    private func decodeResponse(_ data: Data) throws -> JSONRPCResponse {
        try JSONDecoder().decode(JSONRPCResponse.self, from: data)
    }
}
