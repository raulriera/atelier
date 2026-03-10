# Drag & Drop

> **Category:** macOS Integration
> **Type:** New Capability · **Priority:** Medium
> **Milestone:** M5 · **Status:** 🔨 In progress

---

## Problem

Electron's drag-and-drop is basic: files go in, nothing comes out. No rich previews, no ability to drag generated files out of the app into Finder or other apps.

## Solution

Full native drag support in both directions via `NSItemProvider` / `NSDraggingSource`:

- **Drag in:** Files, folders, text, URLs, and images dropped into conversations become context
- **Drag out:** Generated files can be dragged from result cards directly into Finder, Mail, or any app
- **Rich previews:** Quick Look thumbnails during drag — users see the actual document, not a generic icon
- **Multi-item:** Support dragging multiple output files at once

## Status

| Feature | Status |
|---------|--------|
| Drag-in file attachments (Phase 1) | ✅ Shipped |
| Security: sensitive path filtering on drop | ✅ Shipped |
| Auto-approve Read for attached files | ✅ Shipped |
| QuickLook thumbnails in compose strip | ✅ Shipped |
| Attachment-only messages in timeline | ✅ Shipped |
| Drag-out from result cards | 🔲 Not started |
| Folder drop → file listing expansion | 🔲 Not started |
| Inline image preview in timeline | 🔲 Not started |

---

*Back to [Index](../../INDEX.md)*
