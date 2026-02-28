import Foundation

/// Errors that can occur during credential storage operations.
public enum CredentialError: Error, Sendable {
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    case notFound
    case accessDenied(status: OSStatus)
}
