# Network Isolation

> **Category:** Security & Privacy
> **Type:** Improvement · **Priority:** 🔴 Critical

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

### Key Dependencies

- Network.framework (`NWConnection`, `NWProtocolTLS`)
- NetworkExtension framework (`NETransparentProxyProvider`)
- Content inspection pipeline (regex + heuristic-based)

---

*Back to [Index](../../INDEX.md)*
