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

Cloud connectors are capabilities — they follow the same model as local Mac app capabilities, but backed by external MCP servers instead of local JXA helpers. The key insight: **local-first, cloud-optional.**

### Principle: never send the user to the Terminal

Atelier is a product for knowledge workers — writers, consultants, project managers, researchers. They should never see a terminal command, an `npm install`, a PATH variable, or a `gws auth login` prompt. Every step of discovery, installation, authentication, and configuration happens inside the app with native UI. If it can't be done with a button tap or a browser sign-in, we haven't finished the work.

### How it works

When Claude detects an intent (send email, check calendar, create task), the capability system resolves it in order:

1. **Local capability available and enabled?** Use it. Zero latency, zero auth, works offline.
2. **Local capability available but not enabled?** Suggest enabling it: "I can send this via Mail.app — allow?"
3. **No local capability, but cloud connector available?** Suggest connecting: "I can send this via Gmail if you connect your account."
4. **Both available?** Prefer local, but let the user choose. Remember their preference per project.

The user never thinks about "local vs. cloud." They say "send an email" and the system picks the best path. If they've connected Gmail and prefer it, Gmail wins. If they haven't connected anything, Mail.app works out of the box.

### Capability lifecycle

Cloud connectors introduce states beyond the simple on/off toggle of built-in capabilities:

| State | What the user sees | What happens |
|-------|-------------------|-------------|
| **Available** | Capability in the sheet with "Get" button | Binary not yet downloaded |
| **Installing** | Progress bar | Atelier downloads the binary to App Support |
| **Installed** | Capability with "Sign in" button | Binary ready, no credentials yet |
| **Authenticating** | Browser opens for OAuth | User approves in their browser |
| **Connected** | Green checkmark, tool group toggles | Fully operational |
| **Error** | Inline error with "Retry" or "Reconnect" | Auth expired, binary missing, etc. |

Every state transition is a button tap or a browser sign-in. No Terminal. No manual configuration.

### Google Workspace — first external capability

