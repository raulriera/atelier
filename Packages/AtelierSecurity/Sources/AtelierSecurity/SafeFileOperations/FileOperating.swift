import Foundation

/// Abstracts FileManager operations for testability.
public protocol FileOperating: Sendable {
    func trashItem(at url: URL) throws -> URL
    func moveItem(from: URL, to: URL) throws
    func copyItem(from: URL, to: URL) throws
    func fileExists(at url: URL) -> Bool
}
