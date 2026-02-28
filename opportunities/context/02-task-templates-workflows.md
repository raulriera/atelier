# Task Templates & Workflows

> **Category:** Context Control & Agent Intelligence
> **Type:** 🆕 New Capability · **Priority:** 🟠 High
> **Milestone:** M5

---

## Problem

Every conversation starts from scratch. If you ask Claude to "generate a weekly report from these CSVs" every Friday, you re-explain the format, the folder structure, and the output location each time. There's no way to save a successful interaction as a repeatable template.

## Solution

Templates are just context files with instructions. Workflows are just templates triggered by Shortcuts.

### Templates: save what worked

When a conversation produces a great result, Claude offers to save the pattern:

> *"That report came out well. Want me to save these instructions so you can run this again next week?"*

You say yes. Claude writes a context file — like a recipe:

```markdown
# Weekly Sales Report

Read all CSVs in ~/Data/weekly/
Analyze trends compared to previous week
Generate an Excel report with charts
Save to ~/Reports/ with the date in the filename
```

Next time you open that folder and say "run the weekly report," Claude already knows what to do.

### Who uses templates?

| User | Template example |
|------|-----------------|
| A consultant | "Client meeting prep" — reads latest emails, drafts agenda, pulls open items |
| A writer | "Chapter review" — checks for passive voice, clichés, pacing issues |
| A small business owner | "Monthly invoicing" — generates invoices from client folder data |
| A developer | "PR review" — checks code style, test coverage, changelog entry |

Templates aren't a feature for power users. They're what happens when you use the app regularly and Claude remembers what you like.

### Workflows: templates on a schedule

A workflow is a template that runs automatically — triggered by Shortcuts.app, a folder change, or a schedule.

**Example: "Friday Report Pipeline"**

```
Trigger: Every Friday at 9am (via Shortcuts.app)
  │
  ├─ Open ~/Data/weekly/ project
  ├─ Run "Weekly Sales Report" template
  ├─ Save output to ~/Reports/
  └─ Notify user when done
```

This is built entirely on macOS infrastructure — `AppIntent` for Shortcuts integration, FSEvents for folder triggers, `UNUserNotificationCenter` for completion. No custom workflow builder UI needed.

### Shortcuts.app integration

Atelier exposes key actions as `AppIntent` structs, making them available in Shortcuts.app, Siri, and system automations:

- `RunTemplate(project:, template:)` — run a saved template in a project
- `AskClaude(message:, project:)` — send a message in a project context
- `OpenProject(path:)` — open a folder as a project window

Users can chain these with any other Shortcuts action — file operations, email, calendar, other apps. Atelier becomes one step in a larger automation, not a walled garden.

## Implementation

### Phase 1 — Save as Template

- When a conversation produces a structured output, offer to save the instructions
- Template is a context file in the project's `.atelier/templates/` folder
- Simple markdown format — human-readable and editable
- "Run [template name]" triggers it in a new session

### Phase 2 — Template Library

- Starter templates bundled with the app for common use cases
- Offered contextually when relevant: "You're working with CSVs — would a report template help?"
- Templates are starting points, not rigid structures — Claude adapts them to the conversation

### Phase 3 — Shortcuts Integration

- `AppIntent` definitions for core actions
- Atelier appears in Shortcuts.app as an action source
- Parameterized intents: project path, template name, output preferences
- Background execution for scheduled workflows

### Phase 4 — Folder Triggers

- FSEvents monitoring for designated "watch folders"
- When new files appear, run the associated template automatically
- Example: drop a PDF in ~/Inbox/ → Claude processes it according to the template
- Configurable in the project context file

## Dependencies

- context/01-project-context-files.md (templates are context files)
- macos/06-shortcuts-automation.md (Shortcuts.app integration)
- macos/08-file-system-events.md (folder-based triggers)

## Notes

Templates should feel like "Claude remembers how I like things done" — not like "I configured a workflow." The best template is one the user never explicitly created. Claude noticed a pattern, offered to save it, and now it just works.

The Shortcuts integration is the key to workflows. We don't build a workflow builder — Shortcuts.app already is one, and it's better than anything we'd build. We just expose the right intents and let macOS handle the orchestration.

---

*Back to [Index](../../INDEX.md)*