[`gws`](https://github.com/googleworkspace/cli) is a CLI that exposes Google Workspace APIs as an MCP server over stdio. It covers Gmail, Google Drive, Calendar, Sheets, Docs, Chat, and more. It publishes pre-built native macOS ARM binaries on GitHub Releases — no npm or Node.js required.

This is the first "external capability" — a binary Atelier downloads and manages, rather than one bundled in the app at compile time.

#### Installation (no Terminal)

1. User opens Capabilities sheet, sees "Google Workspace" with a "Get" button
2. Tap "Get" — Atelier downloads the macOS ARM binary from the GitHub Release
3. Binary is placed in `~/Library/Application Support/Atelier/Helpers/gws`
4. Progress bar shows download status
5. On completion, the capability transitions to "Installed — Sign in to connect"

Atelier manages the binary lifecycle: checks for updates on app launch, offers one-tap updates when new versions are available, handles cleanup on uninstall.

#### Authentication (no Terminal)

1. User taps "Sign in" — Atelier runs `gws auth login -s <services>` as a subprocess
2. Atelier embeds its own registered OAuth client ID via environment variables (`GOOGLE_WORKSPACE_CLI_CLIENT_ID`, `GOOGLE_WORKSPACE_CLI_CLIENT_SECRET`), so the user never needs a GCP project
3. The browser opens to Google's standard OAuth consent screen — the same one users see in every app that connects to Google
4. User signs in, approves scopes, browser redirects to localhost
5. `gws` captures the callback and stores encrypted credentials in `~/.config/gws/`
6. Atelier detects completion, transitions the capability to "Connected"
7. Tool group toggles appear: Gmail, Drive, Calendar, Sheets, Docs, Chat

The user sees a Google sign-in page. That's it. No GCP project, no Terminal, no configuration files.

#### Tool groups map to services

Each Google Workspace service becomes a tool group. The `gws mcp -s <services>` flag takes a comma-separated list, so Atelier dynamically builds the args from enabled groups:

| Group | Service flag | Tools | Description |
|-------|-------------|-------|-------------|
| Gmail | `gmail` | ~30 | Read, search, draft, send, label, archive email |
| Drive | `drive` | ~20 | List, search, upload, download, share files |
| Calendar | `calendar` | ~15 | Create events, check availability, manage calendars |
| Sheets | `sheets` | ~15 | Read/write cells, create spreadsheets, formulas |
| Docs | `docs` | ~10 | Create/edit documents, export |
| Chat | `chat` | ~10 | Send messages, manage spaces |

The MCP server config is rebuilt when groups change — the `-s` args list updates to match enabled groups. This is a new pattern: **dynamic args** on `MCPServerConfig`, where the args depend on which tool groups the user has enabled.

#### Local alternative awareness

Google Workspace services overlap with local Mac app capabilities:

| Cloud service | Local alternative | User preference |
|--------------|-------------------|-----------------|
| Gmail | Mail.app (Mail capability) | Per-project |
| Google Calendar | Calendar.app (future) | Per-project |
| Google Sheets | Numbers (iWork capability) | Per-project |
| Google Docs | Pages (iWork capability) | Per-project |
| Google Drive | Finder (future) | Per-project |

When both are available, the inline suggestion card shows both options. The user's choice is remembered per project.

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
- Installed cloud connectors show "Sign in" (one tap to OAuth)
- Uninstalled cloud connectors show "Get" (download, then sign in)
- Cards appear inline in the conversation, not in a modal or settings panel
- After connecting, the card collapses to a confirmation: "Gmail connected"
- The card is a suggestion, not a gate — Claude can continue the conversation without it

### Cloud connector registry

A curated, Atelier-maintained registry of external capabilities. Shipped as a bundled JSON manifest, updatable via app updates. Each entry contains:

```swift
struct ExternalCapability: Codable, Sendable {
    let id: String                    // "google-workspace"
    let name: String                  // "Google Workspace"
    let description: String           // "Gmail, Drive, Calendar, Sheets, Docs, Chat"
    let icon: String                  // SF Symbol or bundled asset
    let category: ConnectorCategory   // .productivity, .communication, .storage

    // Installation
    let binarySource: BinarySource    // .githubRelease(owner, repo, assetPattern)
    let installPath: String           // "gws" — relative to App Support/Atelier/Helpers/
    let versionCommand: [String]      // ["gws", "--version"]

    // Authentication
    let authType: AuthType            // .oauth2, .apiKey, .none
    let authCommand: [String]         // ["gws", "auth", "login", "-s"]
    let authEnv: [String: String]     // CLIENT_ID, CLIENT_SECRET injected by Atelier
    let authCheckCommand: [String]    // ["gws", "auth", "status"] — to verify auth state

    // MCP server
    let mcpCommand: [String]          // ["gws", "mcp", "-s"]
    let mcpArgsFromGroups: Bool       // true — append enabled group IDs as comma-separated arg

    // Groups and relationships
    let toolGroups: [ToolGroup]       // Gmail, Drive, Calendar, etc.
    let localAlternatives: [String: String] // "gmail" -> "mail", mapping group to local capability
    let intents: [String]             // ["send-email", "read-email", "manage-files"]
}
```

### Curated launch set

| Connector | Category | Services / Groups | Local Alternative | Auth |
|-----------|----------|-------------------|-------------------|------|
| **Google Workspace** | Productivity | Gmail, Drive, Calendar, Sheets, Docs, Chat | Mail.app, iWork, Calendar.app | OAuth 2.0 |
| Slack | Communication | Messages, Channels, Files | — | OAuth 2.0 |
| Notion | Productivity | Pages, Databases, Search | Notes.app | OAuth 2.0 |
| Linear | Productivity | Issues, Projects, Cycles | Reminders.app | OAuth 2.0 |
| Todoist | Productivity | Tasks, Projects, Labels | Reminders.app | OAuth 2.0 |

Google Workspace ships first. It replaces 6 separate connectors (Gmail, Drive, Calendar, Sheets, Docs, Chat) with one install and one sign-in. Other connectors follow the same pattern — external binary with MCP server, downloaded and managed by Atelier.

### OAuth flow

1. User taps "Sign in" on a capability or an inline suggestion card
2. Atelier launches the connector's auth command as a subprocess with embedded credentials
3. The browser opens to the provider's OAuth consent screen
4. On success, the connector stores tokens (each manages its own credential storage)
5. Atelier detects auth completion (polls the auth check command) and transitions state
6. Claude resumes the interrupted task with the new capability available

For connectors that need Keychain-managed tokens (future custom connectors), `ASWebAuthenticationSession` handles the OAuth flow directly and stores tokens in Keychain (per security/04-credential-storage.md).

### Per-project preferences

When both a local capability and a cloud connector handle the same intent, the user's choice is remembered per project:

- "Pagina web De cocina" project uses Gmail (team collaboration via Google Workspace)
- "Personal" project uses Mail.app (personal preference, works offline)

Stored in the project's `capabilities.json` alongside the existing capability toggle state.

## Implementation

### Phase 1 — External Capability Lifecycle

- `ExternalCapabilityManager` — downloads, installs, updates, and removes external binaries
- Binary storage in `~/Library/Application Support/Atelier/Helpers/`
- Version checking and one-tap update flow
- `CapabilityRegistry` extended with a second source: external capabilities discovered at runtime
- `MCPServerConfig` extended with dynamic args (rebuilt when enabled groups change)
- Capability state machine: available → installing → installed → authenticating → connected → error

### Phase 2 — Google Workspace Connector

- Register `gws` as the first external capability
- Embed OAuth client ID/secret for zero-config auth
- Map 6 Google services to tool groups with dynamic `-s` flag
- Auth flow: subprocess + browser OAuth + polling for completion
- Local alternative mapping: Gmail ↔ Mail.app, Calendar ↔ Calendar.app, etc.

### Phase 3 — Inline Suggestion Card

- New `TimelineContent` case: `.capabilitySuggestion([CapabilitySuggestion])`
- `CapabilitySuggestionCard` SwiftUI view with "Ready to use" / "Sign in" / "Get" states
- System prompt injection tells Claude how to trigger suggestions
- Card collapses after user acts — connected, dismissed, or timed out

### Phase 4 — Registry & Resolution

- `CloudConnectorRegistry` — loads bundled manifest, resolves intents to available connectors
- Intent matching — maps Claude's detected intent to local capabilities + cloud connectors
- Unified `CapabilitySuggestion` model that holds both local and cloud options ranked by preference
- Additional connectors: Slack, Notion, Linear, Todoist

### Phase 5 — Preference Learning

- Track user choices when both local and cloud are available
- Per-project preference storage in `capabilities.json`
- Claude's system prompt includes preference context: "User prefers Gmail over Mail.app in this project"
- Preference can be overridden per message: "send this via Mail.app instead"

## Dependencies

- hub/03-plugin-management.md (capability model and registry — extends it with external entries)
- hub/04-mcp-connector-health.md (health monitoring applies to cloud connectors)
- security/04-credential-storage.md (future custom connectors use Keychain)
- experience/03-conversational-flow.md (inline suggestion card as new content type)

## Notes

The philosophy: **local-first, cloud-optional.** Cowork treats everything as a cloud connector requiring setup. Atelier's advantage is that local Mac apps work instantly — cloud connectors are there for people who live in cloud ecosystems, not as the only path.

The "never send to Terminal" principle is non-negotiable. Every competitor's cloud integration story involves "install this CLI" or "run this command" or "add this to your config." Atelier handles all of that invisibly. The user sees service names they recognize (Gmail, Slack, Google Calendar), taps a button, signs in through their browser, and it works. If we can't make it that simple, we haven't shipped it yet.

The inline suggestion card is the critical UX piece. Cowork gets this right — the connector appears in the conversation where the user needs it, not buried in settings. We should match this UX but improve it by showing local alternatives that need zero setup alongside cloud options that need one tap.

Google Workspace ships first because `gws` gives us 6 services with one binary, one auth flow, and a production-ready MCP server. It's the highest leverage first connector.

The registry should be small and curated at launch. Five to eight high-quality connectors that work reliably beat fifty that fail 25% of the time. Quality over quantity — every connector in the registry must meet the health standards defined in hub/04-mcp-connector-health.md.

Never show "MCP," "connector," "CLI," or "server" in the UI. The user sees "Gmail," "Slack," "Google Calendar" — services they already know. The infrastructure is invisible.

---

*Back to [Index](../../INDEX.md)*
