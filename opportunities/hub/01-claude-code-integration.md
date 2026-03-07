# Claude Code Integration

> **Category:** Hub / Unified Experience
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical
> **Milestone:** M3

---

## Current State (Electron / Cowork)

Claude Code is a completely separate CLI tool with no connection to Cowork. Users must context-switch entirely between the two — different apps, different interfaces, no shared context, no shared session history. Despite the fact that Cowork internally runs Claude Code in the VM, there is no user-facing bridge between them.

## Native macOS Approach

Claude Code runs inside the same container that powers the conversation. When terminal interaction is needed, it surfaces inline in the conversation timeline — not as a separate mode or tab, but as another content type in the flow.

### How it works

- **Claude Code is the engine.** Behind the scenes, the conversation timeline is powered by Claude Code running in the container. When Claude reads files, writes code, or runs commands — that's Claude Code doing the work.
- **Terminal surfaces when needed.** If the user or Claude needs interactive terminal access, a terminal view can appear inline in the conversation or as a split pane. It's the same Claude Code session — same context, same file access.
- **No mode switching.** The user doesn't "switch to Code mode." They might say "let me see the terminal" or Claude might surface terminal output when it's relevant. It's progressive disclosure — the terminal is there when you need it, invisible when you don't.
- **Shared context.** The terminal session inherits everything from the conversation: granted folder access, conversation history, context files, current task state.

### Architecture

```
┌──────────────────────────────────────────┐
│  Atelier Window                          │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │  Conversation Timeline             │  │
│  │                                    │  │
│  │  💬 User message                   │  │
│  │  📄 File card (Claude read a file) │  │
│  │  📝 Diff (Claude made changes)     │  │
│  │  ▶ Terminal output (inline)        │  │
│  │  ✅ Result card                    │  │
│  │                                    │  │
│  └────────────────────────────────────┘  │
│                 │                         │
│  ┌──────────────▼─────────────────────┐  │
│  │  Container (OCI + Claude Code)     │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

### Estimated Impact

| Scenario | Current | Atelier |
|----------|---------|---------|
| CLI precision work during a task | Quit Cowork, open terminal, re-auth, re-explain context | Terminal surfaces inline, full context preserved |
| Share results between conversation and CLI | Manually copy files | Automatic — same session, same container |
| Learn CLI from GUI | Completely separate tool, intimidating | Gradual exposure as terminal output appears in the conversation |

### Key Dependencies

- SwiftTerm or custom PTY terminal emulator
- Shared session state management between conversation UI and Claude Code process
- Container context bridging

---

*Back to [Index](../../INDEX.md)*
