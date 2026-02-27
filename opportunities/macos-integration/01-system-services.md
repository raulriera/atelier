# System Services

> **Category:** macOS Integration
> **Type:** 🆕 New Capability · **Priority:** 🟠 High

---

## Current State (Electron / Cowork)

None — Electron apps cannot register as macOS Services. Users must manually copy text, switch to Claude, paste, get a result, copy it back, and switch to the original app.

## Native macOS Approach

Register as a **macOS Service**: select text in any app → right-click → "Process with Cowork." Implemented via `NSServicesProvider`.

### Implementation Strategy

- **Service registration:** Declare services in `Info.plist` under `NSServices`. Register handlers via `NSApp.servicesProvider`:
  - "Summarize with Claude" — returns a summary of selected text
  - "Rewrite with Claude" — rewrites selected text (replaces in-place)
  - "Analyze with Claude" — opens a Cowork session with the selected text as context
  - "Translate with Claude" — translates selected text
- **In-place replacement:** For services that return text (rewrite, translate), the result replaces the selection in the source app — no context switching needed.
- **Keyboard shortcuts:** Users can assign global keyboard shortcuts to each service via System Settings → Keyboard → Keyboard Shortcuts → Services.
- **Rich content:** Services can accept `NSAttributedString` and `NSFilenamesPboardType` — handle both text and file selections.

### Example User Flow

```
1. User selects 3 paragraphs in TextEdit
2. Right-click → Services → "Rewrite with Claude"
3. Claude processes (small spinner in menu bar)
4. Rewritten text replaces selection in TextEdit
5. Total time: ~3 seconds, zero context switches
```

### Key Dependencies

- `NSServicesProvider` protocol
- `Info.plist` NSServices declarations
- `NSPasteboard` for content exchange

---

*Back to [Index](../../INDEX.md)*
