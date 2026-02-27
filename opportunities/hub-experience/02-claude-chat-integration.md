# Claude Chat Integration

> **Category:** Hub / Unified Experience
> **Type:** 🆕 New Capability · **Priority:** 🟠 High

---

## Current State (Electron / Cowork)

Chat and Cowork are separate tabs in the same Electron app — no shared context or handoff. Starting a Cowork task from a chat conversation requires re-explaining everything. Chat doesn't know what Cowork has done, and Cowork doesn't know what was discussed in chat.

## Native macOS Approach

**Unified conversation model**: start chatting, then "promote" a conversation to a Cowork task with full conversation context preserved. Shared memory and project context across modes.

### Implementation Strategy

- **Conversation promotion:** A "Run as Task" button in any chat message converts the conversation into a Cowork session. All prior messages become task context — no re-explaining.
- **Task results in chat:** When a Cowork task completes, results can be "demoted" back to chat for discussion: "Here's the report I generated — what do you think about the Q3 projections?"
- **Shared memory:** User preferences, project context, and conversation memory persist across Chat, Cowork, and Code modes. Claude remembers what was discussed in chat when executing a Cowork task.
- **Inline task execution:** For simple tasks that don't need full Cowork orchestration, execute them inline within the chat: "Organize my Downloads folder" → runs in the background, result appears as a chat message.
- **Context panel:** A collapsible side panel in chat showing active Cowork sessions, recent outputs, and Code session status — always aware of what's happening across modes.

### Key Dependencies

- Unified conversation data model (CoreData or SwiftData)
- Session context serialization for cross-mode handoff
- Background task execution for inline chat tasks

---

*Back to [Index](../../INDEX.md)*
