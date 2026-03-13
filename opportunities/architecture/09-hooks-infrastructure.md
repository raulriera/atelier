# Hooks Infrastructure

> **Category:** Architecture
> **Type:** New Capability · **Priority:** Critical
> **Milestone:** M2

---

## Problem

Atelier wraps the Claude CLI as a subprocess. Without hooks, Atelier is a passive observer — it can't detect compaction, inject context after compression, track file changes, or validate tool access. The CLI's hook system (18 event types) fires at lifecycle moments the stream alone can't capture.

## Solution

A hooks management layer that writes hooks configuration to `.claude/settings.local.json` when a project opens, bundles helper binaries that hooks invoke, and cleans up on uninstall.

### Key principles

- **Merge, don't overwrite** — user-defined hooks are preserved
- **Idempotent** — calling install twice produces the same result
- **Scoped removal** — uninstall only removes Atelier's hooks (identified by `[Atelier]` statusMessage prefix)

### Single helper binary pattern

A single `atelier-hooks` binary handles all hook events via subcommands (`distill`, `reinject`, `path-guard`), keeping the binary count manageable. It reads stdin (hook input JSON), performs the action, and writes to stdout.

### Hooks registered

| Event | Matcher | Purpose |
|-------|---------|---------|
| `SessionStart` | `compact/startup/resume` | Re-inject learnings, stale context, corrections, proactive suggestions |
| `Stop` | — | Async distillation after each response |
| `PreCompact` | `auto` | Sync distillation + compaction snapshot before context compresses |
| `PreToolUse` | `Read\|Glob\|Grep\|Write\|Edit\|MultiEdit\|NotebookEdit` | Path guard — validates file access against project boundary |

### The `transcript_path` advantage

Every hook receives the full conversation transcript as a JSONL file — far richer than any app-side summarizer. The helper binary parses it for high-fidelity distillation.

## Future hooks

- `InstructionsLoaded` — verify memory file load order
- `Notification[idle_prompt]` — background work triggers
- `PostToolUseFailure` — record failed approaches
- Subagent lifecycle hooks — multi-agent visibility

---

*Back to [Index](../../INDEX.md)*
