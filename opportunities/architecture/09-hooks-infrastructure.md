# Hooks Infrastructure

> **Category:** Architecture
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical

---

## Problem

Atelier wraps the Claude CLI as a subprocess. Today, all intelligence about what happens during a conversation lives in the app — parsing NDJSON stream events, detecting when responses finish, deciding when to distill learnings. But the CLI has a rich hook system (18 event types) that fires at lifecycle moments the app can't observe from the stream alone:

- **Compaction** — the context window fills and compresses. The app has no way to detect this from the stream. Learnings accumulated during a long session vanish.
- **Session lifecycle** — startup, resume, clear, compact. The app can detect `system.init` but nothing else.
- **Tool execution** — pre/post hooks on every tool call. The app sees tool results in the stream, but can't inject behavior before or after execution.
- **Instructions loaded** — when CLAUDE.md or memory files are read. The app has no visibility into this.

Without hooks, Atelier is a passive observer. With hooks, it becomes an active participant in the CLI's lifecycle.

## Solution

Build a hooks management layer that:

1. **Writes hooks configuration** to `.claude/settings.local.json` (project-scoped, gitignored) when a project opens
2. **Bundles helper binaries** that hooks invoke — same pattern as capability helpers in `Contents/Helpers/`
3. **Cleans up** when projects close or Atelier is uninstalled

### Configuration management

The CLI reads hooks from settings files only — no CLI flag for temp configs (unlike MCP servers). Atelier must write to `.claude/settings.local.json` to register hooks without polluting the committed `.claude/settings.json`.

```swift
/// Manages hook registration in .claude/settings.local.json
struct HooksManager {
    let projectRoot: URL

    /// Registers Atelier's hooks, preserving any user-defined hooks.
    func install() throws

    /// Removes Atelier's hooks, preserving user-defined hooks.
    func uninstall() throws
}
```

Key constraints:
- **Merge, don't overwrite** — the user may have their own hooks in `settings.local.json`
- **Idempotent** — calling `install()` twice produces the same result
- **Scoped removal** — `uninstall()` only removes hooks Atelier registered

### Helper binary pattern

