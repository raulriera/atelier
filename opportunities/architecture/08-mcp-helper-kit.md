# MCP Helper Kit

> **Category:** Architecture
> **Type:** Improvement · **Priority:** Medium
> **Milestone:** M3 · **Status:** ✅ Done

---

## Problem

Nine MCP helper scripts each duplicate ~200 lines of boilerplate: JSON-RPC types, response handling, main loop, error formatting. Total: ~1,800 lines of repeated code across helpers. Adding a new capability means copy-pasting this boilerplate.

## Solution

Extract shared MCP infrastructure into a reusable `MCPHelperKit` SPM package. Each helper becomes a compiled executable that imports the shared library — reducing duplication, enabling centralized testing, and making new capabilities trivial to add.

### What moves into the shared package

- JSON-RPC 2.0 types and request/response parsing
- Stdio transport (stdin line reader, stdout JSON writer)
- Tool registration and dispatch
- Error formatting and logging
- The main run loop

### What stays per-helper

- Tool definitions (name, description, input schema)
- Tool implementations (the actual JXA/AppleScript calls)

---

*Back to [Index](../../INDEX.md)*
