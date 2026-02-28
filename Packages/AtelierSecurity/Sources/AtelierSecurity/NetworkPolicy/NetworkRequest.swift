import Foundation

/// A lightweight descriptor of a network request for policy evaluation.
public struct NetworkRequest: Sendable {
    public let host: String
    public let port: Int?
    public let method: String?
    public let payloadSize: Int
    public let payloadSample: String?

    public init(
        host: String,
        port: Int? = nil,
        method: String? = nil,
        payloadSize: Int = 0,
        payloadSample: String? = nil
    ) {
        self.host = host
        self.port = port
        self.method = method
        self.payloadSize = payloadSize
        self.payloadSample = payloadSample
    }
}
