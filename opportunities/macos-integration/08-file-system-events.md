# File System Events & Folder Watching

> **Category:** macOS Integration
> **Type:** 🆕 New Capability · **Priority:** 🟠 High

---

## Current State (Electron / Cowork)

No file watching — users must manually re-trigger tasks every time. There is no way to set up Cowork to automatically react when new files appear in a folder.

## Native macOS Approach

**FSEvents / DispatchSource** for real-time folder monitoring. Auto-trigger workflows when files appear in watched folders (e.g., auto-process new invoices dropped into Downloads).

### Implementation Strategy

- **Folder watches:** Users designate "watched folders" in settings. The app uses `FSEvents` (or `DispatchSource.makeFileSystemObjectSource` for individual files) to monitor for changes.
- **Trigger rules:** Each watched folder can have rules: "When a PDF appears → run the Invoice Processing workflow" or "When CSV files are modified → regenerate the summary report."
- **Debouncing:** Wait 2–3 seconds after file changes stabilize before triggering (handles apps that write in chunks).
- **Filter by type:** Only trigger on specific file extensions, filename patterns, or Finder tags.
- **Integration with workflows:** Watched folder events feed directly into the Task Templates system — combining folder watching with saved workflows enables fully automated pipelines.
- **Status in menu bar:** Show watched folder status in the menu bar agent — active watches, recent triggers, and any errors.

### Example: Auto-Process Invoices

```
Watched folder: ~/Downloads/
Rule: When *.pdf appears matching "invoice*"
  │
  ├─ Move to ~/Documents/Invoices/2026-02/
  ├─ Extract vendor, amount, date, line items
  ├─ Append row to ~/Finances/invoice-tracker.xlsx
  ├─ If amount > $5,000: notify for approval
  └─ Tag file in Finder with "Processed" (green)
```

### Key Dependencies

- `FSEvents` API or `DispatchSource.makeFileSystemObjectSource`
- Integration with Task Templates/Workflows system
- Finder tag manipulation via `NSURL.setResourceValues`

---

*Back to [Index](../../INDEX.md)*
