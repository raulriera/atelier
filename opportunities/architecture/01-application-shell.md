# Application Shell

> **Category:** Architecture & Performance
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical
> **Milestone:** M0

---

## Problem

Claude's desktop experience is an Electron wrapper — high RAM (~500MB+), slow startup (3–5s), non-native rendering. It doesn't respect macOS conventions: no native menus, no system font rendering, no Reduce Motion, no VoiceOver support without extra work. The app feels foreign on the platform it runs on.

## Solution

A native Swift app built on SwiftUI that boots fast, feels native, and is nothing more than a conversation in a window.

### What M0 delivers

The smallest thing that's useful: open the app and talk to Claude.

1. **A native window with a text field.** SwiftUI app, single window, conversation timeline above, text input below. That's the UI.
2. **Paste your key and go.** First launch asks for an Anthropic API key (with a link to console.anthropic.com). Key validated and stored in Keychain. One step, then never again.
3. **A basic conversation.** Send a message, see Claude's response stream in. Messages persist to disk (JSONL). Reopen the app, your conversation is still there.

No container. No sandbox. No file system access. No projects. Just chat.

### What it looks like

```
┌─────────────────────────────────────────┐
│  Atelier                          ⌘     │
│─────────────────────────────────────────│
│                                         │
│  Hi! How can I help you today?          │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ Can you help me plan a trip     │    │
│  │ to Japan for two weeks?         │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Of course! I'd love to help you plan   │
│  a trip to Japan. Let me ask a few      │
│  questions to get started...            │
│  ▌                                      │
│                                         │
│─────────────────────────────────────────│
│  Message Claude...              ⏎ Send  │
└─────────────────────────────────────────┘
```

### App structure

```swift
@main
struct AtelierApp: App {
    var body: some Scene {
        WindowGroup {
            ConversationWindow()
        }
    }
}
```

M0 uses `WindowGroup` for simplicity — one window type, one conversation. M2 evolves this into a document-based model (`DocumentGroup` or project-scoped `openWindow`) when projects and multi-window support arrive.

### First launch flow

1. App opens → window appears with a welcome message and a text field
2. If no API key exists → an inline prompt appears: "Enter your Anthropic API key to get started" with a link to console.anthropic.com
3. User pastes key → validated with a lightweight API call → stored in Keychain
4. Text field activates → user can start typing immediately
5. No onboarding wizard, no feature tour, no settings. Paste and go.

The API key prompt is inline in the conversation — not a modal, not a settings screen. It's the first "message" in the timeline. Anthropic's terms prohibit third-party apps from using subscription OAuth, so API key authentication (usage-based billing) is the only supported path.

### Technology choices

| Decision | Choice | Why |
|----------|--------|-----|
| UI framework | SwiftUI (AppKit bridging where needed) | Native rendering, `@Observable` reactivity, state restoration for free |
| Minimum OS | macOS 26 (Tahoe) | Required for Containerization framework in later milestones |
| API communication | `URLSession` + streaming JSON | No SDK dependency. Protocol abstraction (`ConversationEngine`) allows pivoting later |
| Credential storage | Keychain via Security framework | API key stored natively. Never in UserDefaults or files |
| Data persistence | JSONL files, `@Observable` in-memory model | See architecture/06-conversation-model.md |
| Text rendering | SwiftUI `Text` + `AttributedString` | System fonts, Dynamic Type, accessibility for free |
| Concurrency | Swift structured concurrency (`async/await`, `AsyncStream`) | No Combine unless required by system APIs |

### Performance targets

These are M0 targets — the bar only goes up from here.

| Metric | Target | How to verify |
|--------|--------|---------------|
| Cold launch to text field ready | < 1 second | Instruments Time Profiler |
| Time to first streamed token visible | < 300ms after API responds | Signpost measurement |
| Scrolling through 200+ messages | 120fps on ProMotion displays | Core Animation instrument |
| Idle RAM | < 100MB | Activity Monitor / Instruments |
| Typing latency | < 16ms per keystroke | Main thread responsiveness |

### Why macOS 26

The Containerization framework (apple/containerization) requires macOS 26. We don't need it in M0, but choosing the minimum target now avoids a painful migration later. It also gives us access to the latest SwiftUI improvements, Swift 6.2 concurrency features, and the newest AppKit APIs.

## Implementation

### Phase 1 — Window & Input

- `AtelierApp` with `WindowGroup` scene
- `ConversationWindow` view: scrollable timeline + text input
- Basic message display: user messages and assistant messages
- Text input with auto-grow and Enter-to-send
- Window state restoration via `@SceneStorage`

### Phase 2 — API Connection

- `AnthropicEngine` conforming to `ConversationEngine` protocol
- Streaming response via `URLSession` + server-sent events parsing
- API key entry inline in conversation timeline (with link to console.anthropic.com)
- Key validation and Keychain storage via Security framework
- Error handling: network failures, rate limits, invalid key — all shown as inline messages

### Phase 3 — Persistence

- JSONL writer: append timeline items to disk as they complete
- JSONL reader: hydrate in-memory model on launch
- `@Observable` `Session` model driving SwiftUI updates
- Debounced writes during streaming (don't flush every token delta)
- Verify: quit and relaunch, conversation is intact

### Phase 4 — Polish

- Smooth streaming animation (text appearing word by word or chunk by chunk)
- Loading state while waiting for first token
- Empty state for new conversations
- Basic keyboard shortcuts: `⌘N` (new window), `⌘W` (close), `⌘,` (settings placeholder)
- Performance profiling pass: hit all targets in the table above

## M0 exit criteria

M0 is done when a user can:

- [ ] Launch the app and see a window in under 1 second
- [ ] Enter an API key (first launch) and have it remembered
- [ ] Type a message and see Claude's response stream in
- [ ] Have a multi-turn conversation (Claude remembers earlier messages in the session)
- [ ] Quit the app, relaunch, and see the previous conversation
- [ ] Scroll through a long conversation at 120fps

That's it. Everything else — projects, file access, containers, context files — is a later milestone.

## Dependencies

- architecture/06-conversation-model.md (data model: TimelineItem, Session, JSONL storage)
- experience/01-window-conversation.md (conversation timeline UI design)

## Notes

This is the foundation. If M0 feels fast and simple, everything we add in later milestones inherits that quality. If M0 is slow or cluttered, no amount of features fixes it.

The `ConversationEngine` protocol is the key abstraction. M0 implements `AnthropicEngine` (direct API calls via URLSession). M3 can introduce `ClaudeCodeEngine` (running through the container). The UI never knows or cares which engine is active.

Keep the dependency list minimal. M0 should build with zero third-party packages — just Apple frameworks and our own code. Every external dependency is a maintenance burden and a startup time cost.

---

*Back to [Index](../../INDEX.md)*
