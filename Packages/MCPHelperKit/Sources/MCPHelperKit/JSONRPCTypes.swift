import Foundation

/// An incoming JSON-RPC 2.0 request from the MCP client.
public struct JSONRPCRequest: Codable, Sendable {
    public let jsonrpc: String
    public let id: AnyCodableValue?
    public let method: String
    public let params: AnyCodableValue?
}

/// An outgoing JSON-RPC 2.0 response to the MCP client.
public struct JSONRPCResponse: Codable, Sendable {
    public let jsonrpc: String
    public let id: AnyCodableValue?
    public let result: AnyCodableValue?
    public let error: JSONRPCError?
}

/// A JSON-RPC 2.0 error object.
public struct JSONRPCError: Codable, Sendable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
}
