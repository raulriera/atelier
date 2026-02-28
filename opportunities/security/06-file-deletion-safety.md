# File Deletion Safety

> **Category:** Security & Privacy
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical

---

## Current State (Electron / Cowork)

Viral incident: 11GB of files permanently deleted — a "clean up" prompt caused irreversible data loss. Developer James McAulay demonstrated that asking Cowork to organize a directory resulted in permanent deletion of YouTube footage and LinkedIn assets. Other users reported similar experiences — files deleted while Claude claimed they were still present. The Linux VM uses `rm` which bypasses macOS Trash entirely.

## Native macOS Approach

**Never `rm -rf`.** All deletions go to macOS Trash via `NSFileManager.trashItem()`. Time Machine integration for backup verification before batch operations. Undo support via `NSUndoManager` for file operations.

### Implementation Strategy

- **Trash, never delete:** Override all file deletion commands in the VM with a host-side handler that uses `FileManager.default.trashItem(at:resultingItemURL:)`. Files go to macOS Trash where they can be recovered. The VM's `rm` command is intercepted and redirected.
- **Pre-operation snapshot:** Before any batch file operation (organize, clean up, rename), create an APFS snapshot of the affected directory tree. This is a zero-cost copy-on-write snapshot that enables complete rollback.
- **Time Machine check:** Before destructive operations, check if Time Machine is configured and has a recent backup of the affected files. If no recent backup exists, warn the user: "These files aren't backed up. Proceed anyway?"
- **Undo stack:** Implement `NSUndoManager` for file operations. Users can ⌘Z to undo the last file move, rename, or trash operation — just like undoing in any other Mac app.
- **Operation manifest:** Before executing any batch file operation, generate a manifest showing exactly what will happen to each file (move to X, rename to Y, trash Z). Require explicit approval for any operation affecting >10 files.
- **Recovery view:** A dedicated "File Operations History" view showing every file operation Cowork has performed, with status, timestamp, and a "Restore" button for any trashed or moved file.

### User Flow: Safe Cleanup

```
User: "Clean up my Downloads folder"

Before execution:
┌─────────────────────────────────────────┐
│  Proposed Operations (47 files)         │
│                                         │
│  📁 Move to ~/Documents/PDFs/:    12    │
│  📁 Move to ~/Pictures/:           8    │
│  📁 Move to ~/Documents/Misc/:    15    │
│  🗑️ Move to Trash (duplicates):    12   │
│                                         │
│  ⚠️  Time Machine backup: 2 hours ago   │
│  💾 APFS snapshot will be created       │
│                                         │
│  [Approve All] [Review Each] [Cancel]   │
└─────────────────────────────────────────┘

After execution:
- All "deleted" files are in Trash (recoverable)
- APFS snapshot created (full rollback possible)
- ⌘Z undoes the entire operation
```

### Estimated Impact

| Scenario | Current | Native |
|----------|---------|--------|
| Accidental deletion | Permanent, unrecoverable | Trash → one-click restore |
| Batch operation gone wrong | Re-download from source (if possible) | ⌘Z or APFS snapshot rollback |
| No backup + deletion | Data lost forever | Pre-check warns user first |

### Key Dependencies

- `FileManager.trashItem(at:resultingItemURL:)` for safe deletion
- APFS snapshot APIs (via `diskutil` or `fs_snapshot_create`)
- `NSUndoManager` for operation undo
- Time Machine backup status via `TMStatusCurrent` defaults domain

---

*Back to [Index](../../INDEX.md)*
