# File Sharing (Host ↔ VM)

> **Category:** Architecture & Performance
> **Type:** Improvement · **Priority:** 🟠 High
> **Milestone:** M1

---

## Current State (Electron / Cowork)

VirtioFS with path rewriting through Electron IPC — adds latency and translation errors. When a user grants folder access, the folder is mounted into the VM at `/sessions/<session-name>/mnt/`. The Electron app performs transparent path rewriting so users see familiar `~/Downloads/` paths rather than VM internals. This rewriting layer, passing through JavaScript IPC, introduces both latency and occasional path resolution bugs.

## Native macOS Approach

Apple's **Containerization** framework handles the low-level VirtioFS plumbing between host and container. On the host side, we use native macOS APIs — **Security-Scoped Bookmarks** for persistent folder access and **NSFileCoordinator** for safe concurrent access — to manage what gets shared and how.

### Implementation Strategy

- **Container volume mounts:** Use the Containerization package's volume/mount APIs to expose host directories to the container. The framework handles VirtioFS configuration internally.
- **Persistent access:** Store Security-Scoped Bookmarks (`NSURL.startAccessingSecurityScopedResource()`) for user-granted folders so access persists across launches without re-prompting.
- **Path mapping:** Maintain a Swift dictionary of `[ContainerPath: HostURL]` mappings. The UI always shows host paths; the container sees its own mount points.
- **File coordination:** Wrap all host-side file access in `NSFileCoordinator` to safely handle concurrent access from Finder, other apps, and the container simultaneously.
- **Change notification:** Monitor host-side changes via FSEvents and propagate to the container. Container-side changes are visible to the host through the shared mount.

### Estimated Impact

| Metric | Current | Native | Improvement |
|--------|---------|--------|-------------|
| Per-operation IPC overhead | ~10–50ms | <1ms | ~90% less |
| Path resolution errors | Occasional | Eliminated | 100% fix |
| Concurrent file safety | None | NSFileCoordinator | Safe by default |

### Key Dependencies

- [apple/containerization](https://github.com/apple/containerization) volume mount APIs
- Security-Scoped Bookmarks for persistent folder grants
- NSFileCoordinator for safe concurrent access

---

*Back to [Index](../../INDEX.md)*
