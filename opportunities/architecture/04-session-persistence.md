# Session Persistence

> **Category:** Architecture & Performance
> **Type:** New Capability · **Priority:** Critical
> **Milestone:** M2 · **Status:** ✅ Done (basic persistence)

---

## Problem

In Cowork, sessions die when the app closes or the machine sleeps. Users must keep the window open and their Mac awake for the entire duration of a task. Closing the lid terminates the session, losing in-progress work.

## Solution

Use macOS background execution primitives to keep sessions alive during sleep, app closure, and reboot.

### Levels of persistence

| Scenario | Cowork | Atelier |
|----------|--------|---------|
| Close laptop lid | Session lost | Container paused, resumes on wake |
| Quit app during task | Session lost | Agent keeps container running |
| Reboot machine | Session lost | Agent restarts, container resumes |
| Task completes while away | No notification | Push notification on complete |

### Architecture

A `launchd` Launch Agent manages the CLI lifecycle independently of the GUI app. `NSProcessInfo` activity assertions prevent system suspension during active tasks. `DistributedNotificationCenter` communicates status between the agent and the GUI.

## Status

| Feature | Status |
|---------|--------|
| Per-project session persistence to disk | ✅ Shipped |
| Two-file storage (lightweight main + heavy sidecar) | ✅ Shipped |
| Auto-restore most recent session per project | ✅ Shipped |
| Lossy decoding (corrupted items skipped) | ✅ Shipped |
| Interrupted session flagging | ✅ Shipped |
| Launch Agent for background execution | 🔲 Not started |
| Container pause/resume across sleep | 🔲 Not started (containers deferred) |

---

*Back to [Index](../../INDEX.md)*
