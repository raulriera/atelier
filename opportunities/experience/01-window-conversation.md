# Window & Conversation

> **Category:** Experience
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical

---

## Problem

Claude's functionality is fractured across disconnected surfaces — Claude.app for chat, Cowork for autonomous tasks, Claude Code for terminal work. Each has its own window, its own state, its own context. Users constantly context-switch, re-explain what they're working on, and lose the thread of a multi-step workflow.

There's no single place that says "here's everything happening with Claude right now."

## Solution

A document-based Mac app where every project is a window and every window is a conversation.

### The window

Each window contains one thing: a conversation. No sidebar, no mode tabs, no multi-panel layout. A text field at the bottom, a flowing timeline above it. That's the starting point.

The conversation is adaptive — it's not just text bubbles. As work happens, rich inline elements appear in the timeline:

- **Messages** — your input and Claude's responses
- **File cards** — when Claude reads or creates files, a compact card appears showing what it touched
- **Progress indicators** — when Claude is working on something, progress unfolds inline
- **Diffs** — file changes appear as reviewable diffs in the thread
- **Approvals** — when Claude needs permission, the gate appears inline with context and one-click approve
- **Results** — task outcomes, build status, generated artifacts — all in the timeline

Everything reads top-to-bottom as a story of what happened.

### Multiple projects, multiple windows

Each project lives in its own window. Standard macOS document model:

- `⌘N` — new conversation window
- `⌘O` — open a folder as a project
- `⌘`` ` — switch between open project windows
- Mission Control, Stage Manager, Spaces — all work naturally
- Window menu lists all open projects
- Recent projects appear in File → Open Recent

No project picker, no sidebar, no switcher UI. The OS already solved window management.

### Progressive disclosure

The window starts simple and reveals complexity as the user's needs grow:

- **Day one** — a text field and responses. That's it.
- **Over time** — inline cards become familiar, richer content types appear
- **Power users** — an optional inspector panel (right side) can show project context, file tree, token usage. It's there when you want it, invisible when you don't.
- **Keyboard shortcuts** — hints appear during relevant actions, then fade after a few uses

## Implementation

### Phase 1 — Document-Based Window

- `DocumentGroup` scene with custom `FileDocument` (or `ReferenceFileDocument`) representing a project — gives us multi-window, Open Recent, state restoration for free
- Alternatively, `WindowGroup` with `openWindow` for project-scoped windows if document model is too rigid
- Each window holds a `ConversationView` — a scrollable timeline of heterogeneous content
- AppKit bridging via `NSViewRepresentable` only where SwiftUI has no equivalent
- State restoration via `NSUserActivity` and `@SceneStorage`

### Phase 2 — Conversation Timeline

- **Performance is critical.** The timeline must scroll at 120fps with hundreds of items. Use `LazyVStack` with reusable cell types, pre-computed layouts, and off-main-thread preparation.
- Heterogeneous cell types: text message, file card, diff view, progress indicator, approval gate, result card
- Each cell type is a lightweight SwiftUI view optimized for minimal body recomputation
- Text input at the bottom with auto-grow, drag-and-drop file attachment, and submit on Enter
- Smooth animated insertion of new items (Claude's responses streaming in)

### Phase 3 — Inspector Panel

- Optional right panel (progressive disclosure — hidden by default, toggled via `⌥⌘I` or toolbar button)
- Shows project context: active context files, file tree, token usage, session metadata
- Does not affect the conversation layout — it's supplementary, not primary

### Phase 4 — Keyboard Navigation

Standard macOS shortcuts — never override system-defined bindings (see [HIG Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards)).

- `⌘N` new window
- `⌘O` open project
- `⌘W` close window
- `⌘,` settings
- `⌘`` ` switch windows
- `⌥⌘I` toggle inspector (⌘I is reserved for Italic)
- `↑` to edit last message

## Dependencies

- architecture/01-application-shell.md (the native window shell)

## Notes

This is the most important design decision in the app. The conversation timeline *is* the product. Its speed and fluidity determine whether the app feels alive or sluggish. Every optimization effort should start here.

---

*Back to [Index](../../INDEX.md)*
