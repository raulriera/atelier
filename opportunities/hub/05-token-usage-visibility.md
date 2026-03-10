# Token Usage Visibility

> **Category:** Hub / Unified Experience
> **Type:** New Capability · **Priority:** Critical
> **Milestone:** M3 · **Status:** 🔲 Not started

---

## Problem

Opaque costs — users burn through API allocations without warning. No real-time usage meter, no per-conversation breakdown, no spending alerts. Consistently one of the top user complaints.

## Solution

Token usage is visible when you want it, invisible when you don't. Progressive disclosure: a subtle indicator during conversations, detailed breakdowns for those who care.

### What users see

**During a conversation** — a compact token count at the end of each assistant message. Small, muted, unobtrusive. Like a word count in a writing app.

**In the inspector panel** (`⌘I`) — session tokens (input/output), estimated cost, billing period progress bar, remaining budget projection.

**Pre-send hints** — before sending a long message with large attachments: "This message is ~12,000 tokens." No modal, no gate — just information.

**Budget alerts** — configurable thresholds (75%, 90%) delivered via native notifications.

### What it doesn't do

No "estimate panel" that gates every message. No "Adjust Settings" before you can talk. Cost information is available without interrupting the conversational flow.

Token visibility is a trust feature, not a power-user feature. When users feel surprised by costs, they lose trust. The goal: no one is ever surprised by their bill. But it's not a gate — making people think about costs before every message kills the flow and directly hurts our speed moat.

---

*Back to [Index](../../INDEX.md)*
