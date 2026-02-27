# File Sharing (Host ↔ VM)

> **Category:** Architecture & Performance
> **Type:** Improvement · **Priority:** 🟠 High

---

## Current State (Electron / Cowork)

VirtioFS with path rewriting through Electron IPC — adds latency and translation errors. When a user grants folder access, the folder is mounted into the VM at `/sessions/<session-name>/mnt/`. The Electron app performs transparent path rewriting so users see familiar `~/Downloads/` paths rather than VM internals. This rewriting layer, passing through JavaScript IPC, introduces both latency and occasional path resolution bugs.

## Native macOS Approach

VirtioFS called directly via **Virtualization.framework Swift APIs** — eliminates the Electron IPC hop, provides lower latency, and enables native path handling via `NSURL` and `FileManager`.

### Implementation Strategy

- **Direct VirtioFS:** Configure `VZVirtioFileSystemDeviceConfiguration` with `VZSharedDirectory` directly in Swift. No JavaScript bridge means one fewer serialization/deserialization step per file operation.
- **Path mapping:** Maintain a Swift dictionary of `[VMPath: HostURL]` mappings using Security-Scoped Bookmarks for persistent access across sessions. Use `NSURL.startAccessingSecurityScopedResource()` for sandboxed access.
- **File coordination:** Wrap all host-side file access in `NSFileCoordinator` to safely handle concurrent access from Finder, other apps, and the VM simultaneously.
- **Change notification:** Use `VZVirtioFileSystemDeviceConfiguration` share change notifications to reflect VM-side modifications in the native UI immediately.

### Estimated Impact

| Metric | Current | Native | Improvement |
|--------|---------|--------|-------------|
| Per-operation IPC overhead | ~10–50ms | <1ms | ~90% less |
| Path resolution errors | Occasional | Eliminated | 100% fix |
| Concurrent file safety | None | NSFileCoordinator | Safe by default |

### Key Dependencies

- Virtualization.framework `VZSharedDirectory` APIs
- Security-Scoped Bookmarks for persistent folder grants
- NSFileCoordinator for safe concurrent access

---

*Back to [Index](../../INDEX.md)*
