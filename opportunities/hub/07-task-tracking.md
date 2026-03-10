# Task Tracking (TodoWrite)

> **Milestone:** —
> **Status:** 🔴 Broken

---

## Problem

The built-in `TodoWrite` tool from the CLI displays persistent task checklists in the conversation. The UI rendering works, but tool calls fail because the approval helper corrupts nested JSON during round-tripping.

Adding `TodoWrite` to `silentTools` didn't help (the tool still fails). MCP replacement was attempted but doesn't match the CLI's built-in behavior.

## Next step

Root-cause debug the JSON round-trip corruption in the approval helper's handling of nested `TodoWrite` input.

---

*Back to [Index](../../INDEX.md)*
