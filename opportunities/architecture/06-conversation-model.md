# Conversation & Data Model

> **Category:** Architecture
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical

---

## Problem

The conversation timeline is the entire product surface. Every feature — chatting, task execution, file operations, approvals, results — renders into this one timeline. Without a well-defined data model, nothing else can be built.

We need to answer: how are conversations stored, how do they grow over time, how is context managed for the API, and how do new content types get added without breaking old data.

## Solution

### Sessions within a project

A project contains multiple **sessions** (conversations). Each session is a self-contained timeline with its own history and context.

- Opening a project window shows the **most recent session** by default
- `⌘N` starts a fresh session within the same project window
- Previous sessions are accessible via search (`⌘K`) or the inspector panel
- Each session is its own file on disk — clean separation, simple I/O
- Project context (CLAUDE.md, settings, permissions) carries across all sessions
- Session-specific conversation history does not leak into other sessions

This maps to how people work: Monday's itinerary research is a different conversation than Tuesday's packing list, but they're in the same trip folder. A developer's refactoring session is separate from their bug fix. A consultant's client call prep is separate from their invoice review. Different conversations, same project.

### Storage: files, not a database

All data is stored as plain files — JSON for metadata, JSONL (JSON Lines) for timelines.

```
~/.atelier/
├── config.json                    → global settings
└── projects/
    └── <project-id>/
        ├── project.json           → metadata: path, name, created, lastOpened
        └── sessions/
            └── <session-id>/
                ├── meta.json      → title, created, lastModified, tokenCount
                └── timeline.jsonl → one JSON object per line (append-only)
```

**Why files:**
- Inspectable and debuggable — open in any text editor
- Portable — copy a project folder to back up or share
- Append-only JSONL for timelines — never rewrite the whole file, fast writes during streaming
- No database migrations, no schema versioning headaches
- A 500-message session is a few hundred KB — trivially fast to load

**Reactivity:** The in-memory `@Observable` model is the source of truth during a session. SwiftUI observes it directly. File writes happen asynchronously on a background queue, debounced to avoid thrashing during streaming. On launch, files hydrate the in-memory model. This is the standard document-based Mac app pattern.

### Timeline content: tagged data with protocols

Each timeline item has a type tag (for serialization) and conforms to a protocol (for extensibility).

```swift
// The timeline item — what gets stored in JSONL
struct TimelineItem: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let content: TimelineContent
}

// Tagged union — known types are explicit, unknown types degrade gracefully
enum TimelineContent: Codable {
    case userMessage(UserMessage)
    case assistantMessage(AssistantMessage)
    case fileCard(FileCard)
    case artifact(ArtifactCard)
    case diff(DiffCard)
    case toolUse(ToolUseCard)
    case progress(ProgressCard)
    case approval(ApprovalCard)
    case result(ResultCard)
    case system(SystemEvent)
    case unknown(type: String, data: Data)
}
```

The `unknown` case is the future-proofing escape hatch. If a future version adds a new content type, older versions of the app can load the file without crashing — unknown items render as a generic card or are hidden.

New content types are added by:
1. Adding a case to `TimelineContent`
2. Creating the corresponding struct
3. Adding a cell view for rendering

### Content types

```swift
struct UserMessage: Codable {
    var text: String
    var attachments: [FileReference]
}

struct AssistantMessage: Codable {
    var text: String
    var isComplete: Bool
    var children: [TimelineItem]       // nested: tool uses, file reads, artifacts
    var inputTokens: Int
    var outputTokens: Int
}

struct FileCard: Codable {
    var path: String
    var action: FileAction             // .read, .write, .delete, .create
    var summary: String?               // "Read travel-itinerary.pdf" or "Created report.xlsx"
}

struct ArtifactCard: Codable {
    var title: String                  // "Japan Day-by-Day Itinerary", "Q3 Client Report"
    var contentType: String            // "text/markdown", "text/html", "application/pdf"
    var content: String                // the generated content (markdown, HTML, etc.)
    var isExpandable: Bool             // show inline or as a preview card
}

struct DiffCard: Codable {
    var path: String
    var hunks: [DiffHunk]
    var status: ReviewStatus           // .pending, .approved, .rejected
}

struct ApprovalCard: Codable {
    var description: String
    var risk: RiskLevel                // .low, .medium, .high
    var status: ApprovalStatus         // .pending, .approved, .rejected
    var action: ProposedAction
}

struct ProgressCard: Codable {
    var description: String
    var progress: Double?              // 0.0–1.0 if known
    var status: TaskStatus             // .running, .completed, .failed, .cancelled
}

struct ResultCard: Codable {
    var summary: String
    var children: [TimelineItem]?      // expandable details
}

struct SystemEvent: Codable {
    var kind: SystemEventKind          // .sessionStarted, .projectOpened
    var message: String
}
```

