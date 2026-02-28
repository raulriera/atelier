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

## Implementation

### Phase 1 — Built-in Capabilities

- File operations (read, write, create, delete, move) via host file system access
- Project scanning (understand folder structure, detect file types)
- These require no setup and are always available

### Phase 2 — Capability Registry

- A built-in registry mapping capability names to MCP server configurations
- Ships with common capabilities: web search, image generation, etc.
- Registry is updatable without an app update (fetched from a simple manifest)

### Phase 3 — On-Demand Activation

- Claude detects when a capability would help and suggests it inline in the conversation
- User approves with one click
- App handles MCP server lifecycle: start, connect, health-check, restart on failure
- OAuth flows for capabilities that need authentication (calendar, email, etc.)
- Per-project capability state stored in project metadata

### Phase 4 — Capability Health (Invisible)

- Background health monitoring — if a capability's MCP server degrades, the app handles it silently (retry, restart)
- Only surfaces to the user if something is genuinely broken: "Web search is temporarily unavailable"
- No health dashboard, no status cards, no management UI — unless the user explicitly opens project settings

### Phase 5 — Custom MCP Servers (Power Users)

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
