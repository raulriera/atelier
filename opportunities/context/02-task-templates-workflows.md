# Scheduled Tasks, Templates & Workflows

> **Category:** Context Control & Agent Intelligence
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical
> **Milestone:** M4

---

## Problem

Every conversation starts from scratch. If you ask Claude to "generate a weekly report from these CSVs" every Friday, you re-explain the format, the folder structure, and the output location each time. There's no way to save a successful interaction as a repeatable template — and no way to make it run on a schedule without you being there.

Cowork shipped `/schedule` for recurring tasks in early 2026. It's already one of the most-used features among knowledge workers. But the implementation is limited: tasks only run while the computer is awake and the desktop app is open, there's no native OS integration, and scheduling is a text command rather than a first-class concept.

## Solution

Scheduled recurring tasks are the headline feature. Templates are how they're defined. Shortcuts.app is how they're orchestrated.

### Scheduled tasks: Claude works while you don't

The most powerful thing Atelier can do is work you never have to start. A scheduled task runs automatically — every morning, every Friday, whenever a condition is met — and delivers finished output to your folder.

**Example: "Weekly Client Report"**

```
Every Friday at 9am
  │
  ├─ Read all CSVs in ~/Data/weekly/
  ├─ Analyze trends compared to previous week
  ├─ Generate an Excel report with charts
  ├─ Save to ~/Reports/weekly-2026-03-07.xlsx
  └─ Notify: "Weekly report is ready"
```

You set this up once. It runs every Friday. You wake up to a finished report.

**Example: "Daily Inbox Processing"**

```
Every weekday at 8am
  │
  ├─ Scan ~/Downloads/ for new PDFs matching "invoice*"
  ├─ Extract vendor, amount, date, line items
  ├─ Append to ~/Finances/invoice-tracker.xlsx
  ├─ Move processed files to ~/Documents/Invoices/2026-03/
  └─ If any invoice > $5,000: notify for review
```

**Example: "Meeting Prep"**

```
30 minutes before each calendar event tagged "client"
  │
  ├─ Pull recent email threads with attendees
  ├─ Check project folder for open items
  ├─ Generate a one-page briefing document
  └─ Save to ~/Desktop/prep-[client-name].md
```

### Why this is different from Cowork

| | Cowork | Atelier |
|---|---|---|
| **Scheduling** | `/schedule` text command | Native UI + Shortcuts.app triggers |
| **Persistence** | Dies when app closes | `BGTaskScheduler` + Launch Agent survives sleep/quit/reboot |
| **Triggers** | Time-based only | Time, folder events, calendar, Focus modes, any Shortcuts trigger |
| **Visibility** | Buried in chat history | Menu bar status, notification center, dedicated view |
| **OS integration** | None | Shortcuts.app, Siri, Automator, AppleScript |

The critical advantage: Atelier scheduled tasks survive the app closing. A `launchd` Launch Agent wakes the app to execute scheduled work, and `BGTaskScheduler` handles the OS coordination. Cowork's "app must stay open" limitation is the gap we fill.

### Templates: save what worked

When a conversation produces a great result, Claude offers to save the pattern:

> *"That report came out well. Want me to save these instructions so you can run this again — or put it on a schedule?"*

You say yes. Claude writes a context file:

```markdown
# Weekly Sales Report

Read all CSVs in ~/Data/weekly/
Analyze trends compared to previous week
Generate an Excel report with charts
Save to ~/Reports/ with the date in the filename
```

Templates are just markdown files in `.atelier/templates/`. Human-readable, editable, shareable, versionable via git. They're the recipe. Scheduling is the oven timer.

### Who uses scheduled tasks?

| User | Schedule | What runs |
|------|----------|-----------|
| A consultant | Every Monday 8am | "Client meeting prep" — reads latest emails, drafts agenda, pulls open items |
| A writer | Every evening 6pm | "Chapter review" — checks today's draft for passive voice, clichés, pacing issues |
| A small business owner | 1st of each month | "Monthly invoicing" — generates invoices from client folder data |
| A researcher | Every morning 7am | "Literature scan" — checks saved searches, summarizes new papers |
| A marketer | Every Friday 3pm | "Weekly metrics" — pulls analytics, generates performance report |

