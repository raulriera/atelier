# Scheduled Tasks, Templates & Workflows

> **Category:** Context Control & Agent Intelligence
> **Type:** New Capability · **Priority:** Critical
> **Milestone:** M4 · **Status:** 🔨 In progress

---

## Problem

Every conversation starts from scratch. If you ask Claude to "generate a weekly report from these CSVs" every Friday, you re-explain the format, the folder structure, and the output location each time. There's no way to save a successful interaction as a repeatable template — and no way to make it run on a schedule without you being there.

## Solution

### Scheduled tasks: Claude works while you don't

The most powerful thing Atelier can do is work you never have to start. A scheduled task runs automatically — every morning, every Friday, whenever a condition is met — and delivers finished output to your folder.

**Example:** Every Friday at 9am → read CSVs → analyze trends → generate Excel report → save to ~/Reports/ → notify "Weekly report is ready."

### Why this is different from Cowork

| | Cowork | Atelier |
|---|---|---|
| **Persistence** | Dies when app closes | `launchd` Launch Agent — survives quit, sleep, reboot |
| **Triggers** | Time-based only | Time, folder events, calendar, Focus modes, any Shortcuts trigger |
| **OS integration** | None | Shortcuts.app, Siri, Automator, AppleScript |

The critical advantage: tasks survive the app closing. A `launchd` Launch Agent wakes a lightweight helper binary — no need for the full app to be running.

### Templates: save what worked

When a conversation produces a great result, Claude offers to save the pattern. Templates are just markdown files in `.atelier/templates/` — human-readable, editable, shareable, versionable. They're the recipe. Scheduling is the oven timer.

For developer projects, templates are interoperable with Claude Code's skill format (`.claude/skills/SKILL.md`).

### Workflows: chaining templates with the OS

Atelier exposes App Intents (`RunTemplate`, `ScheduleTask`, `AskClaude`, `OpenProject`). Shortcuts.app provides triggers (time, folder events, Wi-Fi, Focus mode, calendar). Users chain Atelier intents with any other Shortcuts action — Atelier becomes one step in a larger automation, not a walled garden.

## Status

| Feature | Status |
|---------|--------|
| Schedule model and persistence | ✅ Shipped |
| launchd Launch Agent lifecycle | ✅ Shipped |
| Headless execution via `claude -p` | 🔨 Needs scheduler helper binary |
| Save as template | 🔲 Not started |
| Shortcuts integration (App Intents) | 🔲 Not started |
| Folder triggers (FSEvents) | 🔲 Not started |

## Gaps

- **Scheduler helper binary:** `LaunchAgentManager` installs a plist pointing to `Contents/Helpers/atelier-scheduler`, but the binary doesn't exist yet. launchd fires on schedule but silently fails. `runNow()` works because it executes in-process.
- **Relocated toolbar items:** Inspector redesign removed new session button, context files popover, and model picker. Need new homes.

## Notes

The pitch is simple: **Claude works while you sleep.** Scheduled tasks are the single most compelling reason to use a native app over Cowork. Templates should feel like "Claude remembers how I like things done" — not like "I configured a workflow."

---

*Back to [Index](../../INDEX.md)*
