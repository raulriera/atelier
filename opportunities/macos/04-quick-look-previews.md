# Quick Look Previews

> **Category:** macOS Integration
> **Type:** 🆕 New Capability · **Priority:** 🟡 Low

---

## Current State (Electron / Cowork)

None — generated files require opening in external apps to preview. Users must leave Cowork, find the file in Finder, and open it in Excel/Word/Preview to see what was generated.

## Native macOS Approach

**QLPreviewPanel integration**: spacebar to preview any Cowork-generated document inline. Custom Quick Look generators for session summaries.

### Implementation Strategy

- Implement `QLPreviewPanelDataSource` and `QLPreviewPanelDelegate` so pressing spacebar on any output file in the session view opens a Quick Look preview.
- Build a custom Quick Look generator (`.qlgenerator` / `QLPreviewingController`) for Cowork session files — showing task summary, inputs, outputs, and token usage in a formatted preview.
- Embed `QLPreviewView` directly in the session detail view for always-visible output previews without needing a separate panel.

### Key Dependencies

- Quick Look framework (`QLPreviewPanel`, `QLPreviewView`)
- Custom QLPreviewingController for session files

---

*Back to [Index](../../INDEX.md)*
