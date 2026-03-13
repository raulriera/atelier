# CLI Filesystem Boundary

> **Category:** Security & Privacy
> **Type:** New Capability · **Priority:** Critical
> **Milestone:** M1

---

## Problem

Atelier's bookmark system restricts the macOS app process, but the Claude CLI runs as the user's process with full filesystem access. Without constraints, Claude can silently read SSH keys, cloud credentials, and personal documents — especially dangerous when combined with prompt injection.

The exfiltration pipeline: malicious document contains hidden instructions → Claude reads `~/.aws/credentials` (auto-approved) → Claude calls WebFetch to exfiltrate (also auto-approved). Both steps happen silently.

## Solution

Enforce the project folder as a filesystem boundary at the CLI level. Reads inside the project are silent. Reads outside require approval. Reads of known-sensitive paths are blocked entirely.

### Defense-in-depth layers

1. **Path-scoped CLI flags** — file tools scoped to project directory via `--allowedTools Tool(/path/*)`
2. **Sensitive path denylist** — `.ssh`, `.aws`, `.gnupg`, `Library/Keychains`, `.config`, `.netrc`, `.env*` blocked via `--disallowedTools`
3. **PreToolUse hook** — `path-guard` validates every file access against project boundary + sensitive denylist (catches edge cases CLI flags miss)
4. **ApprovalServer guard** — `SensitivePathPolicy` auto-denies sensitive paths before they reach the UI

No single layer is sufficient. All together make exfiltration require bypassing multiple independent controls.

---

*Back to [Index](../../INDEX.md)*
