import Foundation

/// `NSXPCListenerDelegate` for the sandbox XPC service process.
///
/// Configures incoming connections with the `SandboxXPCProtocol` interface
/// and exports a `SandboxServiceHandler` instance.
public final class SandboxServiceDelegate: NSObject, NSXPCListenerDelegate, Sendable {
    private let handler: SandboxServiceHandler

    public init(handler: SandboxServiceHandler = SandboxServiceHandler()) {
        self.handler = handler
    }

    public func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(
            with: SandboxXPCProtocol.self
        )
        newConnection.exportedObject = handler
        newConnection.resume()
        return true
    }
}
