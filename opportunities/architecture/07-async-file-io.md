# Async File I/O on Hot Paths

> **Category:** Architecture
> **Type:** Technical Debt · **Priority:** Medium
> **Milestone:** — · **Status:** 🔲 Not started

---

## Problem

`ContextFileLoader.contentForInjection(from:)` and `MemoryStore.readLearnings()` do synchronous file I/O on the main thread. The files are small (< 1KB typically), so this doesn't cause visible jank today — but it's a pattern that should be fixed before it becomes entrenched as memory files grow.

## Solution

Use `.task` modifiers for view-driven reads and async methods for model-driven reads. All file I/O on hot paths (session open, context injection) should be non-blocking.

---

*Back to [Index](../../INDEX.md)*
