# Cloud Connectors

> **Category:** Hub / Unified Experience
> **Type:** New Capability · **Priority:** High
> **Milestone:** M3

---

## Problem

Atelier's capability model covers local Mac apps (Mail.app, Calendar.app, Reminders, iWork) — things that work instantly via JXA/AppleScript with zero setup. But many knowledge workers live in cloud services: Gmail, Google Calendar, Slack, Notion, Linear, Todoist, Google Drive, Dropbox. Cowork ships 10+ cloud connectors with inline OAuth and a searchable registry. Atelier has no story for cloud services.

A consultant who uses Google Calendar instead of Calendar.app, or a team that runs on Slack instead of Messages, hits a wall. The local capability doesn't help. They need the cloud connector — and right now, only power users who know how to configure custom MCP servers can get there.

### What Cowork does today

When a user asks "send a message to myself," Cowork:

1. Searches a connector registry (Gmail, Slack, Klaviyo, Glean, Attio, etc.)
2. Renders a "Suggested connectors" card inline with descriptions and "+ Connect" buttons
3. One tap triggers an OAuth flow
4. The connector is live immediately — no restart, no configuration

This is the right UX. But Cowork's implementation has problems: ~25% failure rate, no crash isolation, no health monitoring, no local alternatives. Every connector requires cloud auth even when a local app could do the same thing.

## Solution

Cloud connectors are capabilities — they follow the same model as local Mac app capabilities, but backed by remote MCP servers instead of local JXA helpers. The key insight: **local-first, cloud-optional.**

### How it works

When Claude detects an intent (send email, check calendar, create task), the capability system resolves it in order:

1. **Local capability available and enabled?** Use it. Zero latency, zero auth, works offline.
2. **Local capability available but not enabled?** Suggest enabling it: "I can send this via Mail.app — allow?"
3. **No local capability, but cloud connector available?** Suggest connecting: "I can send this via Gmail if you connect your account."
4. **Both available?** Prefer local, but let the user choose. Remember their preference per project.

The user never thinks about "local vs. cloud." They say "send an email" and the system picks the best path. If they've connected Gmail and prefer it, Gmail wins. If they haven't connected anything, Mail.app works out of the box.

### Inline capability suggestion card

A new conversation content type — the bridge between Claude detecting an intent and the user enabling a capability:

```
+----------------------------------------------+
|  Suggested capabilities           2 options   |
|                                               |
|  [icon]  Mail.app                Ready to use |
|  Send and read emails via Mail                |
|                                               |
|  [icon]  Gmail                     + Connect  |
|  Draft replies, search your inbox             |
+----------------------------------------------+
```

Design rules:
- Local capabilities show "Ready to use" (no setup required)
- Cloud connectors show "+ Connect" (one tap to OAuth)
- Cards appear inline in the conversation, not in a modal or settings panel
- After connecting, the card collapses to a confirmation: "Gmail connected"
- The card is a suggestion, not a gate — Claude can continue the conversation without it

### Cloud connector registry

A curated, Anthropic-maintained registry of cloud MCP servers. Shipped as a bundled JSON manifest, updatable via app updates. Each entry contains:

```swift
struct CloudConnector: Codable, Sendable {
    let id: String                    // "gmail", "slack", "notion"
    let name: String                  // "Gmail"
    let description: String           // "Draft replies, search your inbox"
    let icon: String                  // SF Symbol or bundled asset
    let category: ConnectorCategory   // .communication, .productivity, .storage
    let authType: AuthType            // .oauth2, .apiKey, .none
    let oauthConfig: OAuthConfig?     // endpoints, scopes, client ID
    let mcpServerURL: URL             // remote MCP server endpoint
    let localAlternative: String?     // "mail" — maps to a local capability ID
    let intents: [String]             // ["send-email", "read-email", "search-email"]
}
```

Intent matching is how Claude knows which connectors to suggest. When Claude's tool use implies "send-email," the registry returns all capabilities (local and cloud) that handle that intent, ranked by availability.

### Curated launch set

