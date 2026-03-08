# Scheduled Tasks, Templates & Workflows

> **Category:** Context Control & Agent Intelligence
> **Type:** New Capability · **Priority:** Critical
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
| **Persistence** | Dies when app closes | `launchd` Launch Agent — survives quit, sleep, reboot. Coalesces missed fires on wake. |
| **Triggers** | Time-based only | Time, folder events, calendar, Focus modes, any Shortcuts trigger |
| **Visibility** | Buried in chat history | Menu bar status, notification center, dedicated view |
| **OS integration** | None | Shortcuts.app, Siri, Automator, AppleScript |

The critical advantage: Atelier scheduled tasks survive the app closing. A `launchd` Launch Agent wakes a lightweight helper binary to execute scheduled work — no need for the full app to be running. Cowork's "app must stay open" limitation is the gap we fill.

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

### Relationship to Claude Code Skills

Claude Code ships a skill system (`.claude/skills/SKILL.md`) with YAML frontmatter supporting argument substitution (`$ARGUMENTS`), tool restrictions (`allowed-tools`), model selection, and user invocation via `/skill-name`. Templates are conceptually the same — a reusable instruction set with optional parameters. For developer projects, Atelier templates should be interoperable with the skill format, so a template written for Atelier can also run via `claude -p` with `/template-name` from the CLI.

For non-developer users, the template format stays simple markdown with optional frontmatter. The skill-compatible frontmatter is a power-user layer that surfaces only when needed.

### Headless execution for scheduled tasks

When a scheduled task fires, Atelier doesn't need to spin up a full conversation UI. A bundled helper binary (`Contents/Helpers/atelier-scheduler`) reads the schedule store, determines which tasks are due, and runs each one via Claude Code's headless mode:

```bash
claude -p "{prompt}" \
  --model {alias} \
  --output-format json \
  --max-turns 20
```

The helper sets `WorkingDirectory` to the task's project path, so Claude operates in the right folder context. The full app only needs to launch for tasks that require user interaction (approval gates, ask-user prompts).

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

- **Model**: `ScheduledTask` struct — name, description, prompt, schedule (manual/hourly/daily/weekly/monthly/cron), optional model override, project path, pause state
- **Persistence**: `ScheduleStore` (`@Observable`, `@MainActor`) persists to `~/Library/Application Support/Atelier/schedules.json`
- **Execution**: Single `launchd` Launch Agent plist at `~/Library/LaunchAgents/com.atelier.scheduler.plist` with `AssociatedBundleIdentifiers` for clean Login Items display
- **Helper binary**: `Contents/Helpers/atelier-scheduler` — reads `schedules.json`, matches due tasks to the current time, runs `claude -p` for each
- **Agent command**: `claude -p "{prompt}" --model {alias} --output-format json --max-turns 20` with `WorkingDirectory` set to the task's project path
- **Agent lifecycle**: Plist rebuilt and reloaded via `launchctl unload/load` on every task create/update/delete. If no active tasks remain, plist is deleted entirely
- **Logs**: `StandardOutPath` / `StandardErrorPath` to `~/Library/Logs/Atelier/`
- **Notifications**: App reads log files on launch for v1; helper binary posts via `UNUserNotificationCenter` in v2
- **`NSProcessInfo.performActivity()`**: Used when running tasks in-process (manual "Run Now" button)
- **Wake from sleep**: Not supported in v1. `IOPMSchedulePowerEvent(kIOPMAutoWake)` requires root — noted as v2 enhancement via `SMAppService` privileged helper
- Schedule status visible in menu bar: next run time, last result

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

## Technical Constraints

### macOS scheduling options evaluated

| Mechanism | Exact times? | Wakes from sleep? | App closed? | Used? |
|---|---|---|---|---|
| `launchd` Launch Agent | Yes (`StartCalendarInterval`) | No (catches up on wake) | Yes | **Yes** |
| `SMAppService.agent(plistName:)` | Yes | No | Yes | No — plist in signed bundle, can't update dynamically |
| `BGTaskScheduler` | N/A | N/A | N/A | No — not available on native macOS (Mac Catalyst only) |
| `NSBackgroundActivityScheduler` | No (system decides) | No | No (app must run) | No |
| `IOPMSchedulePowerEvent` | Yes | Yes | Yes | Future (requires root) |

### Single-agent design

One plist (`com.atelier.scheduler.plist`) with an `AssociatedBundleIdentifiers` key holds a `StartCalendarInterval` array — the union of all active task schedules. This means:

- **One Login Items entry**: "Atelier" with app icon (not N raw plist names)
- **Zero polling**: launchd's kernel timer fires at exact calendar times
- **Dynamic updates**: plist rebuilt and reloaded on task CRUD only
- **Clean removal**: if no tasks are active, plist is deleted entirely

### launchd coalescing behavior

From `launchd.plist(5)`:
> "Unlike cron which skips job invocations when the computer is asleep, launchd will start the job the next time the computer wakes up. If multiple intervals transpire before the computer is woken, those events will be coalesced into one event upon wake from sleep."

Since all tasks share one agent, a sleep-through-multiple-fires scenario fires the helper once on wake. The helper checks all tasks and runs whichever are due. No stampede, no duplicate runs.

## Dependencies

- context/01-project-context-files.md (templates are context files)
- architecture/04-session-persistence.md (scheduled tasks need session survival)
- macos/06-shortcuts-automation.md (Shortcuts.app integration)
- macos/08-file-system-events.md (folder-based triggers)
- macos/05-menu-bar-agent.md (schedule visibility)
- macos/07-notifications.md (completion notifications)

## Notes

The pitch is simple: **Claude works while you sleep.**

Scheduled tasks are the single most compelling reason to use a native app over Cowork. Cowork requires the app to stay open — close it and your schedule dies. Atelier uses `launchd` Launch Agents to survive anything — app quit, sleep, reboot. When the Mac wakes up, launchd fires the helper, the helper runs whichever tasks are due, and you find finished output waiting. This is a native-only advantage that Electron fundamentally cannot match.

Templates should feel like "Claude remembers how I like things done" — not like "I configured a workflow." The best template is one the user never explicitly created. Claude noticed a pattern, offered to save it, and asked if it should run automatically.

The Shortcuts integration is the key to workflows. We don't build a workflow builder — Shortcuts.app already is one, and it's better than anything we'd build. We just expose the right intents and let macOS handle the orchestration.

---

## Gaps

- **Open Recent menu:** When all project windows are closed, scheduled tasks for those projects are invisible. Need File → Open Recent populated from `ProjectStore` so users can reopen any project and see its automations. Standard macOS `CommandGroup(replacing: .recentFiles)` pattern.
- **`atelier-scheduler` helper binary not implemented:** The `LaunchAgentManager` installs a launchd plist pointing to `Contents/Helpers/atelier-scheduler`, but the binary doesn't exist — no source file, no Xcode target, no build phase. launchd fires on schedule but silently fails because there's nothing to execute. `runNow()` works because it calls `executeProcess` in-process; the launchd path is dead. Need to create the helper as a command-line tool target in Xcode, have it read `schedules.json`, match due tasks to the current time, and run `claude -p` for each (same logic as `ScheduleStore.executeProcess`).
- **Relocated toolbar items need a new home:** The inspector redesign removed three toolbar items that still need to be accessible somewhere:
  - **New session button** (plus.message, Cmd+Shift+T) — could move to File menu or compose field area
  - **Context files popover** (doc.text) — could move to a menu or become part of the inspector
  - **Model picker** (Claude Haiku dropdown) — could move to the compose field area, a menu, or a status bar element

---

*Back to [Index](../../INDEX.md)*
