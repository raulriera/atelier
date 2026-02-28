# Hub & Navigation

> **Category:** Experience
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical

---

## Problem

Claude's functionality is fractured across disconnected surfaces — Claude.app for chat, Cowork for autonomous tasks, Claude Code for terminal work. Each has its own window, its own state, its own context. Users constantly context-switch, re-explain what they're working on, and lose the thread of a multi-step workflow that spans modes.

There's no single place that says "here's everything happening with Claude right now."

## Solution

A single-window application with a unified navigation model:

- **Project sidebar** (left) — lists open projects, pinned folders, recent sessions. This is the persistent anchor.
- **Mode bar** (top) — Chat, Cowork, Code tabs. Switching modes preserves the current project context. Think of it like Xcode's editor/console/debug mode switching — same project, different lens.
- **Content area** (center) — adapts to the active mode. Chat shows conversation. Cowork shows task progress and file diffs. Code shows an embedded terminal.
- **Context panel** (right, collapsible) — shows active COWORK.md, file tree, session metadata, token usage. Shared across modes.

Mode switching is instant and preserves scroll position, draft text, and unsaved state. You can also split the content area (e.g., Chat + Code side by side, or Cowork progress + file diff).

## Implementation

### Phase 1 — Window Shell
- `NavigationSplitView` for the three-column layout (sidebar / content / detail). On macOS 26 this is the native pattern for sidebar-based apps — provides collapse, resize, and state restoration for free.
- SwiftUI `TabView` with the `Tab` API (macOS 26) for mode switching (Chat / Cowork / Code), or a custom `Picker` segment control if more control is needed.
- AppKit bridging via `NSViewRepresentable` only for the embedded terminal view and other controls without SwiftUI equivalents.
- State restoration via `NSUserActivity` and `@SceneStorage`.
- Respect system appearance (Dark Mode, accent color, sidebar tinting via `.listStyle(.sidebar)`).

### Phase 2 — Split Views
- Horizontal and vertical split support within the content area
- Drag-to-resize with snap points
- Per-project layout memory (which splits were open, their sizes)

### Phase 3 — Keyboard-Driven Navigation
- `⌘1` / `⌘2` / `⌘3` for Chat / Cowork / Code
- `⌘\` toggle sidebar, `⌘⌥\` toggle context panel
- `⌘T` new session tab within current mode
- Standard `⌘[` / `⌘]` back/forward through session history

## Dependencies

- architecture/01-application-shell.md (the native window)

## Notes

This is the most important design decision in the app. Everything else is a feature inside this shell. Get the navigation wrong and every feature suffers.

---

*Back to [Index](../../INDEX.md)*
