import Foundation

// MARK: - Top-level NDJSON discriminator

struct CLIMessage: Decodable {
    let type: String
    let subtype: String?
}

// MARK: - system init (session start)

struct CLISystemInit: Decodable {
    let type: String // "system"
    let subtype: String // "init"
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, subtype
        case sessionId = "session_id"
    }
}

// MARK: - stream_event (token-by-token deltas)

struct CLIStreamEvent: Decodable {
    let type: String // "stream_event"
    let event: RawStreamEvent
}

struct RawStreamEvent: Decodable {
    let type: String // "content_block_delta", "content_block_start", "message_start", etc.
    let index: Int?
    let delta: RawDelta?
    let usage: RawUsage?
    let contentBlock: RawContentBlock?

    enum CodingKeys: String, CodingKey {
        case type, index, delta, usage
        case contentBlock = "content_block"
    }
}

struct RawContentBlock: Decodable {
    let type: String // "thinking", "text", "tool_use", etc.
    let id: String?
    let name: String?
}

struct RawDelta: Decodable {
    let type: String // "text_delta", "thinking_delta", "input_json_delta"
    let text: String?
    let thinking: String?
    let partialJson: String?

    enum CodingKeys: String, CodingKey {
        case type, text, thinking
        case partialJson = "partial_json"
    }
}

// MARK: - result (final message)

struct CLIResult: Decodable {
    let type: String // "result"
    let subtype: String? // "success", "error_*"
    let isError: Bool?
    let usage: RawUsage?
    let result: String?

    enum CodingKeys: String, CodingKey {
        case type, subtype, result, usage
        case isError = "is_error"
    }
}

// MARK: - Shared

struct RawUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}
