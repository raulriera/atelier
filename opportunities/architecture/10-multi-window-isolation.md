# Multi-Window Session Isolation

> **Category:** Architecture
> **Type:** Bug · **Priority:** ~~Critical~~ Fixed
> **Milestone:** — · **Status:** ✅ Fixed

---

## Problem

Pending approvals in one project window blocked all other windows. Root cause: `FileHandle.AsyncBytes` serializes concurrent pipe reads when SwiftUI is running — a Foundation bug.

## Fix

Replaced `handle.bytes.lines` with custom `CLIEngine.lines(from:)` using blocking POSIX `read()` on a detached task. Each CLI process now reads independently without cross-window serialization.

---

*Back to [Index](../../INDEX.md)*
