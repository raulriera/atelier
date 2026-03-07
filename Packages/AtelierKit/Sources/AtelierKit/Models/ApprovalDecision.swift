/// The user's decision on a tool approval request.
public enum ApprovalDecision: Sendable {
    case allow
    case allowForSession
    case deny(reason: String)
}
