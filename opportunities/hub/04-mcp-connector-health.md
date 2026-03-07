# Capability Health

> **Category:** Hub / Unified Experience
> **Type:** Improvement · **Priority:** 🟠 High
> **Milestone:** M5

---

## Current State (Electron / Cowork)

Approximately 25% reported failure rate for connectors, with no visibility into status or errors. Connectors fail silently — users discover failures only when expected results don't appear. No retry mechanisms, no logs, and re-authentication requires navigating obscure settings.

## Native macOS Approach

Capability health is invisible by default. The app monitors, retries, and recovers automatically. The user only hears about it when something is genuinely broken — and even then, the message is simple and actionable.

### Design principles

- **No health dashboard.** Regular users should never need to check on capability status. The app handles it.
- **Automatic recovery.** If an MCP server crashes, restart it. If an OAuth token expires, refresh it silently. If a request fails, retry with backoff.
- **Surface only what's actionable.** "Web search is temporarily unavailable" is useful. "MCP server at localhost:3847 returned HTTP 503 with retry-after header" is not.
- **One-tap fixes.** If re-authentication is needed, show a single prompt in the conversation: "Google Calendar needs you to sign in again." → One tap → OAuth flow → fixed.

### What happens behind the scenes

- Background health pings every 5 minutes for active capabilities
- Exponential backoff retry on failure (1s → 2s → 4s → 8s, max 3 attempts)
- Automatic OAuth token refresh before expiration
- XPC isolation: a crashing MCP server never affects the app
- Automatic restart of crashed servers with state recovery

### What the user sees

| Situation | User experience |
|-----------|----------------|
| Capability working normally | Nothing. It just works. |
| Temporary blip (recovers in <10s) | Nothing. Retry handled silently. |
| OAuth token expired (auto-refreshable) | Nothing. Refreshed in background. |
| OAuth needs re-login | Inline prompt: "Sign in again to use Calendar" → one tap |
| Capability down for >1 minute | Inline note: "Web search is temporarily unavailable" |
| Capability permanently broken | Message in conversation with suggestion to check settings |

### Power users only

Project settings includes a capabilities section where power users can:
- See which capabilities are active and their status
- View recent errors for debugging
- Manually restart or disconnect a capability
- Add custom MCP server configurations

This view exists but is never surfaced proactively. You have to go looking for it.

## Implementation

### Phase 1 — Health Monitoring

- Background `URLSession` health pings for active MCP servers
- Exponential backoff retry queue for failed operations
- Auto-restart for crashed XPC-isolated MCP processes

### Phase 2 — Silent Recovery

- OAuth token refresh before expiration via Keychain-stored refresh tokens
- Server reconnection with state recovery
- Queue pending operations during temporary outages, replay on recovery

### Phase 3 — User-Facing Alerts (Minimal)

- Inline conversation messages for actionable issues only
- One-tap re-authentication via `ASWebAuthenticationSession`
- Capability status in project settings for power users

## Dependencies

- hub/03-plugin-management.md (capabilities model — renamed from plugin management)
- security/04-credential-storage.md (OAuth tokens in Keychain)

## Notes

The best health monitoring is the kind nobody notices. If a user ever has to "manage their connectors," we've failed. The goal is zero-maintenance capabilities that just work, with graceful degradation when they can't.

---

*Back to [Index](../../INDEX.md)*
