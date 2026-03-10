# Drag & Drop

> **Category:** macOS Integration
> **Type:** 🆕 New Capability · **Priority:** 🟡 Medium
> **Milestone:** M5

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

## Shipped: Drag-In File Attachments (Phase 1)

### What shipped

Users can drag files from Finder (or any app) into the conversation window. Dropped files become attachments sent alongside the user's message, with auto-approved `Read` access so Claude can read them without an approval prompt.

### Components

| File | Role |
|------|------|
| `FileAttachment` | Model: URL, filename, kind classification via UTType |
| `DropPathValidator` | Security: rejects non-file URLs and sensitive paths (credentials, keychains) |
| `AttachmentThumbnailView` | QuickLook thumbnail with system icon fallback |
| `ComposeAttachmentStrip` | Horizontal strip above compose field, glass-backed cards with dismiss buttons |
| `UserMessageAttachmentsView` | "Paper pile" ZStack layout in the conversation timeline |
| `UserMessageCell` | Attachment-only messages render without a speech bubble |
| `ConversationController` | Builds CLI message with file paths, accumulates `allowedReadPaths` per session |
| `CLIEngine.buildArguments` | Emits `--allowedTools Read(//path)` for each attachment path |
| `ConversationEngine` | Protocol updated with `allowedReadPaths` parameter |
| `Session.appendUserMessage` | Accepts optional attachments for timeline items |
| `UserMessage` | Codable with backwards-compatible `attachments` field |

### Design decisions

- **Max 5 attachments per drop** — enforced by `FileAttachment.maxAttachments`
- **Sensitive path filtering** — `DropPathValidator` reuses `CLIEngine.sensitiveRelativePaths` and `sensitiveGlobalPatterns` to reject credentials, keychains, etc.
- **Auto-approve Read** — attachment paths passed as `--allowedTools Read(//path)` with double-slash prefix for absolute filesystem paths (single `/` is project-relative in CLI's gitignore-style rules)
- **Paths accumulate per session** — `allowedAttachmentPaths` in `ConversationController` grows across messages, cleared on new conversation
- **Attachment-only messages** — rendered as a separate timeline item (no bubble), text follows as a second item, matching iMessage's photo-then-caption pattern
- **Glass-backed thumbnails** — each card in the compose strip uses `.glassEffect()` with a `GlassEffectContainer`; dismiss buttons also use `.glassEffect(.interactive(), in: .circle)` to render above the glass compositing layer

### What's next (Phase 2)

- **Drag out:** Implement `NSDraggingSource` on file result cards for dragging generated files to Finder, Mail, etc.
- **Folder drops:** Accept dropped folders and expand to file listing
- **Image inline preview:** Show full-resolution image previews in the timeline instead of thumbnails

---

*Back to [Index](../../INDEX.md)*
