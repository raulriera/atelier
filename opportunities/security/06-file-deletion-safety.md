# File Deletion Safety

> **Category:** Security & Privacy
> **Type:** New Capability · **Priority:** Critical
> **Milestone:** M1

---

## Problem

Viral incident: 11GB of files permanently deleted — a "clean up" prompt caused irreversible data loss. The Linux VM uses `rm` which bypasses macOS Trash entirely. Multiple users reported files deleted while Claude claimed they were still present.

## Solution

Multi-layer protection so file deletion is always recoverable and always visible.

### Defense layers

| Layer | What | How |
|-------|------|-----|
| **Finder capability** | Safe deletion | `finder_trash` uses `NSFileManager.trashItemAtURL` — files go to Trash, never permanently deleted |
| **Approval gating** | User sees before it happens | `finder_trash` excluded from auto-approved tools. Every trash operation requires explicit approval |
| **Bash visibility** | `rm` commands visible | `Bash` not in `silentTools` — user sees full command before approving |
| **Filesystem boundary** | Limited blast radius | File tools scoped to project directory, sensitive paths denied entirely |
| **System prompt** | Behavioral steering | Claude instructed to always prefer `finder_trash` over `rm` |

---

*Back to [Index](../../INDEX.md)*
