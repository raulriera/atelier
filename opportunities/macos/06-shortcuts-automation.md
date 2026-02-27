# Shortcuts & Automation

> **Category:** macOS Integration
> **Type:** 🆕 New Capability · **Priority:** 🟠 High

---

## Current State (Electron / Cowork)

No Shortcuts.app or AppleScript support. Cowork cannot be triggered or controlled by any macOS automation system. Users cannot integrate Cowork into larger workflows involving other apps.

## Native macOS Approach

Full **SiriShortcuts / Shortcuts.app** integration via App Intents framework. **AppleScript/JXA** dictionary for power users. Automator actions for legacy workflows.

### Implementation Strategy

- **App Intents:** Define 10–15 core intents that appear in Shortcuts.app:
  - `ProcessFiles` — run a Cowork task on specified files/folders
  - `GenerateDocument` — create a report/deck/spreadsheet from data
  - `OrganizeFolder` — sort and organize files
  - `RunWorkflow` — execute a named saved workflow
  - `GetTaskStatus` — check if a background task is complete
  - `GetTokenUsage` — return current billing period usage
- **Parameterized intents:** Each intent accepts parameters (file paths, output formats, model preference) that can be configured in Shortcuts.app's visual editor.
- **AppleScript dictionary:** Expose a Scripting Definition (`.sdef`) file for AppleScript/JXA control. Power users can script Cowork from Terminal, BBEdit, or any scriptable app.
- **Shortcuts automations:** Combine with Shortcuts' triggers: time-of-day, when a file appears in a folder, when connecting to a specific Wi-Fi network, Focus mode changes, etc.

### Example Shortcut: "Morning Briefing"

```
Trigger: 8:00 AM on weekdays
  │
  ├─ Shortcuts: Get today's calendar events (Calendar app)
  ├─ Shortcuts: Get unread email count (Mail app)
  ├─ Cowork Intent: GenerateDocument
  │   - Input: calendar events + email summary
  │   - Template: "daily-briefing"
  │   - Output: ~/Desktop/briefing-2026-02-27.md
  └─ Shortcuts: Open file in Preview
```

### Key Dependencies

- App Intents framework (macOS 26)
- Scripting Definition (`.sdef`) for AppleScript
- `NSUserActivity` for Handoff support

---

*Back to [Index](../../INDEX.md)*
