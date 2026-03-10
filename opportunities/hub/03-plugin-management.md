# Capabilities

> **Category:** Hub / Unified Experience
> **Type:** Improvement · **Priority:** High
> **Milestone:** M3 · **Status:** ✅ Done (Phase 1-3)

---

## Problem

Cowork has 11+ plugins with a ~25% failure rate, no crash isolation, and no health monitoring. Users have to manually install and configure plugins. Most people never bother.

## Solution

No plugins. No marketplace. No configuration screens. **Capabilities** — things Claude can do — that surface when needed and disappear when they're not.

### How it works

Built-in capabilities just work. On-demand capabilities surface when Claude needs them: "I can check your calendar if you connect it. Allow?" → One tap → Done.

The user never sees "MCP," "plugin," or "connector." They see capability names and permission prompts. The infrastructure is invisible.

### Progressive disclosure

| Level | Experience |
|-------|-----------|
| Everyone | Built-in capabilities work out of the box |
| Regular users | Claude asks to enable things when needed, one-tap approval |
| Power users | Capabilities section in project settings to browse and configure |
| Developers | Custom MCP server URLs in the context file |

## Status

| Feature | Status |
|---------|--------|
| Capability registry, store, tool groups | ✅ Shipped |
| iWork (Keynote, Pages, Numbers) | ✅ Shipped |
| Mail (Read, Manage, Send) | ✅ Shipped |
| Reminders (Read, Create, Manage) | ✅ Shipped |
| Calendar (Read, Create, Manage) | ✅ Shipped |
| Notes (Read, Create, Manage) | ✅ Shipped |
| Safari (Browse, Script) | ✅ Shipped |
| Finder (Browse, Organize) | ✅ Shipped |
| Preview/PDF (info, extract, merge, split) | ✅ Shipped |
| System prompt injection for capability suggestions | ✅ Shipped |
| Inline suggestion bar for one-click enable | ✅ Shipped |
| Health monitoring (CapabilityHealthMonitor) | ✅ Shipped |
| Destructive tool gating | ✅ Shipped |
| Plain-English tool names (MCPToolMetadata) | ✅ Shipped |
| Shortcuts capability | 🔲 Not started |
| Music, Maps | 🔲 Not started |
| Custom MCP servers (power users) | 🔲 Not started |

## Notes

The word "plugin" should never appear in the UI. The word "MCP" should never appear in the UI. This is the phone model: you don't configure your GPS chip, you just open Maps and it knows where you are.

---

*Back to [Index](../../INDEX.md)*
