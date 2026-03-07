# Spotlight & System Search Integration

> **Category:** macOS Integration
> **Type:** 🆕 New Capability · **Priority:** 🟡 Medium
> **Milestone:** M5

---

## Current State (Electron / Cowork)

No system search integration — Cowork outputs, conversation history, and task results are invisible to Spotlight and completely siloed within the Electron app.

## Native macOS Approach

**CoreSpotlight integration**: index all Cowork-generated files, conversation history, and task results. Users can find past Cowork outputs system-wide via Spotlight.

### Implementation Strategy

- Register a `CSSearchableIndex` and index every Cowork output with rich metadata: title, task description, creation date, source folder, tags, and a text summary.
- Implement a Spotlight Importer (`mdimporter`) for `COWORK.md` files so they appear in Spotlight searches.
- Tapping a Spotlight result opens the relevant Cowork session directly.
- Also index completed task summaries — "find that financial analysis I ran last Tuesday" works from Spotlight.

### Key Dependencies

- CoreSpotlight framework, `CSSearchableItem`, `CSSearchableItemAttributeSet`
- Spotlight Importer plugin for custom file types

---

*Back to [Index](../../INDEX.md)*
