# MCP Helper Kit

> **Category:** Architecture
> **Type:** Improvement · **Priority:** 🟡 Medium
> **Milestone:** M3

---

## Problem

Every capability helper (`Helpers/atelier-*.swift`) is a standalone Swift script that duplicates ~200 lines of identical infrastructure:

- `AnyCodableValue` enum with full `Codable` conformance (~75 lines)
- `JSONRPCRequest`, `JSONRPCResponse`, `JSONRPCError` structs
- `ToolDefinition` struct
- `respond()`, `respondError()` functions
- `handleInitialize()`, `handleToolsList()`, `handleToolsCall()` request routing
- `while let line = readLine(...)` main loop

The 7 JXA-based helpers additionally duplicate `executeJXA()` and `jxaEscape()`.

With 9 helpers shipping today and more planned (Shortcuts, Music, Maps), this is ~1,800 lines of duplicated code that must be kept in sync manually. A bug in `AnyCodableValue` decoding would need to be fixed in 9 files. A protocol version bump requires 9 edits.

## Solution

Extract a shared `MCPHelperKit` SPM package that each helper imports:

```
Packages/
└── MCPHelperKit/
    ├── Package.swift
    ├── Sources/MCPHelperKit/
    │   ├── AnyCodableValue.swift
    │   ├── JSONRPCTypes.swift      ← Request, Response, Error
    │   ├── ToolDefinition.swift
    │   ├── MCPServer.swift         ← Main loop + request routing
    │   └── JXA.swift               ← executeJXA(), jxaEscape()
    └── Tests/MCPHelperKitTests/
        ├── AnyCodableValueTests.swift
        ├── JSONRPCTests.swift
        └── JXATests.swift
```

Each helper becomes a compiled SPM executable target that depends on `MCPHelperKit`, replacing the `#!/usr/bin/env swift` script with a proper binary:

```swift
// Sources/AtelierCalendarMCP/main.swift
import MCPHelperKit

let server = MCPServer(name: "atelier-calendar", version: "1.0.0")
server.registerTools(calendarTools)
server.run { name, args in
    handleCalendarToolCall(name: name, args: args)
}
```

### What changes

| Before | After |
|--------|-------|
| 9 standalone `.swift` scripts | 9 executable targets + 1 shared library |
| `#!/usr/bin/env swift` (interpreted) | Compiled binaries (faster startup) |
| ~200 lines boilerplate per helper | ~20 lines per helper (tool defs + handlers) |
| No tests for JSON-RPC layer | Full test coverage of shared infrastructure |
| Bug fix = edit 9 files | Bug fix = edit 1 file |

### What stays the same

- Helpers still live in `Contents/Helpers/` in the app bundle
- `CLIEngine.bundledHelperPath(named:)` unchanged
- MCP JSON-RPC 2.0 protocol unchanged
- Each helper is still an independent binary (no shared process)

## Implementation

### Phase 1 — Extract MCPHelperKit

1. Create `Packages/MCPHelperKit/` with the shared types and `MCPServer` runner
2. Write tests for `AnyCodableValue` round-tripping, JSON-RPC request/response encoding, JXA escaping
3. Verify the package builds independently with `swift test`

### Phase 2 — Migrate helpers one at a time

4. Convert one helper (e.g. `atelier-reminders-mcp`) to a compiled executable depending on `MCPHelperKit`
5. Update the Xcode build phase to compile from the new location
6. Verify the capability still works end-to-end
7. Repeat for remaining helpers

### Phase 3 — Test coverage

8. Add integration tests that send JSON-RPC messages to each helper and verify tool responses
9. Test error handling: malformed requests, missing parameters, invalid tool names

## Dependencies

- hub/03-plugin-management.md (capability infrastructure)
- Xcode build phases need updating for each migrated helper

## Notes

The `MCPServer` abstraction should be minimal — just the request routing loop. Each helper still owns its tool definitions and handlers. The goal is deduplication, not abstraction-for-abstraction's-sake.

Compiled executables also bring a nice side benefit: faster cold start (~10ms vs ~300ms for `swift` script interpretation), which matters when the CLI spawns all capability servers at conversation start.

---

*Back to [Index](../../INDEX.md)*
