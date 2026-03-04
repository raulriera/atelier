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

### Phase 1 — Unified Conversation Model ✅

- ✅ `TimelineItem` holds heterogeneous `TimelineContent` (user, assistant, system)
- ✅ No mode state — `Session` is the single model, UI responds to content types
- ✅ `TimelineView` renders all content types with consistent styling via `@ViewBuilder` switch
- ✅ All models are `Sendable` + `Codable` for persistence and thread safety

### Phase 2 — Inline Content Types 🔨

- ✅ **Text message** — user (tinted bubble) and assistant (plain bubble), real-time streaming with `activeAssistantText`
- ✅ **Markdown rendering** — paragraphs, headings, code blocks (with copy button), lists, tables, blockquotes, thematic breaks, inline markup (bold, italic, code, links, strikethrough)
- ✅ **Streaming indicator** — animated dots while waiting for text
- ✅ **Thinking indicator** — brain icon + pulsing animation during extended thinking
- ✅ **Token usage** — displayed below completed assistant messages
- ✅ **System events** — error and session-started events rendered inline
- ✅ **Tool use cards** — inline cards for each tool invocation (Read, Write, Edit, Bash, etc.) with input summary, status, and result preview
- ✅ **Inspector sidebar** — right-side panel (`.inspector()`) showing full tool output, togglable via toolbar, compresses content in-place
- ✅ **Scrolling performance** — visible items window + cached properties for efficient timeline rendering
- ✅ **File card** — compact representation of a file read/write, expandable to show content
- ✅ **Diff view** — track-changes view in inspector for Edit operations (strikethrough removed, highlighted added)
- 🔲 **Todo list** — parse `TaskCreate`/`TaskUpdate` tool events and render as an inline task list with status icons (pending, in-progress, completed) instead of generic tool cards. Claude uses these during multi-step plans.
- 🔲 **Ask user card** — `AskUserQuestion` tool calls need interactive rendering: show the question, options as clickable buttons, and send the selection back to the CLI. Requires a response channel (MCP-based, like approvals). Currently the CLI handles this via terminal stdin, which Atelier can't reach.
- 🔲 **Plan review** — `EnterPlanMode` / `ExitPlanMode` tool calls. Claude writes a plan file and asks for approval before implementing. Render the plan as a reviewable card with approve/reject actions. Same MCP response channel as ask user and approvals.
- 🔲 **Progress indicator** — shows what Claude is doing, estimated time, cancellation
- ✅ **Approval gate** — inline approval cards with approve/deny, compact resolved state, wired through MCP
- 🔲 **Result card** — summary of completed work with expandable details (blocked on M3 — hub/01-claude-code-integration.md)
- Each type must render fast — pre-computed layouts, minimal view recomputation

### Phase 3 — Background Work 🔨

- ✅ Non-blocking compose: user can type and queue messages while Claude streams
- ✅ Queued messages appear as normal user bubbles immediately, dispatched after current response completes
- ✅ Dock icon bounce + red badge when response completes while app is not focused; badge clears on window focus
- 🔲 Multiple concurrent background tasks (deferred to M3 — requires multi-subprocess support)

## Why there's no "Chat Integration"

Cowork treats Chat and Tasks as separate tabs with no shared context or handoff. Starting a task from a chat requires re-explaining everything. This is a design failure, not a feature gap.

In Atelier, the conversation *is* the interface. There is no "chat mode" vs. "task mode." You type a message and Claude responds. If the response involves work (reading files, making changes, running commands), that work appears inline. If it's a simple answer, it's just text. The entire conversation history is context for every interaction — one continuous thread. This makes a separate "chat integration" opportunity unnecessary.

## Dependencies

- experience/01-window-conversation.md (the conversation timeline)
- experience/02-project-workspace.md (shared project context)
- hub/01-claude-code-integration.md (terminal capability when needed)

## Notes

The magic is in making this feel natural rather than clever. The user should never think about modes — they should just talk and watch things happen. The risk is over-engineering the "intelligence" of when to show what. Start with clear, simple rules: if Claude is reading a file, show a card. If there's a diff, show a diff. Let the content drive the UI.

---

*Back to [Index](../../INDEX.md)*
