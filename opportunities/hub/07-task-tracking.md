# Task Tracking (TodoWrite)

> **Milestone:** —

## Status: 🔴 Broken

## Problem

The Claude CLI's built-in `TodoWrite` tool provides a persistent task checklist that tracks multi-step work in real time. This is a core UX feature of Claude Cowork — the first thing users see is a live progress checklist above the compose field.

Atelier has a complete UI implementation for this (TaskCard, TaskListOverlay, TaskEntry, TaskPreviewFixtures) and full parsing/session integration. **None of it works.** The tool calls never succeed when invoked through Atelier.

### What happens

1. The CLI has a built-in `TodoWrite` tool that sends the full todo list as JSON: `{"todos": [{"id":"1","content":"...","status":"pending"}, ...]}`
2. Atelier uses `--permission-prompt-tool` to route unapproved tools through an approval MCP helper
3. `TodoWrite` is not in the auto-approved `silentTools` list, so it goes through the approval flow
4. The approval helper round-trips the input through JSON serialization (AnyCodableValue → JSON string → back), which corrupts the nested `todos` array
5. The CLI receives mangled input and throws a type error
6. The model sees the error, reports "TodoWrite is down", and falls back to writing plain-text checklists

### What was tried and failed

- Adding TodoWrite to `silentTools` — model still didn't use it (unclear why; may need further investigation in a clean environment)
- Providing a replacement `mcp__atelier__todo_write` MCP tool — tool was available and auto-approved, but models (Haiku, Sonnet) ignored it despite system prompt instructions
- Blocking built-in TodoWrite via `--disallowedTools` to force models toward the MCP replacement — models still didn't call it
- Auto-generating task entries from regular tool calls — introduced too much complexity for an unreliable result

## What exists today

The UI and parsing code is complete and tested:

- `Atelier/Views/Tasks/TaskCard.swift` — Liquid Glass checklist card
- `Atelier/Views/Tasks/TaskListOverlay.swift` — Persistent overlay above compose field
- `Atelier/Views/Tasks/TaskPreviewFixtures.swift` — Preview data
- `Packages/AtelierKit/Sources/AtelierKit/Models/TaskEntry.swift` — Task list builder (supports TodoWrite and TaskCreate/TaskUpdate formats)
- `Packages/AtelierKit/Sources/AtelierKit/Models/TaskStatus.swift` — Status enum + TodoItem parser
- `Packages/AtelierKit/Sources/AtelierKit/Models/ToolUseEvent.swift` — `isTaskOperation`, `todoItems` parsing
- `Packages/AtelierKit/Sources/AtelierKit/Session/Session.swift` — `taskEntries`, `hasActiveTasks`, cache invalidation
- `Packages/AtelierKit/Tests/AtelierKitTests/SessionTaskTests.swift` — Full test coverage

All of this code works correctly when TodoWrite events arrive. The problem is they never arrive.

## Solution

Needs root-cause investigation:

1. **Understand why `silentTools` alone doesn't fix it.** Adding TodoWrite to the auto-approved list should bypass the approval flow entirely. If the model still doesn't call it, the issue is upstream (CLI not exposing the tool, model not inclined to use it in `-p` mode, or something else).
2. **Compare CLI invocation.** Run the same prompt through `claude` directly (not through Atelier) with identical flags and check if TodoWrite is called. This isolates whether the problem is Atelier-specific or CLI-wide in `-p` mode.
3. **Check tool visibility.** Verify that the model's tool list actually includes TodoWrite when running through Atelier's CLI flags. The `--verbose` flag or stream events may reveal this.

## Dependencies

- Claude CLI (`claude` binary) — TodoWrite is a built-in tool, not something Atelier controls
- Model behavior — even with the tool available, models must choose to use it

## Priority

**Critical.** This is a flagship feature that defines the Cowork UX. Without it, Atelier's conversation experience is missing its most visible differentiator.
