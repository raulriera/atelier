# Sandboxed Execution

> **Category:** Architecture & Performance
> **Type:** Improvement · **Priority:** 🔴 Critical

---

## Current State (Electron / Cowork)

Linux VM via Apple Virtualization Framework — boots full Ubuntu 22.04 with 4 vCPUs, 3.8GB RAM, ~10GB sparse virtual disk per session. The Electron app wraps the Virtualization.framework calls through layers of JavaScript-to-native bridging, adding complexity and potential failure points. Each Cowork session spins up a complete Linux environment with the Claude Code CLI running inside it.

## Native macOS Approach

Use **Apple Virtualization.framework directly from Swift** — same VM isolation model, but eliminate the Electron IPC overhead layer entirely. For lighter tasks that don't need a full Linux toolchain, explore macOS native sandboxing via App Sandbox + XPC services.

### Implementation Strategy

- **Primary path (VM):** Call `VZVirtualMachine`, `VZVirtualMachineConfiguration`, and `VZLinuxBootLoader` directly from Swift. No JavaScript bridge. Configure vCPU count, memory, and disk dynamically based on task complexity.
- **Lightweight path (XPC):** For simple file operations (rename, organize, move), skip the VM entirely. Use an XPC service running in a sandboxed process with minimal entitlements. Faster startup, lower resource usage.
- **Hybrid model:** The app decides at task-planning time whether to use the lightweight XPC path or the full VM path based on the tools the agent needs (e.g., Python/Node → VM; file rename → XPC).
- **VM lifecycle:** Pre-warm a VM on app launch in the background. Suspend/resume via `VZVirtualMachine.pause()` and `resume()` instead of cold-booting per session.

### Architecture Diagram

```
┌─────────────────────────────────────┐
│         Atelier            │
│  ┌──────────┐  ┌─────────────────┐  │
│  │ SwiftUI  │  │ Task Planner    │  │
│  │   UI     │  │ (decides path)  │  │
│  └────┬─────┘  └───┬────────┬────┘  │
│       │            │        │       │
│  ┌────▼────┐ ┌─────▼──┐ ┌──▼────┐  │
│  │ Session │ │  XPC   │ │  VM   │  │
│  │ Manager │ │Service │ │Bridge │  │
│  └─────────┘ │(light) │ │(heavy)│  │
│              └────────┘ └───┬───┘  │
│                             │       │
│              ┌──────────────▼────┐  │
│              │ Virtualization.fw │  │
│              │  Ubuntu 22.04 VM │  │
│              │  Claude Code CLI │  │
│              └──────────────────┘  │
└─────────────────────────────────────┘
```

### Estimated Impact

| Metric | Current (Electron + VM) | Native | Improvement |
|--------|------------------------|--------|-------------|
| VM boot time | 5–8s | 2–3s (pre-warmed: <1s) | ~70% faster |
| IPC latency | ~10–50ms per call | <1ms (direct Swift) | ~95% less |
| Light task startup | 5–8s (always boots VM) | <0.5s (XPC path) | ~95% faster |

### Key Dependencies

- Virtualization.framework (macOS 12+, Apple Silicon required for Linux VMs)
- XPC Services framework
- Entitlements: `com.apple.security.virtualization`

### Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Intel Mac users can't run ARM64 Linux VMs | Provide XPC-only fallback with reduced capabilities; document Apple Silicon requirement |
| VM pre-warming consumes resources at idle | Only pre-warm when app is in foreground; release after 5 min of inactivity |
| XPC path has limited capabilities | Clear capability matrix; auto-escalate to VM when XPC can't handle the task |

---

*Back to [Index](../../INDEX.md)*