### The drillable assistant message

An `AssistantMessage` is more than text. Its `children` array contains the work that happened during that response — file reads, tool uses, generated artifacts. The default view shows the text. Expanding reveals the nested cards: "Read travel-itinerary.pdf", "Created day-by-day-plan.md", or a diff of changes made to a document.

### Streaming

1. User types message → `UserMessage` appended to timeline, engine receives it
2. Engine returns `AsyncStream<TimelineEvent>`
3. `.textDelta` → `activeMessage.text` grows in place, SwiftUI re-renders just that cell
4. `.toolUseStart` → a child `TimelineItem` is added inside `activeMessage.children`
5. `.toolUseResult` → the child item updates with the result
6. `.messageComplete` → `activeMessage.isComplete = true`, full item flushed to JSONL

```swift
enum TimelineEvent {
    case textDelta(String)
    case toolUseStart(ToolUseCard)
    case toolUseResult(id: UUID, result: TimelineContent)
    case messageComplete(usage: TokenUsage)
    case error(Error)
}
```

### The engine abstraction

The conversation engine is a protocol. Today it wraps the Anthropic API directly. Tomorrow it could wrap the Claude Code SDK or something else entirely.

```swift
protocol ConversationEngine: Sendable {
    func send(
        message: String,
        context: ProjectContext,
        history: [TimelineItem]
    ) -> AsyncStream<TimelineEvent>
}
```

The engine receives the user's message, the project context (folder contents, context files, settings), and the session history (for conversational continuity). It returns a stream of events that the UI renders progressively.

### Context management for the API

Claude has a finite context window. A long session can't all be sent. The engine manages this:

1. **Always included:** Project context files (CLAUDE.md, COWORK.md), system prompt
2. **Recent history:** The last N messages from the current session (fits within context budget)
3. **Summarized older context:** If the session is long, older messages are summarized into a compact representation
4. **Cross-session memory:** Project-level memory (patterns, preferences, decisions) persists in context files, not in conversation history

The user never sees this windowing — it's invisible. They scroll back and see all their messages. Claude's effective memory is managed behind the scenes.

## Implementation

### Phase 1 — Core Model

- `TimelineItem`, `TimelineContent` enum, all content type structs
- `Session` as `@Observable` class: id, title, items array, activeMessage
- JSONL reader/writer with async file I/O
- Unit tests: serialization round-trips, unknown type handling, append-only writes

### Phase 2 — In-Memory Reactivity

- `Session.items` drives SwiftUI timeline via `LazyVStack`
- Streaming updates: `activeMessage.text` mutations trigger minimal view recomputation
- Debounced file writer: batches JSONL appends during streaming, flushes on completion
- Performance target: 120fps scrolling with 1000+ items (virtualized)

### Phase 3 — Session Lifecycle

- `⌘N` creates new session within project window
- Session list in inspector panel (title, date, preview of first message)
- `⌘K` search across all sessions in a project (full-text search over JSONL files)
- Window shows most recent session on open, with back/forward navigation

### Phase 4 — Context Windowing

- Token counting for history items
- Sliding window: fill context budget with recent messages, truncate oldest
- Summary generation: when a session exceeds N messages, summarize the oldest chunk
- Project-level memory extraction: surface patterns/decisions to CLAUDE.md

## Dependencies

- experience/01-window-conversation.md (the conversation timeline UI)
- experience/02-project-workspace.md (project ↔ session relationship)
- architecture/04-session-persistence.md (sessions surviving reboot)

## Notes

This model is the spine of the entire app. Every feature renders into the timeline, every user action creates timeline items. The decisions here — files over database, tagged data for extensibility, sessions for conversation lifecycle — are load-bearing. Change them later and everything moves.

The `unknown` content type case is non-negotiable. We will add content types we can't predict today. Old data must always load.

---

*Back to [Index](../../INDEX.md)*
