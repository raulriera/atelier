# Document Generation

> **Category:** macOS Integration
> **Type:** Improvement · **Priority:** Medium
> **Milestone:** M5 · **Status:** 🔲 Not started

---

## Problem

Generated files (Excel, Word, PDF, PowerPoint) have no native preview, no version history, and no Finder integration. Users must leave the app to see what was produced.

## Solution

Native enhancements around document generation:

- **Inline preview** — Quick Look preview of outputs directly in the conversation, no Finder needed
- **Finder tags** — auto-tag generated files (green = final, orange = draft, plus project/date tags)
- **Open With…** — native button to open in the user's preferred app
- **Version history** — `NSFileVersion` tracks generations so users can compare and roll back
- **APFS clones** — zero-cost backup before modifying existing user files

---

*Back to [Index](../../INDEX.md)*
