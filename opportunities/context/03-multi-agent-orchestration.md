# Multi-Agent Orchestration

> **Category:** Context Control & Agent Intelligence
> **Type:** Improvement · **Priority:** 🟡 Medium
> **Milestone:** M5

---

## Problem

Complex tasks are decomposed into subtasks handled by multiple models working simultaneously. But orchestration is completely opaque — users see a single progress stream with no visibility into what's happening underneath.

## Solution

Orchestration is invisible by default. When Claude needs to do multiple things at once, the conversation shows progress naturally — not through a dashboard, but through the same inline cards used for everything else.

### What users see

**Simple tasks** — nothing special. Claude responds. One message, one response.

**Complex tasks** — Claude's response includes nested progress cards:

```
Claude is working on your request...

  ├─ Reading 47 PDF files          ✅ Done
  ├─ Analyzing contract terms      ⏳ In progress
  └─ Generating summary report     ○ Waiting

This will take about 2 minutes.
```

These are children of the `AssistantMessage` — drillable. Tap any line to see details. But by default, you just see progress and results.

### What users don't see

No "Activity Monitor-style dashboard." No sidebar with agent cards. No Gantt-style timeline of sub-agents. That level of detail conflicts with our simplicity moat and isn't useful to most people.

### Power users

The inspector panel (`⌘I`) can show:
- Per-step token usage for the current response
- Which model handled each step (Opus vs Sonnet)
- Timing breakdown

This is progressive disclosure — hidden by default, available for those who care.

### User-defined agents (power users)

Claude Code supports custom agent definitions (`.claude/agents/AGENT.md`) with frontmatter controlling model, tools, permissions, memory, and isolation. For knowledge-work projects, this enables user-created specialists:

```yaml
---
name: proofreader
description: "Review documents for grammar, tone, and style"
tools: "Read,Grep,Glob"
model: haiku
---
Review the document for passive voice, clichés, and inconsistent tone.
Flag issues with line references. Do not modify files.
```

Atelier can surface these as named assistants within the orchestration UI — "Claude is using your proofreader to review the draft" — without building a separate agent management system. The agent definitions live in the project folder, are editable markdown, and work with the CLI directly.

The `SubagentStart` and `SubagentStop` hooks provide the event stream needed for the progress cards below — each fires when an agent spawns or completes, giving Atelier the timing and metadata to render nested progress without polling.

## Implementation

### Phase 1 — Nested Progress Cards

- `ProgressCard` items nested inside `AssistantMessage.children` (already in data model)
- Each shows: description, status (waiting/running/done/failed), optional progress percentage
- Animated status transitions in the conversation timeline

### Phase 2 — Drillable Details

- Tap a progress card to expand: see what that step produced, how many tokens it used
- Collapse back to the compact view
- All in the conversation timeline — no separate panel

### Phase 3 — Inspector Integration

- Per-step model attribution and token accounting in the inspector panel
- Only visible when inspector is open (`⌘I`)
- Useful for debugging and cost optimization, not for everyday use

## Dependencies

- architecture/06-conversation-model.md (nested children in AssistantMessage)
- hub/05-token-usage-visibility.md (per-step token attribution)

## Notes

The key insight: orchestration visibility is a feature of the conversation timeline, not a separate UI. Progress cards, nested children, and drillable details are the same patterns used everywhere else in the app. We don't need a dashboard because the conversation already shows what's happening.

---

*Back to [Index](../../INDEX.md)*
