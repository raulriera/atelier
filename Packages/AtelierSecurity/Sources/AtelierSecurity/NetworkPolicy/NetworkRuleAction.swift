/// The action to take when a network rule matches.
public enum NetworkRuleAction: String, Sendable {
    case allow
    case deny
    case log
}
