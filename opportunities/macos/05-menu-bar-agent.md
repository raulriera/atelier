# Menu Bar Agent

> **Category:** macOS Integration
> **Type:** 🆕 New Capability · **Priority:** 🟠 High
> **Milestone:** M4

---

## Problem

To interact with Claude, users must bring the full app window to the foreground. This is disruptive when working in other applications — sometimes you just want to ask a quick question without leaving what you're doing.

## Solution

A menu bar icon that provides quick access to Claude from anywhere — without opening a full project window.

### What it does

- **Status indicator** — the menu bar icon shows whether Claude is idle, working, or needs attention (waiting for approval). Animated subtly during active work.
- **Quick conversation** — click the icon (or press the global hotkey, e.g. `⌘⇧K`) to open a popover with a text field. Type a question, get an answer. No project context — just a quick chat.
- **Active session status** — see which project windows have active work in progress, with one-click to jump to any of them.
- **Token usage glance** — current billing period usage, always one look away.
- **Drag-drop target** — drag files onto the menu bar icon to start a conversation with those files as context. Opens a new window.

### What it doesn't do

No "compact task interface." No "mini app in the menu bar." The menu bar agent is a quick access point, not a replacement for project windows. If you need to do real work, the full window is one click (or `⌘`` `) away.

## Implementation

### Phase 1 — Status & Quick Access

- `NSStatusItem` with `NSStatusBarButton`
- Click → menu with: active project windows, token usage summary, "New Conversation" shortcut
- Animated icon states: idle, working, needs-attention

### Phase 2 — Quick Conversation Popover

- `NSPopover` with a minimal SwiftUI view: text field + response area
- Global hotkey registration (e.g., `⌘⇧K`) to summon from any app
- No project context — just the API key and a fresh conversation
- Dismiss on click-outside or Escape

### Phase 3 — Drag & Drop

- `NSDraggingDestination` on the status bar button
- Drop files → open a new project window with those files as context
- Visual feedback during drag hover

## Dependencies

- architecture/01-application-shell.md (the app must be running for menu bar agent)
- experience/01-window-conversation.md (quick conversation uses the same ConversationEngine)

## Notes

The menu bar agent is the lightest possible entry point to Claude. It respects the document-based window model — it doesn't try to be a second app. It's a doorbell, not a room.

---

*Back to [Index](../../INDEX.md)*
