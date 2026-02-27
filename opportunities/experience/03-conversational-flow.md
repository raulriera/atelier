# Conversational Flow

## Type
🆕 New

## Priority
🟠 High

---

## Problem

The three modes of working with Claude (chat, autonomous task, terminal) are currently three different products with three different interaction models. Users have to decide upfront which mode they need, even though real work often starts as a question and evolves into a task.

"How should I refactor this auth module?" starts as chat. The answer involves code changes. You want Claude to just do it. Now you need Cowork. Then you want to review the diff and tweak something manually. Now you need Code. Three app switches for one thought.

## Solution

Fluid escalation and de-escalation between modes, all within the same conversation thread:

### Chat → Cowork (Escalation)
- Typing a message that implies a task (e.g., "Go ahead and refactor it") surfaces a **"Run as Task"** affordance
- One click promotes the conversation to a Cowork session, carrying full chat context
- The task runs in the background; results appear inline when done

### Cowork → Code (Drop to terminal)
- During or after a Cowork task, a **"Open in Terminal"** button drops you into a Claude Code session in the same project directory
- The terminal session has access to the Cowork task's context and file changes
- Terminal output can be referenced back in the Cowork conversation

### Code → Chat (De-escalation)
- From Code mode, a **"Discuss"** action opens a chat thread about the current terminal context
- Useful for "explain what just happened" or "what should I do next?" without leaving the project

### All transitions preserve:
- Project context (COWORK.md, folder access, settings)
- Conversation history (the full thread is one continuous timeline)
- File state (changes made in one mode are visible in others)

## Implementation

### Phase 1 — Unified Conversation Model
- Single `Conversation` model that spans modes, with segments tagged by mode (chat/cowork/code)
- Mode transitions are events in the conversation timeline, not new conversations
- Shared message rendering that handles text, diffs, terminal output, and task status

### Phase 2 — Escalation UI
- NLP-based hint detection for "Run as Task" suggestion (or explicit button)
- Inline task progress within the chat thread (collapsible detail)
- "Open in Terminal" button on Cowork file changes

### Phase 3 — Cross-Mode References
- @-mention files, sessions, or previous messages from any mode
- "Pin" a terminal output to the conversation for later reference

## Dependencies

- experience/01-hub-navigation.md (mode switching infrastructure)
- experience/02-project-workspace.md (shared project context)
- hub/01-claude-code-integration.md (terminal embedding)

## Notes

This is the most ambitious UX challenge in Atelier. The risk is making it feel magical when it works but confusing when it doesn't. Start with explicit buttons for mode transitions; add intelligent suggestions later.
