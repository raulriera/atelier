# Conversational Flow

> **Category:** Experience
> **Type:** 🆕 New Capability · **Priority:** 🟠 High

---

## Problem

Today, working with Claude means deciding upfront what kind of interaction you want — a chat, an autonomous task, or a terminal session. But real work doesn't fit in boxes. A question evolves into a task. A task needs a manual tweak. A debugging session needs an explanation.

"How should I refactor this auth module?" starts as a question. The answer involves code changes. You want Claude to just do it. Then you want to review the diff. Then you want to tweak something by hand. Three app switches for one thought.

## Solution

There are no modes. There's one conversation that adapts to what's happening.

### The conversation responds to intent

- You ask a question → Claude answers. Simple.
- You say "go ahead and do it" → Claude begins working. Progress appears inline in the conversation — file reads, changes, status updates. You don't switch to a different view.
- The work finishes → results, diffs, and outcomes appear in the same timeline. You review them right there.
- You want to tweak something manually → Claude can surface a terminal or editor inline if the project context supports it.
- You want to step back and think → just type your next message. You're always in the conversation.

### What makes this work

- **No explicit mode switching.** The conversation itself is the interface. It responds to what you're doing, not to which tab you clicked.
- **Inline rich content.** File cards, diffs, progress indicators, approval gates — they appear in the conversation timeline as needed, not in separate panels.
- **Background capability.** When Claude is working on something time-consuming, you see it begin in the timeline and can continue talking or switch to another window. Results appear when ready.
- **Progressive complexity.** A first-time user sees text messages. A power user working on code sees diffs, file cards, terminal output — all because the work demands it, not because they configured it.

## Implementation

### Phase 1 — Unified Conversation Model

- Single `Conversation` model that holds a heterogeneous list of timeline items (messages, file operations, task progress, diffs, approvals, results)
- No mode state. The conversation model doesn't know about "chat" vs "cowork" vs "code" — it knows about content types
- Shared rendering pipeline that handles all inline content types with consistent styling

### Phase 2 — Inline Content Types

- **Text message** — user and assistant messages, streaming support
- **File card** — compact representation of a file read/write, expandable to show content
- **Diff view** — syntax-highlighted, collapsible, with approve/reject actions
- **Progress indicator** — shows what Claude is doing, estimated time, cancellation
- **Approval gate** — inline request with context, one-click approve, Touch ID for high-risk
- **Result card** — summary of completed work with expandable details
- Each type must render fast — pre-computed layouts, minimal view recomputation

### Phase 3 — Background Work

- When Claude begins a long-running task, the conversation shows it started and continues to accept input
- Progress updates stream into the timeline without blocking interaction
- Completion triggers an inline result card and (optionally) a system notification
- Multiple background tasks can be active in the same conversation

## Dependencies

- experience/01-window-conversation.md (the conversation timeline)
- experience/02-project-workspace.md (shared project context)
- hub/01-claude-code-integration.md (terminal capability when needed)

## Notes

The magic is in making this feel natural rather than clever. The user should never think about modes — they should just talk and watch things happen. The risk is over-engineering the "intelligence" of when to show what. Start with clear, simple rules: if Claude is reading a file, show a card. If there's a diff, show a diff. Let the content drive the UI.

---

*Back to [Index](../../INDEX.md)*
