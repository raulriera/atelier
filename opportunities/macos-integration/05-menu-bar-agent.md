# Menu Bar Agent

> **Category:** macOS Integration
> **Type:** 🆕 New Capability · **Priority:** 🟠 High

---

## Current State (Electron / Cowork)

Full window required — no lightweight access point. To interact with Cowork, users must bring the entire Electron app to the foreground, which is disruptive when working in other applications.

## Native macOS Approach

**NSStatusItem menu bar agent**: quick task launch, session monitoring, notifications, and drag-drop target without opening the full app.

### Implementation Strategy

- **Status item:** Persistent menu bar icon showing agent status (idle, working, needs approval). Animated icon during active tasks.
- **Quick actions menu:** Click to see: active sessions with progress, recent outputs (click to Quick Look), quick task launcher (type a task inline), token usage summary for the billing period.
- **Drag-drop target:** Drag files onto the menu bar icon to start a Cowork session with those files as context.
- **Popover view:** Option-click for a mini SwiftUI popover with a compact task interface — no need to open the full app for quick operations.
- **Global hotkey:** Register a global keyboard shortcut (e.g., `⌘⇧K`) via `CGEvent.tapCreate` or `MASShortcut` to summon the popover from any app.

### Key Dependencies

- `NSStatusItem` and `NSStatusBarButton`
- `NSPopover` for compact UI
- Global hotkey registration
- `NSDraggingDestination` on status bar button

---

*Back to [Index](../../INDEX.md)*
