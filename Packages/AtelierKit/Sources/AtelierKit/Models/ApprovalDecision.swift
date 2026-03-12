/// The user's decision on a tool approval request.
public enum ApprovalDecision: Sendable {
    case allow
    case allowForSession
    case deny(reason: String)

    /// Whether the decision grants permission (either once or for the session).
    public var isAllowed: Bool {
        switch self {
        case .allow, .allowForSession: true
        case .deny: false
        }
    }
}
