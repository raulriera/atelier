# Document Generation

> **Category:** macOS Integration
> **Type:** Improvement · **Priority:** 🟡 Medium

---

## Current State (Electron / Cowork)

Creates Excel, PowerPoint, Word, and PDF files inside the VM — outputs deposited in mounted folders. The generation itself works well since it uses the full Linux toolchain (Python, Node.js, LibreOffice). However, there's no native preview of outputs, no version history, and no Finder integration for generated files.

## Native macOS Approach

Same generation capability in the VM, plus native **Quick Look previews**, **Finder tags** on outputs, and direct "Open With…" from Atelier. **Version history** via APFS snapshots or document versioning.

### Implementation Strategy

- **Inline preview:** After document generation, immediately show a Quick Look preview (`QLPreviewView`) of the output within the Cowork session. No need to open Finder or the target app.
- **Finder tags:** Automatically apply Finder tags to generated files: color tags for status (green = final, orange = draft), custom tags for project name and generation date. Applied via `NSURL.setResourceValues()`.
- **Open With… integration:** A native "Open With…" button using `NSWorkspace.open(_:configuration:)` lets users immediately open the generated file in their preferred app (Excel, Pages, Preview, etc.).
- **Version history:** Use `NSFileVersion` to create versions of output files. Users can compare current vs. previous generations and roll back if the new version is worse.
- **APFS clones:** When modifying existing user files, create an APFS clone first (zero-cost copy-on-write) as an automatic backup. The clone is invisible to the user but available for recovery.
- **Template management:** A native template picker for document generation — users choose from their own templates or built-in options before the agent starts work.

### Key Dependencies

- `QLPreviewView` for inline previews
- `NSURL` resource values for Finder tags
- `NSFileVersion` for version history
- APFS clone operations

---

*Back to [Index](../../INDEX.md)*
