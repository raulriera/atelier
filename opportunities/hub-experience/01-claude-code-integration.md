# Claude Code Integration

> **Category:** Hub / Unified Experience
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical

---

## Current State (Electron / Cowork)

Claude Code is a completely separate CLI tool with no connection to Cowork. Users must context-switch entirely between the two — different apps, different interfaces, no shared context, no shared session history. Despite the fact that Cowork internally runs Claude Code in the VM, there is no user-facing bridge between them.

## Native macOS Approach

**Embedded terminal view** (via SwiftTerm or custom PTY) running Claude Code directly within the Atelier. Shared session context: start a task in the Cowork GUI, drop to Code CLI for precision work, results flow back seamlessly.

### Implementation Strategy

- **Embedded terminal:** Integrate SwiftTerm (open-source Swift terminal emulator) or build a custom PTY-based terminal view. Claude Code runs directly in this view — same CLI, same capabilities, same commands.
- **Unified session context:** When a user starts a Cowork GUI task and needs more precision, they can "drop to terminal" within the same session. The Claude Code instance inherits:
  - All granted folder access
  - The active conversation history
  - Any `COWORK.md` context files
  - Current task state
- **Bidirectional handoff:** Results from Claude Code (files created, code executed) automatically appear in the Cowork GUI output panel. Conversely, clicking "refine in Code" on any Cowork output opens a Code session with that output as context.
- **Split view:** Support a split-pane view: Cowork GUI on the left, Claude Code terminal on the right. Both operating in the same session, sharing the same VM.
- **Hub navigation:** A sidebar or tab bar provides one-click switching between Chat, Cowork, and Code — all within the same native window, all sharing context.

### Architecture

```
┌─────────────────────────────────────────────┐
│  Atelier                          │
│                                             │
│  ┌─────┐ ┌────────┐ ┌──────┐               │
│  │Chat │ │Cowork  │ │Code  │  ← Tab bar    │
│  └──┬──┘ └───┬────┘ └──┬───┘               │
│     │        │         │                    │
│     ▼        ▼         ▼                    │
│  ┌─────────────────────────────────────┐    │
│  │  Shared Session Context             │    │
│  │  - Conversation history             │    │
│  │  - Granted folder access            │    │
│  │  - COWORK.md files                  │    │
│  │  - Task state                       │    │
│  └──────────────┬──────────────────────┘    │
│                 │                            │
│  ┌──────────────▼──────────────────────┐    │
│  │  Shared VM (Ubuntu + Claude Code)   │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

### Estimated Impact

| Scenario | Current | Hub |
|----------|---------|-----|
| Switch from GUI to CLI for precision | Quit Cowork, open terminal, re-auth, re-explain context | Click "Code" tab, full context preserved |
| Share results between modes | Manually copy files | Automatic — same session |
| Learn Code from Cowork | Completely separate tool, intimidating | Gradual exposure within familiar app |

### Key Dependencies

- SwiftTerm or custom PTY terminal emulator
- Shared session state management
- VM context bridging between GUI and CLI modes

---

*Back to [Index](../../INDEX.md)*
