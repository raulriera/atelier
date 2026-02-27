# Drag & Drop

> **Category:** macOS Integration
> **Type:** 🆕 New Capability · **Priority:** 🟡 Medium

---

## Current State (Electron / Cowork)

Basic file drag into the Electron window — no rich preview during drag, no ability to drag generated files *out* of Cowork into Finder or other apps.

## Native macOS Approach

Full `NSItemProvider` / `NSDraggingSource` support: drag files out of Cowork into Finder, Mail, or any app. Rich previews via Quick Look thumbnails during drag.

### Implementation Strategy

- **Drag out:** Implement `NSDraggingSource` on file result cards. Users can drag a generated report directly from the Cowork session into a Mail compose window, Finder folder, or Slack message.
- **Drag in:** Accept drops of files, folders, text, URLs, and images via `onDrop` in SwiftUI or `NSDraggingDestination`. Dropped items become task context.
- **Rich previews:** During drag, show a Quick Look thumbnail of the file via `QLThumbnailGenerator` — users see a preview of the actual document, not just a generic file icon.
- **Multi-item drag:** Support dragging multiple output files at once for batch operations.

### Key Dependencies

- `NSItemProvider`, `NSDraggingSource`, `NSDraggingDestination`
- `QLThumbnailGenerator` for drag previews
- SwiftUI `onDrag` / `onDrop` modifiers

---

*Back to [Index](../../INDEX.md)*
