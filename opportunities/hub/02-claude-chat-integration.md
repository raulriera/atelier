# Claude Chat Integration

> **Category:** Hub / Unified Experience
> **Type:** 🆕 New Capability · **Priority:** 🟠 High

---

## Current State (Electron / Cowork)

Chat and Cowork are separate tabs in the same Electron app — no shared context or handoff. Starting a Cowork task from a chat conversation requires re-explaining everything. Chat doesn't know what Cowork has done, and Cowork doesn't know what was discussed in chat.

## Native macOS Approach

There is no separate "chat" — the conversation *is* the interface. Talking, asking questions, handing off tasks, reviewing results — it all happens in the same timeline. Claude's chat capabilities are the foundation of every interaction.

### Implementation Strategy

- **Conversation is everything.** There is no "chat mode" vs "task mode." You type a message and Claude responds. If the response involves work (reading files, making changes, running commands), that work appears inline. If it's a simple answer, it's just text.
- **Inline task execution.** When Claude needs to do something — organize files, generate a report, refactor code — it starts working and shows progress in the conversation. No "promotion" step needed.
- **Shared context.** The entire conversation history is context for every interaction. Claude remembers what was discussed earlier when executing work later. One continuous thread.
- **Background work.** Long-running tasks show their start in the conversation, then the user can keep talking or switch to another window. Results appear in the timeline when ready.

### Key Dependencies

- Unified conversation data model (SwiftData)
- Streaming message rendering with rich inline content types
- Background task execution with inline progress

---

*Back to [Index](../../INDEX.md)*
