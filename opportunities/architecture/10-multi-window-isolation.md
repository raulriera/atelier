# Multi-Window Session Isolation

> **Category:** Architecture
> **Type:** Bug · **Priority:** ~~🔴 Critical~~ ✅ Fixed
> **Milestone:** —

---

## Problem

When multiple project windows are open, a pending approval request in one window blocks all other windows. Denying the approval in one window causes all windows to resume simultaneously.

## Root Cause

`FileHandle.AsyncBytes` (used by `handle.bytes.lines`) serializes concurrent pipe reads within a SwiftUI app process. When two `Process` instances write to separate `Pipe` stdout handles and both are read via `bytes.lines` in `Task.detached` blocks, the second pipe produces no data until the first pipe's process resumes output.

This is a Foundation bug — the same code works correctly in a standalone Swift executable without SwiftUI. Filed as a swift-foundation issue.

## Fix

Replaced `handle.bytes.lines` with a custom `CLIEngine.lines(from:)` that reads from the pipe's file descriptor using blocking POSIX `read()` on a detached task. This bypasses Foundation's `AsyncBytes` entirely and produces lines as an `AsyncStream<String>`.

## Investigation Timeline

Ruled out before identifying root cause:
- Claude CLI serialization (standalone reproduction proved concurrent `claude -p --permission-prompt-tool` works)
- `FileHandle.bytes.lines` in isolation (works in non-SwiftUI context)
- Main-actor starvation (standalone `@MainActor` consumption works)
- MCP server naming (each window has unique socket, shared name is local to each CLI config)
- `Task.yield()` in streaming loop
- `withAnimation` on approval cards
- `Task.detached` for streaming consumption
- CLI lock files
- App sandbox (disabled for main target)

## Dependencies

- None — this is a bug in existing architecture

---

*Back to [Index](../../INDEX.md)*
