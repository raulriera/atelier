# Task Templates & Workflows

> **Category:** Context Control & Agent Intelligence
> **Type:** 🆕 New Capability · **Priority:** 🟠 High

---

## Current State (Electron / Cowork)

Only the `/schedule` slash command exists for recurring tasks. There are no reusable workflow definitions, no visual task builders, and no way to save a successful task as a template for future use. Every invocation starts from scratch.

## Native macOS Approach

Native **Shortcuts.app integration** — expose Cowork actions as Shortcut steps. Plus a **visual workflow builder** using SwiftUI with drag-and-drop task composition.

### Implementation Strategy

- **App Intents framework:** Define Cowork actions as `AppIntent` structs. Each intent becomes available in Shortcuts.app, Siri, and the system-wide Action button:
  - `OrganizeFolder(path:, rules:)` — organize files in a folder
  - `GenerateReport(source:, template:, outputFormat:)` — create a report
  - `ProcessInbox(folder:, actions:)` — triage and process new files
  - `RunWorkflow(name:)` — execute a saved custom workflow
- **Workflow builder:** A native SwiftUI view with drag-and-drop steps. Each step is a Cowork action with configurable parameters. Steps can be chained, branched (if/else based on file count, content), and looped.
- **Template gallery:** Community-contributed and built-in templates, stored as JSON workflow definitions. Import/export for sharing.
- **Trigger system:** Workflows can be triggered by Shortcuts automations (time-based, location-based, or event-based), folder activity (via FSEvents), or manual invocation.

### Example Workflow: "Weekly Report Pipeline"

```
Trigger: Every Friday at 9am (via Shortcuts automation)
  │
  ├─ Step 1: Collect CSVs from ~/Data/weekly/
  ├─ Step 2: Run analysis (COWORK.md rules apply)
  ├─ Step 3: Generate Excel report with charts
  ├─ Step 4: Create PowerPoint summary deck
  ├─ Step 5: Move outputs to ~/Reports/2026-W09/
  └─ Step 6: Notify user via push notification
```

### Key Dependencies

- App Intents framework (macOS 26)
- Shortcuts.app integration
- FSEvents for file-based triggers
- JSON workflow definition schema

---

*Back to [Index](../../INDEX.md)*
