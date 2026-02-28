import Foundation

/// Wire protocol for the XPC service. Uses raw `Data` for Codable transport.
///
/// A single method handles all operations — the request enum case determines
/// dispatch. Adding new operations never changes this protocol.
@objc public protocol SandboxXPCProtocol {
    func performOperation(
        _ requestData: Data,
        reply: @escaping @Sendable (Data?, Data?) -> Void
    )
}