| Cloud Connector | Category | Local Alternative | Auth |
|----------------|----------|-------------------|------|
| Gmail | Communication | Mail.app | OAuth 2.0 |
| Google Calendar | Productivity | Calendar.app | OAuth 2.0 |
| Slack | Communication | — | OAuth 2.0 |
| Notion | Productivity | Notes.app | OAuth 2.0 |
| Linear | Productivity | Reminders.app | OAuth 2.0 |
| Todoist | Productivity | Reminders.app | OAuth 2.0 |
| Google Drive | Storage | Finder | OAuth 2.0 |
| Dropbox | Storage | Finder | OAuth 2.0 |

This is the launch set. The registry is extensible — new connectors added via app updates, no user action required. Power users can still add custom MCP servers via context files for anything not in the registry.

### OAuth flow

1. User taps "+ Connect" on an inline suggestion card
2. `ASWebAuthenticationSession` opens the provider's OAuth consent screen
3. On success, tokens are stored in Keychain (per security/04-credential-storage.md)
4. The MCP server connection is established immediately
5. Claude resumes the interrupted task with the new capability available

Token refresh is automatic and invisible (per hub/04-mcp-connector-health.md). If a refresh token expires, a re-auth prompt appears inline in the conversation — one tap to fix.

### Per-project preferences

When both a local capability and a cloud connector handle the same intent, the user's choice is remembered per project:

- "Pagina web De cocina" project uses Gmail (team collaboration via Google Workspace)
- "Personal" project uses Mail.app (personal preference, works offline)

Stored in the project's `capabilities.json` alongside the existing capability toggle state.

## Implementation

### Phase 1 — Registry & Resolution

- `CloudConnectorRegistry` — loads bundled manifest, resolves intents to available connectors
- Intent matching — maps Claude's detected intent to local capabilities + cloud connectors
- Unified `CapabilitySuggestion` model that holds both local and cloud options ranked by preference
- Extend `CapabilityStore` to track cloud connector state (disconnected, connecting, connected, error)

### Phase 2 — Inline Suggestion Card

- New `TimelineContent` case: `.capabilitySuggestion([CapabilitySuggestion])`
- `CapabilitySuggestionCard` SwiftUI view with local "Ready to use" vs. cloud "+ Connect" states
- System prompt injection tells Claude how to trigger suggestions (extending existing capability prompt)
- Card collapses after user acts — connected, dismissed, or timed out

### Phase 3 — OAuth & Connection

- `ASWebAuthenticationSession` for OAuth 2.0 flows
- Token storage in Keychain via existing credential infrastructure
- Automatic token refresh with silent retry
- MCP server connection lifecycle: connect on auth, disconnect on revoke, reconnect on token refresh
- XPC isolation for cloud MCP server processes

### Phase 4 — Preference Learning

- Track user choices when both local and cloud are available
- Per-project preference storage in `capabilities.json`
- Claude's system prompt includes preference context: "User prefers Gmail over Mail.app in this project"
- Preference can be overridden per message: "send this via Mail.app instead"

## Dependencies

- hub/03-plugin-management.md (capability model and registry — extends it with cloud entries)
- hub/04-mcp-connector-health.md (health monitoring applies to cloud connectors)
- security/04-credential-storage.md (OAuth tokens in Keychain)
- experience/03-conversational-flow.md (inline suggestion card as new content type)

## Notes

The philosophy: **local-first, cloud-optional.** Cowork treats everything as a cloud connector requiring setup. Atelier's advantage is that local Mac apps work instantly — cloud connectors are there for people who live in cloud ecosystems, not as the only path.

The inline suggestion card is the critical UX piece. Cowork gets this right — the connector appears in the conversation where the user needs it, not buried in settings. We should match this UX but improve it by showing local alternatives that need zero setup alongside cloud options that need one tap.

The registry should be small and curated at launch. Eight to ten high-quality connectors that work reliably beat fifty that fail 25% of the time. Quality over quantity — every connector in the registry must meet the health standards defined in hub/04-mcp-connector-health.md.

Never show "MCP," "connector," or "server" in the UI. The user sees "Gmail," "Slack," "Google Calendar" — services they already know. The infrastructure is invisible.

---

*Back to [Index](../../INDEX.md)*
