# Multi-Agent Orchestration Visibility

> **Category:** Context Control & Agent Intelligence
> **Type:** Improvement · **Priority:** 🟡 Medium

---

## Current State (Electron / Cowork)

A lead agent (Opus-class model) decomposes complex tasks into subtasks, delegating to multiple Sonnet-class sub-agents that execute simultaneously. However, orchestration is completely opaque — users see a single progress stream with no visibility into which sub-agents are running, what they're doing, or how much they're consuming.

## Native macOS Approach

**Activity Monitor-style agent dashboard**: see each sub-agent's task, status, token usage, and output in real-time. Native `NSProgress` integration for system-level progress indicators.

### Implementation Strategy

- **Agent dashboard:** A SwiftUI sidebar or sheet showing each active sub-agent as a card: task description, model being used (Opus/Sonnet), status (planning/executing/waiting), token count, and elapsed time.
- **NSProgress integration:** Each sub-agent reports progress via `NSProgress`, which flows into the system's native progress UI — visible in the Dock icon badge, Touch Bar (older Macs), and Atelier's title bar.
- **Token attribution:** Track and display per-sub-agent token usage so users can see which parts of a complex task are most expensive.
- **Pause/cancel individual agents:** Users can pause or cancel specific sub-agents without killing the entire orchestration.
- **Timeline view:** A Gantt-style timeline showing when each sub-agent started, what it depended on, and how long it took — useful for optimizing workflow templates.

### Key Dependencies

- `NSProgress` and progress reporting protocol
- SwiftUI `TimelineView` for real-time updates
- Anthropic API multi-agent response parsing

---

*Back to [Index](../../INDEX.md)*