Hook commands invoke bundled helpers via absolute path:

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "compact",
      "hooks": [{
        "type": "command",
        "command": "/Applications/Atelier.app/Contents/Helpers/atelier-hooks compact-reinject"
      }]
    }]
  }
}
```

A single `atelier-hooks` binary handles all hook events via subcommands, keeping the binary count manageable. It reads stdin (hook input JSON), performs the action, and writes to stdout.

### What hooks get `transcript_path`

Every hook receives `transcript_path` — the full conversation as a JSONL file. This is dramatically richer than the `ConversationSummarizer` output we currently build app-side. The helper binary can read the transcript directly for distillation, file tracking, or any other analysis.

## Available Hook Events

The CLI exposes 18 hook events. Here's the full inventory with Atelier's planned usage:

### Session Lifecycle

| Event | Matchers | Fires when | Planned use |
|-------|----------|-----------|-------------|
| `SessionStart` | `startup`, `resume`, `clear`, `compact` | Session begins or resumes | Re-inject learnings after compaction; inject project context on startup |
| `SessionEnd` | `clear`, `logout`, `prompt_input_exit`, `other` | Session terminates | Final distillation; cleanup |
| `PreCompact` | `manual`, `auto` | Before context compresses | Trigger distillation before context is lost |
| `Stop` | — | Claude finishes responding | Trigger incremental distillation |

### Tool Execution

| Event | Matchers | Fires when | Planned use |
|-------|----------|-----------|-------------|
| `PreToolUse` | Tool name (regex) | Before tool executes | Audit logging; command validation |
| `PostToolUse` | Tool name (regex) | After tool succeeds | Track file changes (`Write\|Edit`); update project structure map |
| `PostToolUseFailure` | Tool name (regex) | After tool fails | Record failed approaches in learnings |
| `PermissionRequest` | Tool name (regex) | Permission dialog about to show | Future: auto-approve based on project trust |

### Context & Configuration

| Event | Matchers | Fires when | Planned use |
|-------|----------|-----------|-------------|
| `InstructionsLoaded` | — | CLAUDE.md or memory file loaded | Verify memory files are being read; track load order |
| `UserPromptSubmit` | — | User submits a prompt | Future: prompt augmentation with project context |
| `Notification` | `permission_prompt`, `idle_prompt`, `auth_success` | CLI sends notification | Surface in app UI; trigger background work on idle |
| `ConfigChange` | `user_settings`, `project_settings`, etc. | Config file changes | Re-read project settings |

### Agent & Team

| Event | Matchers | Fires when | Planned use |
|-------|----------|-----------|-------------|
| `SubagentStart` | Agent type | Subagent spawned | Future: multi-agent visibility |
| `SubagentStop` | Agent type | Subagent finishes | Future: collect subagent learnings |
| `TeammateIdle` | — | Teammate goes idle | Future: team orchestration |
| `TaskCompleted` | — | Task marked complete | Future: task tracking |

### Workspace

| Event | Matchers | Fires when | Planned use |
|-------|----------|-----------|-------------|
| `WorktreeCreate` | — | Git worktree created | Future: workspace awareness |
| `WorktreeRemove` | — | Git worktree removed | Future: cleanup |

## Hook Types

The CLI supports four hook types. Relevance to Atelier:

| Type | What it does | Atelier use |
|------|-------------|-------------|
| `command` | Runs a shell command (stdin JSON → stdout) | Primary — bundled helper binary |
| `http` | POSTs to a URL | Alternative — POST to Atelier's local server |
| `prompt` | Single LLM call (Haiku) | Lightweight validation/analysis |
| `agent` | Spawns a subagent with tool access | Deep analysis (file inspection, etc.) |

For distillation, `command` hooks calling the bundled helper are the right choice — fast, no network dependency, full control over the binary.

## Implementation

### Phase 1 — HooksManager + compaction hook ✅

1. ~~Create `HooksManager` in AtelierKit — reads/writes `.claude/settings.local.json`~~
2. ~~Bundle `atelier-hooks` helper binary with `reinject` subcommand~~
3. ~~Register `SessionStart[compact/startup/resume]` hooks on project open~~
4. ~~The hook reads `.atelier/memory/learnings.md` and writes to stdout → CLI re-injects as context~~
5. ~~Coexistence with user-defined hooks — Atelier hooks identified by `[Atelier]` statusMessage prefix~~

### Phase 2 — Hook-based distillation ✅

6. ~~Register `Stop` hook for async incremental distillation~~
7. ~~Register `PreCompact[auto]` hook for sync pre-compaction distillation~~
8. ~~`atelier-hooks distill` subcommand reads `transcript_path` directly — richer than summarizer~~
9. ~~Remove `ConversationSummarizer`, `triggerDistillation()` from app-side code~~
10. ~~Xcode build phase compiles helper into `Contents/Helpers/atelier-hooks`~~

**Deferred:** `SessionEnd` hook for final distillation (low priority — `Stop` already fires on last response)

### Phase 3 — File tracking + project awareness

10. Register `PostToolUse[Write|Edit]` hook to track file changes
11. Build project structure map from accumulated file operations
12. Feed into living context system (context/05-living-context.md)

### Phase 4 — Observability hooks

13. Register `InstructionsLoaded` for memory file load verification
14. Register `Notification[idle_prompt]` for background work triggers
15. Register `PostToolUseFailure` to record failed approaches

## Dependencies

- context/05-living-context.md (distillation is the core use case)
- architecture/08-mcp-helper-kit.md (shared infrastructure for helper binaries)
- hub/03-plugin-management.md (capability system uses similar patterns)

## Notes

### Hook configuration is per-project, not per-session

Hooks in `.claude/settings.local.json` persist across sessions. Atelier should install hooks when a project opens and leave them — they're useful even when the user runs the CLI directly outside Atelier. This is a feature: the user's project gets smarter regardless of how they talk to Claude.

### Hooks run in parallel

All matching hooks for an event fire simultaneously. Atelier's hooks should be fast (< 1s) to avoid slowing down the CLI. The `async: true` flag is available for hooks that can run in the background (like distillation).

### The `transcript_path` advantage

Every hook receives the full conversation transcript as a JSONL file. This is far richer than the `ConversationSummarizer` output (which truncates messages, drops thinking, and caps at 100 items). The helper binary can parse the transcript for high-fidelity distillation.

### Exit codes matter

- Exit 0 → success, stdout parsed as JSON or context
- Exit 2 → block/deny (for hooks that support it)
- Other → non-blocking error, logged in verbose mode

---

*Back to [Index](../../INDEX.md)*
