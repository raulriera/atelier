# Memory Management

> **Category:** Architecture & Performance
> **Type:** Improvement · **Priority:** 🟠 High

---

## Current State (Electron / Cowork)

Electron + Chromium + VM stack creates severe memory pressure, especially on 8GB Macs. The Chromium renderer alone consumes 300–500MB, plus the Linux VM allocates a fixed 3.8GB. On a base-model MacBook Air with 8GB of unified memory, this leaves almost nothing for other apps, causing swapping, UI stutter, and fan noise.

## Native macOS Approach

Atelier footprint is minimal (~80–120MB). Use Virtualization.framework's **memory balloon driver** for dynamic VM memory allocation that scales with actual task needs rather than fixed pre-allocation.

### Implementation Strategy

- **Atelier memory:** SwiftUI views are lightweight. The app shell consumes ~50MB; add ~30–70MB for conversation history, cached assets, and session state.
- **VM memory ballooning:** Configure `VZVirtioTraditionalMemoryBalloonDeviceConfiguration` to dynamically inflate/deflate VM memory. Start with 1GB for simple tasks, scale to 4GB for heavy Python/Node workloads.
- **Memory pressure monitoring:** Use `DispatchSource.makeMemoryPressureSource()` to detect system memory warnings. Automatically balloon down the VM, pause background sessions, or suggest the user close other apps.
- **Conversation history:** Use memory-mapped files (`mmap` via `Data(contentsOf:options: .mappedIfSafe)`) for large conversation histories instead of loading everything into heap memory.
- **Cache management:** `NSCache` with cost limits for generated file previews and thumbnails. Automatic eviction under memory pressure.

### Estimated Impact

| Scenario | Current (Electron + VM) | Native |
|----------|------------------------|--------|
| App idle (no task) | ~500MB (Electron alone) | ~80MB |
| Light task running | ~4.3GB (Electron + VM fixed) | ~1.1GB (app + ballooned VM) |
| Heavy task running | ~4.3GB (same, no scaling) | ~4.1GB (app + expanded VM) |
| 8GB Mac headroom | ~3.7GB for everything else | ~6.9GB idle / ~3.9GB heavy |

### Key Dependencies

- `VZVirtioTraditionalMemoryBalloonDeviceConfiguration`
- `DispatchSource.makeMemoryPressureSource`
- Memory-mapped file I/O

---

*Back to [Index](../../INDEX.md)*
