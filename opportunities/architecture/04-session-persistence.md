# Session Persistence

> **Category:** Architecture & Performance
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical

---

## Current State (Electron / Cowork)

Sessions die when the desktop app closes or the machine sleeps — no background execution whatsoever. Users must keep the Electron window open and their Mac awake for the entire duration of a Cowork task. Closing the lid on a laptop or letting the screen sleep terminates the session, losing any in-progress work. This is one of the most frequently cited frustrations.

## Native macOS Approach

Use macOS **Background Tasks framework**, `NSProcessInfo` activity assertions, and **Launch Agents** to keep sessions alive during sleep, app closure, and even after logout.

### Implementation Strategy

- **Process assertions:** Call `ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Cowork task in progress")` to prevent the system from suspending Atelier or sleeping the machine during active tasks.
- **Background task scheduling:** Use `BGProcessingTaskRequest` for long-running tasks that can survive app termination. Register with `BGTaskScheduler` to resume work after system restart.
- **Launch Agent:** Install a lightweight `launchd` agent (`~/Library/LaunchAgents/com.atelier.agent.plist`) that manages the VM lifecycle independently of the GUI app. The VM persists even if the user quits Atelier; reconnect on relaunch.
- **VM suspend/resume:** Use `VZVirtualMachine.pause()` before sleep and `resume()` on wake. Serialize VM state to disk for cross-reboot persistence.
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
│  │  - VM lifecycle manager    │  │
│  │  - Survives app quit       │  │
│  │  - Survives sleep          │  │
│  │  - Auto-start on login     │  │
│  └─────────────┬──────────────┘  │
│                │                 │
│  ┌─────────────▼──────────────┐  │
│  │  VM (pause/resume capable) │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘
```

### Estimated Impact

| Scenario | Current | Native |
|----------|---------|--------|
| Close laptop lid | ❌ Session lost | ✅ VM paused, resumes on wake |
| Quit app during task | ❌ Session lost | ✅ Agent keeps VM running |
| Reboot machine | ❌ Session lost | ✅ Agent restarts, VM resumes |
| Task completes while away | ❌ No notification | ✅ Push notification on complete |

### Key Dependencies

- `NSProcessInfo` activity assertions
- `BGTaskScheduler` for background processing
- `launchd` Launch Agent for persistent VM management
- `VZVirtualMachine` pause/resume APIs
- `DistributedNotificationCenter` for IPC

### Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Battery drain from background VM | Pause VM after idle timeout; alert user about battery impact for long tasks |
| Launch Agent security concerns | Sign with hardened runtime; use App Group containers for shared data |
| macOS may kill background processes under memory pressure | Checkpoint VM state periodically so work can resume after termination |

---

*Back to [Index](../../INDEX.md)*
