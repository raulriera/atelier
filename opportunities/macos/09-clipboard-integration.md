# Clipboard Integration

> **Category:** macOS Integration
> **Type:** 🆕 New Capability · **Priority:** 🟡 Medium
> **Milestone:** M5

---

## Current State (Electron / Cowork)

No clipboard awareness — cannot process clipboard contents or output to clipboard. Users must save content to a file, grant Cowork access to the folder, and then ask it to process the file. For quick operations on copied text or data, this is painfully slow.

## Native macOS Approach

**NSPasteboard monitoring**: "Process clipboard with Cowork" from the menu bar. Rich clipboard output — paste generated tables directly into Keynote/Numbers as native objects.

### Implementation Strategy

- **Clipboard input:** The menu bar agent includes a "Process Clipboard" action. It reads the current clipboard content (text, images, files, URLs) and creates a quick Cowork session with that content as input.
- **Rich clipboard output:** When Cowork generates structured data (tables, formatted text, images), it places rich `NSPasteboard` representations:
  - Tables → `NSPasteboardTypeTabularText` + HTML + plain text (paste into Numbers/Excel as a formatted table)
  - Formatted text → `NSAttributedString` (paste into Pages/Word with formatting preserved)
  - Images → `NSPasteboardTypeTIFF` + PNG (paste into Keynote/Preview)
- **Clipboard history:** Optional clipboard history integration — track the last N items processed through Cowork for quick re-access.
- **Global hotkey:** `⌘⇧V` (or configurable) to invoke "Process Clipboard" from any app — no need to open Cowork.

### Example User Flow

```
1. User copies a table of sales data from an email
2. Presses ⌘⇧V (global hotkey)
3. Menu bar popover appears: "What should I do with this table?"
4. User types: "Add a totals row and sort by revenue descending"
5. Processed table is placed on clipboard
6. User pastes (⌘V) into Numbers — arrives as a formatted table
```

### Key Dependencies

- `NSPasteboard` for clipboard read/write
- Rich pasteboard types (TabularText, AttributedString, TIFF)
- Global hotkey registration
- Menu bar popover UI

---

*Back to [Index](../../INDEX.md)*
