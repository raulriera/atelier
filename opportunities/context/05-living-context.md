# Living Context

> **Category:** Context Control & Agent Intelligence
> **Type:** New Capability · **Priority:** Critical
> **Milestone:** M2 · **Status:** ✅ Done

---

## The Problem

Every AI tool has a dirty secret: the context window. After enough conversation, the AI quietly forgets everything. Quality degrades. Responses become generic. The user doesn't know why — they just feel like "Claude got dumb."

Technical users work around this with CLAUDE.md files and manual context management. Non-technical users hit the wall and blame the product. **This is the single biggest barrier to AI adoption for knowledge work.**

## The Insight

Every other tool treats compaction as a loss event. Atelier inverts this: **compaction is a learning event.** Every time the context window fills and compresses, Claude distills what it learned into persistent project files. The project gets smarter over time. The user never thinks about tokens.

## How It Works

### The compaction-distillation loop

```
Conversation happens → context fills up → compaction triggers
    → Claude distills learnings (preferences, decisions, patterns, corrections, vocabulary)
    → Writes to .atelier/memory/ files
    → Fresh context loads with distilled knowledge baked in
    → Claude continues, now smarter about this project
```

This runs silently. The user never sees "compacting..." or "saving memory..." — they just keep talking.

### Multi-file memory

One big file is a dead end. Instead, Atelier writes to multiple focused files that grow independently:

- `preferences.md` — "Use DD/MM/YYYY", "Prefers bullet points"
- `decisions.md` — "Chose Stripe over Square because..."
- `patterns.md` — "Files organized by client name"
- `vocabulary.md` — Domain-specific terms and meanings
- `corrections.md` — "Don't use 'leverage', say 'use'"

Failures are explicitly preserved — "Tried X, didn't work because Y" prevents repeating mistakes.

### Smart loading

Not everything gets injected. High-value files (`preferences.md`, `corrections.md`) load in full. Everything else appears as a one-line manifest — Claude reads on demand when relevant. This produces ~47% token reduction vs. pre-loading everything.

### Progressive decay

Not all memories are equally relevant forever. Entries that haven't appeared recently get condensed automatically:

- **Recent:** Full detail
- **Aging (5-20 runs):** Key facts only
- **Old (20+ runs):** Archived to `.atelier/memory/archive/`, recoverable if the topic resurfaces

### Proactive behaviors

**Silent:** Post-compaction distillation, vocabulary learning, preference tracking, stale context detection, conflict detection.

**Suggest-then-act:** Pattern verification ("I've learned you prefer X. Still accurate?"), stale context verification, correction acknowledgment.

**Never:** Deleting context files, changing project identity, modifying files outside `.atelier/`.

## Persona Emergence

The persona emerges from the project — not preset roles. Day 1: generic Claude. Week 2: writes in the right tone, knows the terminology, anticipates output format. Month 2: remembers decisions from weeks ago, flags inconsistencies, suggests approaches based on what worked before.

On the first session, Claude silently scans the project structure to set an initial baseline (project fingerprinting). **One well-informed agent outperforms a committee of specialists.**

### The user is always in control

Context files are plain markdown — inspectable, editable, shareable, version-controllable. Corrections are immediate. Any file can be deleted to start fresh on that topic.

## Status

| Feature | Status |
|---------|--------|
| Hook-based distillation (Stop, PreCompact, SessionStart) | ✅ Shipped |
| Multi-file memory (5 categories) | ✅ Shipped |
| Smart loading (always-inject + manifest) | ✅ Shipped |
| Compaction snapshots (infinite session) | ✅ Shipped |
| Project fingerprinting (Haiku-powered) | ✅ Shipped |
| Proactive suggestions (pattern tracking) | ✅ Shipped |
| Vocabulary learning | ✅ Shipped |
| Progressive decay (entry age tracking) | ✅ Shipped |
| Stale context detection | ✅ Shipped |
| Pattern conflict detection ([corrected] markers) | ✅ Shipped |

## Why This Is the Moat

Every AI tool will eventually be fast. Every AI tool will eventually have a nice UI. But **a project that has been using Atelier for 3 months is profoundly better than a fresh start anywhere else.** The accumulated context is a switching cost that benefits the user, not locks them in.

---

*Back to [Index](../../INDEX.md)*
