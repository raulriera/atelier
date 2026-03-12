# Task Tracking (TodoWrite)

> **Milestone:** —
> **Status:** 🔴 Broken

---

## Problem

The built-in `TodoWrite` tool from the CLI displays persistent task checklists in the conversation. The UI rendering works, but tool calls fail because the approval helper corrupts nested JSON during round-tripping.

## Investigation

- **`updatedInput` is required** — the CLI validates it as a record. Removing it causes `ExitPlanMode` (and all other tools) to fail with `"expected record at updatedInput"`.
- The approval helper passes `rawInput` (an `AnyCodableValue`) back as `updatedInput` in the allow response. This is then encoded to a JSON string inside a text content block. For flat tools this works. For deeply nested inputs (`TodoWrite.todos`, `ExitPlanMode.plan`), the re-encoding through `AnyCodableValue` → `JSONEncoder` → string → text block may corrupt the structure.
- `ExitPlanMode` was also failing with the same `updatedInput` error — the issue affects any tool with complex nested input, not just `TodoWrite`.

## Next step

Debug the exact encoding path: capture what the CLI sends as `input`, what `AnyCodableValue` decodes it as, and what gets re-encoded as `updatedInput`. The corruption likely happens in the `AnyCodableValue` decode/encode round-trip or in the double-encoding through the text content block.

---

*Back to [Index](../../INDEX.md)*
