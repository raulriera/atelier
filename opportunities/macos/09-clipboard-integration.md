# Clipboard Integration

> **Category:** macOS Integration
> **Type:** New Capability · **Priority:** Medium
> **Milestone:** M5 · **Status:** 🔲 Not started

---

## Problem

No clipboard awareness — processing copied text or data requires saving to a file first, granting folder access, then asking Claude to process it. Painfully slow for quick operations.

## Solution

**NSPasteboard** integration: "Process Clipboard" from the menu bar agent, plus rich clipboard output — paste generated tables directly into Numbers/Keynote as native objects.

### How it works

```
1. Copy a table of sales data from an email
2. Press ⌘⇧V (global hotkey)
3. Menu bar popover: "What should I do with this table?"
4. "Add a totals row and sort by revenue descending"
5. Processed table placed on clipboard
6. Paste into Numbers — arrives as a formatted table
```

- **Rich output** — tables paste as `NSPasteboardTypeTabularText`, formatted text as `NSAttributedString`, images as TIFF/PNG
- **Global hotkey** — invoke from any app without opening Atelier

---

*Back to [Index](../../INDEX.md)*
