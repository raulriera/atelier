# Shortcuts & Automation

> **Category:** macOS Integration
> **Type:** New Capability · **Priority:** High
> **Milestone:** M4 · **Status:** 🔲 Not started

---

## Problem

Atelier cannot be triggered or controlled by any macOS automation system. Users cannot integrate it into larger workflows involving other apps — everything requires manual interaction.

## Solution

Full **Shortcuts.app** integration via App Intents framework, plus an **AppleScript/JXA** dictionary for power users.

### App Intents

Core intents that appear in Shortcuts.app: ProcessFiles, GenerateDocument, OrganizeFolder, RunWorkflow, GetTaskStatus, GetTokenUsage. Each accepts parameters configurable in Shortcuts' visual editor.

### Automation power

Combined with Shortcuts' triggers (time-of-day, folder actions, Focus mode changes), this enables fully automated workflows:

```
Trigger: 8:00 AM on weekdays
  ├─ Get today's calendar events (Calendar app)
  ├─ Get unread email count (Mail app)
  ├─ Atelier: GenerateDocument(template: "daily-briefing")
  └─ Open file in Preview
```

This is impossible in Electron — App Intents require a native app bundle.

---

*Back to [Index](../../INDEX.md)*