### Workflows: chaining templates with the OS

A workflow is a template connected to the broader macOS automation ecosystem via Shortcuts.app. The workflow builder is Shortcuts.app — Atelier just exposes the right intents.

**Atelier provides the intents:**

- `RunTemplate(project:, template:)` — run a saved template in a project
- `ScheduleTask(project:, template:, recurrence:)` — create or modify a schedule
- `AskClaude(message:, project:)` — send a message in a project context
- `OpenProject(path:)` — open a folder as a project window

**Shortcuts.app provides the triggers:**

- Time of day, day of week
- When a file appears in a folder
- When connecting to a specific Wi-Fi
- When Focus mode changes
- When a calendar event starts
- Manual trigger from the Shortcuts widget

Users chain Atelier intents with any other Shortcuts action — Calendar, Mail, Reminders, other apps. Atelier becomes one step in a larger automation, not a walled garden.

## Implementation

### Phase 1 — Save as Template

- When a conversation produces a structured output, offer to save the instructions
- Template is a context file in the project's `.atelier/templates/` folder
- Simple markdown format — human-readable and editable
- "Run [template name]" triggers it in a new session

### Phase 2 — In-App Scheduling

- Schedule UI accessible from the menu bar agent and project settings
- Recurrence options: hourly, daily, weekly, monthly, custom cron expression
- `BGTaskScheduler` for OS-managed scheduling
- `launchd` Launch Agent for surviving app quit (wake the app to execute)
- `NSProcessInfo.performActivity()` to prevent sleep during execution
- Schedule status visible in menu bar: next run time, last result
- Notifications on completion via `UNUserNotificationCenter`

### Phase 3 — Shortcuts Integration

- `AppIntent` definitions for core actions (RunTemplate, ScheduleTask, AskClaude, OpenProject)
- Atelier appears in Shortcuts.app as an action source
- Parameterized intents for Shortcuts' visual editor
- Background execution for automated workflows
- AppleScript dictionary (`.sdef`) for power users

### Phase 4 — Template Library & Contextual Offers

- Starter templates bundled with the app for common knowledge-work use cases
- Offered contextually when relevant: "You're working with invoices — would a monthly processing template help?"
- Claude notices recurring patterns across sessions and offers to templatize them
- Templates are starting points — Claude adapts them to the conversation

### Phase 5 — Folder Triggers

- FSEvents monitoring for designated "watch folders"
- When new files appear, run the associated template automatically
- Example: drop a PDF in ~/Inbox/ → Claude processes it according to the template
- Configurable in the project context file
- Integrates with the scheduling system (folder trigger + time window)

## Dependencies

- context/01-project-context-files.md (templates are context files)
- architecture/04-session-persistence.md (scheduled tasks need session survival)
- macos/06-shortcuts-automation.md (Shortcuts.app integration)
- macos/08-file-system-events.md (folder-based triggers)
- macos/05-menu-bar-agent.md (schedule visibility)
- macos/07-notifications.md (completion notifications)

## Notes

The pitch is simple: **Claude works while you sleep.**

Scheduled tasks are the single most compelling reason to use a native app over Cowork. Cowork requires the app to stay open — close it and your schedule dies. Atelier uses `launchd` and `BGTaskScheduler` to survive anything. This is a native-only advantage that Electron fundamentally cannot match.

Templates should feel like "Claude remembers how I like things done" — not like "I configured a workflow." The best template is one the user never explicitly created. Claude noticed a pattern, offered to save it, and asked if it should run automatically.

The Shortcuts integration is the key to workflows. We don't build a workflow builder — Shortcuts.app already is one, and it's better than anything we'd build. We just expose the right intents and let macOS handle the orchestration.

---

*Back to [Index](../../INDEX.md)*
