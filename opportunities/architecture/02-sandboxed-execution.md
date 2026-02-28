# Sandboxed Execution

> **Category:** Architecture & Performance
> **Type:** Improvement · **Priority:** 🔴 Critical
> **Milestone:** M1

---

## Problem

Claude's desktop app runs agent work inside a full Ubuntu VM — 4 vCPUs, 3.8GB RAM, ~10GB disk per session, 5–8 seconds to boot. Every task, no matter how small, pays this startup cost. The Electron app wraps Virtualization.framework calls through JavaScript-to-native bridging, adding latency and fragility.

## Solution

Use **Apple's [Containerization](https://github.com/apple/containerization) Swift package** — a first-party framework (open source, macOS 26+) that provides VM-per-container with sub-second startup, OCI image support, and integrated networking. For lightweight work that doesn't need Linux tooling, use macOS-native sandboxing via XPC services.

### Two execution paths

The conversation engine decides which path to use based on what Claude needs to do:

**XPC path (lightweight)** — For operations that don't need a Linux environment: file operations (read, write, rename, organize), document analysis, text generation, web search. An XPC service in a sandboxed process with minimal entitlements. Startup is near-instant.

**Container path (full)** — For operations that need Linux tooling: running code (Python, Node, etc.), complex build steps, system commands. A Containerization-managed Linux VM with Claude Code and required runtimes pre-installed. Sub-second startup via optimized kernel.

The user never sees this decision. Claude says "Let me analyze those files" and the engine picks the right path. The conversation timeline shows the work happening — not which execution environment it's happening in.

### Why Containerization over raw Virtualization.framework

| Concern | Raw Virtualization.framework | Apple Containerization |
|---------|------------------------------|----------------------|
| VM lifecycle | Manual boot/pause/resume | Managed by the framework |
| Filesystem | Build ext4 rootfs yourself | ext4 included, OCI image support |
| Networking | Configure VZNetworkDevice manually | `container-network-vmnet` handles it |
| Kernel | Source and build your own | Optimized Linux kernel included, sub-second boot |
| Image management | Roll your own | OCI-compatible — pull from any container registry |
| Maintenance | All on us | Apple maintains the hard parts |

### Performance targets

| Metric | Current (Electron + VM) | Atelier | Improvement |
|--------|------------------------|---------|-------------|
| Container startup | 5–8s | <1s | ~90% faster |
| XPC task startup | 5–8s (always boots VM) | <0.1s | ~99% faster |
| IPC latency | ~10–50ms per call | <1ms (direct Swift) | ~95% less |
| Image updates | Manual VM image rebuild | `container pull` | Trivial |

## Implementation

### Phase 1 — XPC Service

- Sandboxed XPC service for file operations and document analysis
- Minimal entitlements: read/write access only to user-approved folders
- Communication via `NSXPCConnection` with Codable message types
- This is the first execution path — available as soon as M1 ships

### Phase 2 — Container Integration

- Import `Containerization` Swift package
- Build a minimal OCI image: Claude Code CLI + Node + Python + essential tools
- Container lifecycle management: start, pause, resume, destroy
- File sharing between host and container (see architecture/03-file-sharing.md)

### Phase 3 — Smart Routing

- The `ConversationEngine` decides which path to use based on tool requirements
- If Claude needs to run code → container. If it needs to read/write files → XPC.
- Transparent to the user — the conversation shows results, not infrastructure
- Automatic fallback: if XPC can't handle a request, escalate to container

### Phase 4 — Image Management

- OCI image pulled and cached on first use (not first launch — only when a container is actually needed)
- Background image updates — new versions pulled silently, applied on next container start
- Image size budget: <500MB base image, lazy-pull additional tooling on demand

## Dependencies

- architecture/01-application-shell.md (the app must exist before execution paths are added)
- architecture/03-file-sharing.md (containers need host filesystem access)
- security/01-network-isolation.md (containers need network policy)

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| macOS 26 minimum limits user base | macOS 26 is current; Containerization is Apple's direction |
| Containerization package is pre-1.0 | Pin version, test on updates, contribute upstream |
| OCI image size on first pull | Lazy-pull, background download, only when container is first needed |
| XPC path can't handle all tasks | Clear capability matrix, auto-escalate to container |

## Notes

M0 ships with no execution sandbox — just direct API calls. M1 adds both XPC and container paths. The key insight is that most user interactions (chat, file reading, document analysis, text generation) never need a container at all. The container is for power-user scenarios: running code, complex builds, system commands. Progressive disclosure applies to infrastructure too.

---

*Back to [Index](../../INDEX.md)*
