# Async File I/O on Hot Paths

> **Category:** Architecture
> **Type:** 🐛 Technical Debt · **Priority:** 🟡 Medium
> **Milestone:** —

---

## Problem

Several code paths read files synchronously on the main thread, blocking the UI during renders or user actions. For a product where "speed is the product," any main-thread file I/O is a latent frame-drop waiting to happen.

Today's known instances:

1. **`ContextFileLoader.contentForInjection(from:)`** — reads project context files (`COWORK.md`, `.atelier/context.md`) via `String(contentsOf:)` synchronously. Called from `ConversationWindow.sendMessage()`, blocking the main thread on every send.
2. **`MemoryStore.readLearnings()`** — reads the learnings file via `String(contentsOf:)` synchronously. Called during session setup without async wrapping.

A third instance (`TimelineView` reading plan files in `body`) was already fixed by moving the read into a `.task` modifier on `PlanReviewCard`.

## Solution

Each synchronous file read should be replaced with an async alternative:

### Pattern: `.task` for view-driven reads

When a view needs file content to render, load it in a `.task(id:)` modifier and store the result in `@State`. The view renders immediately (with a placeholder or empty state) and updates when the read completes.

```swift
@State private var content: String?

var body: some View {
    ContentView(text: content ?? "")
        .task(id: filePath) {
            content = try? String(contentsOfFile: filePath, encoding: .utf8)
        }
}
```

### Pattern: async method for model-driven reads

When a model or service needs file content, expose an `async` method and call it from a `Task` at the appropriate lifecycle point.

```swift
// Before (blocking)
func inject() -> String {
    try? String(contentsOf: url, encoding: .utf8) ?? ""
}

// After (non-blocking)
func inject() async -> String {
    (try? String(contentsOf: url, encoding: .utf8)) ?? ""
}
```

### Specific fixes

| File | Method | Fix |
|------|--------|-----|
| `ContextFileLoader.swift` | `contentForInjection(from:)` | Make `async`, call from existing `Task` in `sendMessage` |
| `MemoryStore.swift` | `readLearnings()` | Make `async`, call from `.task` or session init |

## Dependencies

- None — each fix is self-contained and can be done independently.

## Priority

Medium. The files involved are small (context files are typically <10KB, learnings <5KB), so the blocking duration is short. But the pattern is wrong in principle, and as projects grow, these reads will get slower. Fix before shipping to avoid establishing synchronous I/O as an acceptable pattern.
