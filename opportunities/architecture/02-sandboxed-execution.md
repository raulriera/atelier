# Sandboxed Execution

> **Category:** Architecture & Performance
> **Type:** Improvement · **Priority:** 🔴 Critical

---

## Current State (Electron / Cowork)

Linux VM via Apple Virtualization Framework — boots full Ubuntu 22.04 with 4 vCPUs, 3.8GB RAM, ~10GB sparse virtual disk per session. The Electron app wraps the Virtualization.framework calls through layers of JavaScript-to-native bridging, adding complexity and potential failure points. Each Cowork session spins up a complete Linux environment with the Claude Code CLI running inside it.

## Native macOS Approach

Use **Apple's [Containerization](https://github.com/apple/containerization) Swift package** — a first-party framework (open source, macOS 26+) that wraps Virtualization.framework and provides a VM-per-container model with sub-second startup, OCI image support, and integrated networking. Instead of managing raw VM lifecycle ourselves, we build on Apple's abstraction.

For lighter tasks that don't need a full Linux toolchain, use macOS native sandboxing via App Sandbox + XPC services.

### Why Containerization over raw Virtualization.framework

| Concern | Raw Virtualization.framework | Apple Containerization |
|---------|------------------------------|----------------------|
| VM lifecycle | Manual boot/pause/resume | Managed by the framework |
| Filesystem | Build ext4 rootfs yourself | ext4 implementation included, OCI image support |
| Networking | Configure VZNetworkDevice manually | `container-network-vmnet` handles it |
| Kernel | Source and build your own | Optimized Linux kernel included, sub-second boot |
| Image management | Roll your own | OCI-compatible — pull from any container registry |
| Maintenance | All on us | Apple maintains the hard parts |

### Implementation Strategy

- **Primary path (Containers):** Import `Containerization` as a Swift package dependency. Define a container image with Claude Code CLI and required tooling pre-installed. Launch per-session containers with sub-second startup.
- **Lightweight path (XPC):** For simple file operations (rename, organize, move), skip the container entirely. Use an XPC service running in a sandboxed process with minimal entitlements. Faster startup, lower resource usage.
- **Hybrid model:** The app decides at task-planning time whether to use the lightweight XPC path or the full container path based on the tools the agent needs (e.g., Python/Node → container; file rename → XPC).
- **Image management:** Build a custom OCI image with Claude Code CLI, common runtimes (Node, Python), and minimal OS. Push to a registry. Atelier pulls and caches on first launch.

### Architecture Diagram

```
┌─────────────────────────────────────┐
│         Atelier (macOS 26)          │
│  ┌──────────┐  ┌─────────────────┐  │
│  │ SwiftUI  │  │ Task Planner    │  │
│  │   UI     │  │ (decides path)  │  │
│  └────┬─────┘  └───┬────────┬────┘  │
│       │            │        │       │
│  ┌────▼────┐ ┌─────▼──┐ ┌──▼─────┐ │
│  │ Session │ │  XPC   │ │Container│ │
│  │ Manager │ │Service │ │Manager  │ │
│  └─────────┘ │(light) │ └───┬────┘ │
│              └────────┘     │      │
│                      ┌──────▼────┐ │
│                      │ Container-│ │
│                      │ ization   │ │
│                      │ (Swift)   │ │
│                      └──────┬────┘ │
│                      ┌──────▼────┐ │
│                      │ Virtualiz-│ │
│                      │ tion.fw   │ │
│                      │ Linux VM  │ │
│                      │ (OCI img) │ │
│                      └───────────┘ │
└─────────────────────────────────────┘
```

### Estimated Impact

| Metric | Current (Electron + VM) | Native | Improvement |
|--------|------------------------|--------|-------------|
| Container startup | 5–8s | <1s (Containerization optimized kernel) | ~90% faster |
| IPC latency | ~10–50ms per call | <1ms (direct Swift) | ~95% less |
| Light task startup | 5–8s (always boots VM) | <0.5s (XPC path) | ~95% faster |
| Image updates | Manual VM image rebuild | `container pull` from registry | Trivial |

### Key Dependencies

- [apple/containerization](https://github.com/apple/containerization) Swift package
- macOS 26+, Apple Silicon required
- XPC Services framework
- Entitlements: `com.apple.security.virtualization`

### Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| macOS 26 minimum limits user base | macOS 26 is current; Containerization is Apple's direction — bet on the future |
| Containerization package is pre-1.0 (breaking changes between minor versions) | Pin to `.upToNextMinorVersion`, test on each update, contribute upstream |
| OCI image size and pull time on first launch | Ship a minimal base image; lazy-pull additional tooling on demand |
| XPC path has limited capabilities | Clear capability matrix; auto-escalate to container when XPC can't handle the task |

---

*Back to [Index](../../INDEX.md)*
