public enum EngineError: Error, Sendable {
    case cliNotFound
    case processFailure(exitCode: Int, stderr: String)
    case decodingError(String)
    case cliError(String)
}
