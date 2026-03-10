# File System Events & Folder Watching

> **Category:** macOS Integration
> **Type:** New Capability · **Priority:** High
> **Milestone:** M5 · **Status:** 🔲 Not started

---

## Problem

No file watching — users must manually re-trigger tasks. There is no way to set up Atelier to automatically react when files change or appear in a folder.

## Solution

**FSEvents** for real-time folder monitoring. Users designate watched folders with trigger rules, enabling fully automated pipelines:

```
Watched folder: ~/Downloads/
Rule: When *.pdf appears matching "invoice*"
  ├─ Move to ~/Documents/Invoices/2026-02/
  ├─ Extract vendor, amount, date, line items
  ├─ Append row to ~/Finances/invoice-tracker.xlsx
  └─ Tag file in Finder with "Processed" (green)
```

- **Trigger rules** — filter by file type, name pattern, or Finder tags
- **Debouncing** — waits for file writes to stabilize before triggering
- **Integration** — feeds directly into saved workflows and task templates
- **Menu bar status** — active watches, recent triggers, and errors visible at a glance

---

*Back to [Index](../../INDEX.md)*
