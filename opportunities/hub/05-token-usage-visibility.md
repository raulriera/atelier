# Token Usage Visibility

> **Category:** Hub / Unified Experience
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical
> **Milestone:** M3

---

## Problem

Opaque — users report burning through API allocations without warning. There is no real-time usage meter, no per-conversation cost breakdown, no spending alerts, and no way to estimate cost before sending a message. This is consistently one of the top user complaints.

## Solution

Token usage is visible when you want it, invisible when you don't. Progressive disclosure: a subtle indicator during conversations, detailed breakdowns in the inspector panel for those who care.

### What users see

**During a conversation** — a compact token count appears at the end of each assistant message. Small, muted, unobtrusive. Like a word count in a writing app — there if you glance at it, easy to ignore.

**In the inspector panel** (`⌘I`) — a detailed view:
- Tokens used this session (input / output breakdown)
- Estimated cost for the current session
- Tokens used this billing period with a progress bar
- Remaining budget at current usage rate

**Pre-send estimates** — before sending a long message or one with large file attachments, a subtle hint: "This message is ~12,000 tokens." No modal, no gate — just information.

**Budget alerts** — configurable thresholds via notifications: "You've used 75% of your monthly budget." Delivered via `UNUserNotificationCenter`, not blocking.

### What it looks like

```
┌─────────────────────────────────────┐
│  Claude's response text here...     │
│                                     │
│  ─── 847 tokens · ~$0.003 ───      │
└─────────────────────────────────────┘
```

In the inspector panel:

```
┌─────────────────────────────┐
│  Session Usage              │
│  In: 4,200  Out: 2,100     │
│  ~$0.02 this session        │
│                             │
│  Monthly                    │
│  ████████░░░░░░░  52%       │
│  ~$12.40 of $25 budget      │
│  Est. 11 days remaining     │
└─────────────────────────────┘
```

### What it doesn't look like

No "estimate panel" that gates every message. No "Run Task" button. No "Adjust Settings" before you can talk. The user types, Claude responds, and cost information is available without interrupting the flow.

## Implementation

### Phase 1 — Per-Message Token Count

- Parse `usage` from Anthropic API response (`input_tokens`, `output_tokens`)
- Store in `AssistantMessage.inputTokens` / `AssistantMessage.outputTokens` (already in data model)
- Render as a subtle footer on each assistant message cell
- Toggle visibility in settings (default: on but muted)

### Phase 2 — Session Aggregation

- Sum tokens across all messages in the current session
- Calculate estimated cost based on current Anthropic pricing
- Display in inspector panel when open

### Phase 3 — Budget Tracking

- Store monthly usage in `~/.atelier/config.json` (reset on billing cycle)
- Configurable budget amount and alert thresholds (50%, 75%, 90%)
- Native notifications via `UNUserNotificationCenter`
- Optional hard limit: "Warn me before sending if remaining budget < X%"

### Phase 4 — Historical Usage

- Swift Charts visualization of daily/weekly/monthly trends
- Per-project usage breakdown
- Accessible from settings, not surfaced proactively

## Dependencies

- architecture/06-conversation-model.md (token counts stored in timeline items)
- experience/01-window-conversation.md (inspector panel for detailed view)

## Notes

Token visibility is a trust feature, not a power-user feature. When users feel surprised by costs, they lose trust in the app. The goal is: no one is ever surprised by their bill.

But it's also not a gate. We don't make people think about costs before every message — that kills the conversational flow and directly hurts our speed moat. The information is there for those who want it, invisible for those who don't.

---

*Back to [Index](../../INDEX.md)*
