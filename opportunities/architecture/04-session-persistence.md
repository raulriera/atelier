# Session Persistence

> **Category:** Architecture & Performance
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical

---

## Current State (Electron / Cowork)

Sessions die when the desktop app closes or the machine sleeps — no background execution whatsoever. Users must keep the Electron window open and their Mac awake for the entire duration of a Cowork task. Closing the lid on a laptop or letting the screen sleep terminates the session, losing any in-progress work. This is one of the most frequently cited frustrations.

## Native macOS Approach

Use macOS **Background Tasks framework**, `NSProcessInfo` activity assertions, and **Launch Agents** to keep sessions alive during sleep, app closure, and even after logout. Containers managed by the Containerization framework can be paused and resumed as the system state changes.

### Implementation Strategy

- **Process assertions:** Call `ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Cowork task in progress")` to prevent the system from suspending Atelier or sleeping the machine during active tasks.
- **Background task scheduling:** Use `BGProcessingTaskRequest` for long-running tasks that can survive app termination. Register with `BGTaskScheduler` to resume work after system restart.
- **Launch Agent:** Install a lightweight `launchd` agent (`~/Library/LaunchAgents/com.atelier.agent.plist`) that manages the container lifecycle independently of the GUI app. Containers persist even if the user quits Atelier; reconnect on relaunch.
- **Container pause/resume:** Pause containers before sleep and resume on wake. Checkpoint container state to disk for cross-reboot persistence.
- **Status reporting:** Use `DistributedNotificationCenter` to communicate task status between the Launch Agent and the GUI app, plus `UserNotifications` to alert the user when a background task completes.

### Architecture

```
┌──────────────────────────────────┐
│  macOS System                    │
│                                  │
│  ┌────────────┐  ┌────────────┐  │
│  │ Native GUI │◄─┤ Distributed│  │
│  │  (SwiftUI) │  │  Notif.    │  │
│  └─────┬──────┘  └─────┬──────┘  │
│        │               │         │
│  ┌─────▼───────────────▼──────┐  │
│  │  Launch Agent (launchd)    │  │
│  │  - Container lifecycle     │  │
│  │  - Survives app quit       │  │
│  │  - Survives sleep          │  │
│  │  - Auto-start on login     │  │
│  └─────────────┬──────────────┘  │
│                │                 │
│  ┌─────────────▼──────────────┐  │
│  │  Containerization          │  │
│  │  (pause/resume capable)    │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘
```

### Estimated Impact

| Scenario | Current | Native |
|----------|---------|--------|
| Close laptop lid | ❌ Session lost | ✅ Container paused, resumes on wake |
| Quit app during task | ❌ Session lost | ✅ Agent keeps container running |
| Reboot machine | ❌ Session lost | ✅ Agent restarts, container resumes |
| Task completes while away | ❌ No notification | ✅ Push notification on complete |

### Key Dependencies

- [apple/containerization](https://github.com/apple/containerization) — container pause/resume
- `NSProcessInfo` activity assertions
- `BGTaskScheduler` for background processing
- `launchd` Launch Agent for persistent container management
- `DistributedNotificationCenter` for IPC

### Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Battery drain from background container | Pause container after idle timeout; alert user about battery impact for long tasks |
| Launch Agent security concerns | Sign with hardened runtime; use App Group containers for shared data |
| macOS may kill background processes under memory pressure | Checkpoint container state periodically so work can resume after termination |

---

## Current Implementation Status

> ⚠️ **The current implementation uses global primitives that don't support the multi-project model.**

What's been built:
- `DiskSessionPersistence` saves/loads sessions as JSON files in `~/Library/Application Support/Atelier/sessions/`
- `Session.save(to:)` and auto-restore of most recent session on launch
- Sessions survive app closure and relaunch

What's wrong:
- **Global persistence:** A single `DiskSessionPersistence` instance is shared across all windows. `loadMostRecent()` returns the same session regardless of which project window is asking.
- **No project scoping:** Sessions aren't tied to a project folder. Opening two project windows overwrites the same "most recent" slot.
- **No per-project storage:** Session files live in a flat global directory, not organized by project.

What needs to change for multi-project support:
- Session persistence must be scoped per-project (e.g., `~/Library/.../sessions/{projectID}/`)
- Each window must receive its own `SessionPersistence` instance bound to its project
- `loadMostRecent()` should be per-project, not global
- Depends on 3.1 Project Workspace establishing the `Project` model first

---

*Back to [Index](../../INDEX.md)*
