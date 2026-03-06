# Capabilities

> **Category:** Hub / Unified Experience
> **Type:** Improvement · **Priority:** 🟠 High

---

## Current State (Electron / Cowork)

11+ starter plugins, private enterprise marketplaces via GitHub — but management is clunky and the failure rate is approximately 25%. Plugins fail silently, there's no crash isolation (a bad plugin can destabilize the app), and no health monitoring. Users have to install, configure, and manage plugins manually. Most people never bother.

## Native macOS Approach

No plugins. No marketplace. No configuration screens. **Capabilities** — things Claude can do — that surface when needed and disappear when they're not.

### How it works

Capabilities are the things Claude can do beyond basic conversation: read files, search the web, access a calendar, send an email, query a database. Some are built-in. Some need a one-time connection. None require manual installation or configuration.

**Built-in capabilities** just work. File reading, writing, searching within a project — these are part of the app. No setup.

**On-demand capabilities** surface when Claude needs them:

> "I can look up flight prices if you enable web search. Allow?"
> → One tap. Done.

> "I can check your calendar if you connect Google Calendar."
> → One tap → OAuth sign-in → Done.

The user never sees "MCP," "plugin," or "connector." They see a capability name ("web search," "Google Calendar") and a permission prompt. The app manages the underlying MCP server lifecycle invisibly — starting, connecting, health-checking, restarting on crash.

### Progressive disclosure layers

| User level | Experience |
|-----------|-----------|
| Everyone | Built-in capabilities work out of the box |
| Regular users | Claude asks to enable things when needed, one-tap approval |
| Power users | A capabilities section in project settings to browse and pre-configure |
| Developers | Can add custom MCP server URLs in the context file |

### The context file connection

Capabilities can be declared in a project's context file:

```
capabilities: [web-search, google-calendar]
```

Just names. Not server URLs, not commands, not port numbers. Atelier resolves them from a built-in registry. When the project opens, those capabilities are available immediately.

For developers building custom tools, the deepest layer supports full MCP server configuration — but this is explicitly a power-user feature that nobody else ever sees.

## Current Implementation

The capabilities architecture is live with iWork, Safari, and Mail as built-in capabilities:

- **Capability models** — `Capability`, `ToolGroup`, `MCPServerConfig`, `EnabledCapability`, `CapabilityRegistry` in `AtelierKit/Capabilities/`
- **Tool groups** — each capability defines named groups of tools (e.g. Mail has Read, Manage, Send). Users enable/disable groups independently for granular control
- **CapabilityStore** — per-project persistence of enabled groups (`capabilities.json`), with migration from legacy flat format
- **CLIEngine integration** — merges capability MCP servers into the temp config, auto-approves tools from enabled groups via `--allowedTools`
- **System prompt injection** — Claude knows about available/enabled capabilities (including which groups are active) and can suggest enabling them
- **UI** — toolbar sheet with NavigationStack drill-down to per-group toggles
- **iWork MCP helper** — `Helpers/atelier-iwork-mcp.swift`, 12 tools across Keynote/Pages/Numbers via JXA, 2 groups (Create, Export)
- **Safari MCP helper** — `Helpers/atelier-safari-mcp.swift`, 6 tools via JXA, 2 groups (Browse, Script)
- **Mail MCP helper** — `Helpers/atelier-mail-mcp.swift`, 10 tools via JXA, 3 groups (Read, Manage, Send)
- **Export defaults** — saves to project working directory when no path specified

Pattern for adding new capabilities: add a new helper in `Helpers/`, register in `CapabilityRegistry`, add a build phase in the Xcode project.

## Planned Built-in Capabilities

### High Priority — Native Mac Differentiators

| Capability | App | What it unlocks | Complexity |
|-----------|-----|----------------|------------|
| ✅ **iWork** | Keynote, Pages, Numbers | Create/edit presentations, documents, spreadsheets | Shipped |
| ✅ **Mail** | Mail.app | Draft, send, reply to emails. "Summarize this and email it to the team." | Shipped |
| 🔲 **Reminders** | Reminders.app | Create tasks, lists, due dates. "Remind me to review the budget Friday." | Low — simple scripting dictionary |
| 🔲 **Calendar** | Calendar.app | Create events, check availability. "Block 2 hours tomorrow for this project." | Low — EventKit or JXA |
| 🔲 **Notes** | Notes.app | Read/write Apple Notes. "Save these meeting notes to my Work folder." | Medium — Notes scripting is limited but workable |
| 🔲 **Preview / PDF** | Preview, PDFKit | Merge, split, annotate PDFs. "Combine these three PDFs into one." | Medium — may use PDFKit directly instead of JXA |

### Medium Priority — Productivity Multipliers

| Capability | App | What it unlocks | Complexity |
|-----------|-----|----------------|------------|
| ✅ **Safari** | Safari | Open URLs, read page content, bookmark. "Research competitors and save the links." | Shipped |
| 🔲 **Finder** | Finder | Organize files, create folders, tag files. "Organize my Downloads by type." Smart folders. | Low — comprehensive scripting dictionary |
| 🔲 **Shortcuts** | Shortcuts.app | Trigger any user-defined Shortcut. Meta-capability — unlocks everything the user has already automated. | Low — `shortcuts run` CLI |

### Lower Priority — Delight

| Capability | App | What it unlocks |
|-----------|-----|----------------|
| 🔲 **Music** | Music.app | "Play some focus music." Simple but charming. |
| 🔲 **Maps** | Maps.app | Location lookup, directions export for travel planning docs. |

## Implementation Phases

### Phase 1 — Built-in Capabilities (current)

- ✅ Capability registry and store architecture
- ✅ iWork capability (Keynote, Pages, Numbers)
- ✅ Safari capability (Browse, Script)
- ✅ Mail capability (Read, Manage, Send)
- ✅ Tool groups — granular per-group enablement with NavigationStack sheet UI
- 🔲 Reminders, Calendar, Notes, Preview/PDF capabilities
- 🔲 Finder, Shortcuts capabilities

### Phase 2 — On-Demand Activation

- ✅ Claude detects when a capability would help and suggests enabling it (via system prompt injection)
- 🔲 One-click enable directly from the conversation (not just toolbar)
- 🔲 OAuth flows for capabilities that need authentication (Google Calendar, etc.)

### Phase 3 — Capability Health (Invisible)

- Background health monitoring — if a capability's MCP server degrades, the app handles it silently (retry, restart)
- Only surfaces to the user if something is genuinely broken: "Web search is temporarily unavailable"
- No health dashboard, no status cards, no management UI — unless the user explicitly opens project settings

### Phase 4 — Custom MCP Servers (Power Users)

- Context file supports full MCP server configuration for custom capabilities
- XPC-based isolation: custom servers can't crash the app
- Only relevant for developers building their own tools

## Dependencies

- architecture/06-conversation-model.md (capabilities surface in the conversation timeline)
- context/01-project-context-files.md (capability declarations in context files)
- security/04-credential-storage.md (OAuth tokens in Keychain)

## Notes

The word "plugin" should never appear in the UI. The word "MCP" should never appear in the UI. Users see capabilities — things Claude can do. The infrastructure is invisible. This is the phone model: you don't configure your GPS chip, you just open Maps and it knows where you are.

---

*Back to [Index](../../INDEX.md)*
