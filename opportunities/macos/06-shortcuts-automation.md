# Shortcuts & Automation

> **Category:** macOS Integration
> **Type:** New Capability · **Priority:** High
> **Milestone:** M4 · **Status:** 🔲 Not started

---

## Problem

Atelier cannot be triggered or controlled by any macOS automation system. Users cannot integrate it into larger workflows involving other apps — everything requires manual interaction.

## Solution

**Shortcuts.app** integration via the App Intents framework. Three focused intents that cover the full surface area — everything else is just a prompt.

### App Intents

1. **Ask Atelier** — Send a free-form prompt to a selected project and get a text result back. The general-purpose intent that subsumes any specific task (process files, generate documents, organize folders, etc.).
   - Parameters: `prompt` (String), `project` (AppEntity with dynamic options)
   - Returns: String

2. **Run Workflow** — Execute a saved workflow/template on a selected project. For structured, repeatable tasks.
   - Parameters: `workflow` (AppEntity with dynamic options), `project` (AppEntity with dynamic options)
   - Returns: Void

3. **Get Token Usage** — Returns current account-level token usage as a percentage. No parameters needed — useful for dashboards, widgets, or automation guards.
   - Parameters: none
   - Returns: Double (0.0–1.0)

### Automation power

Combined with Shortcuts' triggers (time-of-day, folder actions, Focus mode changes), this enables fully automated workflows:

```
Trigger: 8:00 AM on weekdays
  ├─ Get today's calendar events (Calendar app)
  ├─ Get unread email count (Mail app)
  ├─ Atelier: Ask Atelier(project: "Work", prompt: "Write my daily briefing")
  └─ Open result in Notes
```

All three intents also surface automatically in Siri and Spotlight.

This is impossible in Electron — App Intents require a native app bundle.

---

*Back to [Index](../../INDEX.md)*
