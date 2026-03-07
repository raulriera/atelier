# File Deletion Safety

> **Category:** Security & Privacy
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical
> **Milestone:** M1

---

## Problem

Viral incident: 11GB of files permanently deleted — a "clean up" prompt caused irreversible data loss. Developer James McAulay demonstrated that asking Cowork to organize a directory resulted in permanent deletion of YouTube footage and LinkedIn assets. Other users reported similar experiences — files deleted while Claude claimed they were still present. The Linux VM uses `rm` which bypasses macOS Trash entirely.

## Current State (Atelier)

Atelier's Finder capability and approval system already provide multi-layer protection against accidental deletion.

### Layer 1: Finder capability with `finder_trash`

The Finder capability (`atelier-finder-mcp`) provides a `finder_trash` tool that uses `NSFileManager.trashItemAtURL` — files go to macOS Trash, never permanently deleted. The system prompt hint explicitly instructs Claude:

> *"When deleting files, ALWAYS use finder_trash instead of the rm command. finder_trash moves files to the Trash (recoverable), while rm permanently deletes them."*

### Layer 2: `finder_trash` requires approval

`finder_trash` is intentionally excluded from the Finder capability's auto-approved tool groups (`browse` and `organize`). Every trash operation shows an approval card the user must accept.

### Layer 3: `Bash` requires approval

The `Bash` tool is not in `silentTools`, so any `rm` command shows an approval card with the full command visible. The user sees exactly what will be deleted before approving.

### Layer 4: Filesystem boundary (Phase 1–2)

File-reading tools are scoped to the project directory. Sensitive paths (`.ssh`, `.aws`, etc.) are denied entirely. This limits the blast radius of any file operation.

## What's Covered

| Scenario | Protection |
|----------|-----------|
| Claude uses `finder_trash` | Moves to Trash (recoverable) + approval card |
| Claude uses `rm` via Bash | Approval card shows full command |
| Claude reads sensitive files first | Filesystem boundary blocks access |
| Batch "clean up" operation | Each tool call gets its own approval |

## Remaining Gaps

### No `rm` interception

If the user approves a `Bash` command containing `rm -rf`, the deletion is permanent. The system prompt steers Claude toward `finder_trash`, but a determined prompt injection or user override could bypass this.

**Potential fix:** A `PreToolUse` hook on `Bash` that inspects the command for destructive patterns (`rm`, `rmdir`, `unlink`) and either blocks or escalates to a warning-level approval card. Trade-off: false positives on legitimate commands.

### No batch operation manifest

When Claude processes many files (e.g. "organize my Downloads"), each tool call is separate. There's no consolidated "here's what will happen to 47 files" preview. The user approves one at a time or uses session-scoped auto-approval.

**Potential fix:** An aggregate approval card that batches related file operations into a single reviewable manifest. This requires changes to the approval flow and is deferred to M3.

### No undo beyond Trash

Files moved to Trash can be restored. But file moves, renames, and copies via Finder tools have no undo mechanism. If Claude renames 50 files wrong, the user must fix them manually.

**Potential fix:** Operation manifest logging + a "Revert" action. Deferred.

## Implementation Status

- ✅ `finder_trash` uses `NSFileManager.trashItemAtURL` (safe deletion)
- ✅ `finder_trash` excluded from auto-approved tools (requires approval card)
- ✅ `Bash` requires approval (user sees `rm` commands)
- ✅ System prompt steers Claude to `finder_trash` over `rm`
- ✅ Filesystem boundary limits file access scope
- 🔲 `PreToolUse` hook to intercept `rm` in Bash commands
- 🔲 Batch operation manifest / aggregate approval
- 🔲 Operation undo beyond Trash

## Dependencies

- security/07-cli-filesystem-boundary.md (filesystem boundary limits blast radius)
- context/04-approval-review-flow.md (approval cards gate destructive operations)
- hub/03-plugin-management.md (Finder capability provides `finder_trash`)

---

*Back to [Index](../../INDEX.md)*
