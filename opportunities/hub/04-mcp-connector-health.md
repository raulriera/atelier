# Capability Health

> **Category:** Hub / Unified Experience
> **Type:** Improvement · **Priority:** High
> **Milestone:** M5 · **Status:** ✅ Done (basic monitoring)

---

## Problem

MCP servers crash, OAuth tokens expire, network drops. Users shouldn't have to diagnose why "Claude can't send email anymore." Capabilities should self-heal invisibly.

## Solution

Background health monitoring with automatic recovery. Zero-maintenance capabilities where users never see status unless something is genuinely broken.

### Principles

- **No health dashboard.** Health is tracked silently. Users only see alerts when something is actually broken: "Mail is temporarily unavailable."
- **Automatic recovery.** Retry with exponential backoff. Refresh OAuth tokens before they expire. Restart crashed MCP servers.
- **Graceful degradation.** If a capability is down, Claude works around it: "Mail seems to be having issues. Want me to draft the email so you can send it manually?"

### Health states

Healthy → Degraded (intermittent failures) → Unavailable (3+ consecutive failures). Automatically resets on new conversation (CLI spawns fresh MCP servers).

## Status

| Feature | Status |
|---------|--------|
| Tool call success/failure tracking (CapabilityHealthMonitor) | ✅ Shipped |
| Health state machine (healthy/degraded/unavailable) | ✅ Shipped |
| System event alerts for broken capabilities | ✅ Shipped |
| Auto-reset on new conversation | ✅ Shipped |
| Background health pings with exponential backoff | 🔲 Not started |
| Silent OAuth token refresh | 🔲 Not started |

---

*Back to [Index](../../INDEX.md)*
