# Living Context

> **Category:** Context Control & Agent Intelligence
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical

---

## The Problem Nobody Talks About

Every AI tool has a dirty secret: the context window. After enough conversation, the AI quietly forgets everything. Quality degrades. Responses become generic. The user doesn't know why — they just feel like "Claude got dumb."

Technical users work around this. They write CLAUDE.md files, manage .cursorrules, manually paste context. They understand tokens and compaction. They know to keep instructions short and specific.

Non-technical users — the travel planner, the small business owner, the student — hit the wall and blame the product. They never come back.

**This is the single biggest barrier to AI adoption for knowledge work.**

## The Insight

Every other tool treats compaction as a loss event. Context fills up, gets compressed, details vanish. The user's only defense is writing instructions upfront (CLAUDE.md) or hoping the AI remembers the right things.

Atelier inverts this: **compaction is a learning event.** Every time the context window fills and compresses, Claude distills what it learned into persistent project files. The project gets smarter over time. The user never thinks about tokens — they just notice Claude "gets" their project more with each conversation.

## How It Works

### The compaction-distillation loop

```
Conversation happens
        ↓
Context fills up → compaction triggers
        ↓
Claude reviews what was learned this session:
  - New patterns, preferences, corrections
  - Key decisions and their rationale
  - Facts about the project discovered during work
        ↓
Claude writes/updates context files in the project
        ↓
Fresh context loads → context files are re-read
        ↓
Claude continues, now with distilled knowledge baked in
```

This runs silently. The user never sees "compacting..." or "saving memory..." — they just keep talking.

### Multi-file memory (grows forever)

One big file is a dead end — it bloats, loses structure, and eventually hurts more than it helps. Instead, Atelier writes to multiple focused files:

```
.atelier/
├── context.md          ← Project identity & core instructions
├── memory/
│   ├── preferences.md  ← "Use DD/MM/YYYY", "Prefers bullet points"
│   ├── decisions.md    ← "Chose Next.js over Remix because..."
│   ├── patterns.md     ← "Files are organized by client name"
│   ├── vocabulary.md   ← Domain-specific terms and meanings
│   └── corrections.md  ← "Don't use 'leverage', say 'use'"
```

Each file stays small and focused. New topics get new files. Old entries get refined or removed as the project evolves. There's no upper bound — memory grows horizontally across files, not vertically in one blob.

### What gets distilled

| Source | What Claude learns | Where it goes |
|--------|--------------------|---------------|
| User corrections | "Not that format" → preference | `preferences.md` |
| Repeated patterns | "Always saves PDFs to /exports" | `patterns.md` |
| Explicit decisions | "We chose Stripe over Square" | `decisions.md` |
| Domain terms | "ARR means Annual Recurring Revenue" | `vocabulary.md` |
| Project structure | "Client folders are under /clients/{name}" | `context.md` |
| User feedback | "Don't be so formal", "Stop using emojis" | `preferences.md` |
| Failed approaches | "Tried X, didn't work because Y" | `decisions.md` |

Failures are explicitly preserved. Manus found that keeping "tried X, didn't work because Y" in context prevents the model from repeating mistakes — a pattern every other tool ignores. `decisions.md` tracks what was rejected and why, not just what was chosen.

### What never gets distilled

- Conversation content (what was said stays in session history)
- Sensitive data (passwords, keys, personal information)
- Temporary state (current task details, in-progress work)
- Single-use instructions ("make this heading bold" — not a pattern)

## Persona Emergence

### The project develops its own identity

Rather than picking from preset roles (Engineer, Designer, Legal), the persona emerges from the project itself. Claude adapts based on what it discovers:

**Day 1 — Generic Claude.** User opens a folder and starts chatting. No context files exist. Claude is helpful but generic.

**Day 3 — Pattern recognition.** Claude has had a few conversations. It notices: the user always asks for professional language, prefers structured outputs, references "the board" frequently. This looks like a corporate strategy project.

**Week 2 — Proactive adaptation.** Claude has built context files. It now:
- Writes in a professional, structured tone without being asked
- Understands the project's stakeholders and decision-makers
- Knows the file organization and where things go
- Uses the project's terminology correctly
- Anticipates what kind of output the user wants

**Month 2 — Deep project intelligence.** The context files are rich. Claude:
- Remembers decisions from weeks ago and their rationale
- Connects new work to existing project themes
- Flags inconsistencies with earlier decisions
- Suggests approaches based on what worked before in this project

### Project fingerprinting (first session)

On the first conversation in a new project, Claude silently scans the project structure to set an initial baseline:

| Signal | Inference |
|--------|-----------|
| `package.json`, `.swift` files | Software project — technical tone, code-aware |
| `.docx`, `.pdf` in subfolders | Document-heavy — writing assistance, formatting |
| Client-name folders | Service business — professional, client-focused |
| Meeting notes, agendas | Collaborative project — structured, action-oriented |
| Research papers, citations | Academic — precise language, citation-aware |
| Invoices, spreadsheets | Financial — numbers-focused, accuracy-critical |
| Mix of everything | Multi-domain — adapt per conversation topic |

This isn't a classification system ("you are in Legal Mode"). It's a set of soft signals that inform how Claude communicates, what it offers to help with, and how it structures its responses. The user can always override any inference.

Research across CrewAI, AutoGen, and LangGraph consistently found that **one well-informed agent outperforms a committee of specialists** for most real-world tasks. Multi-agent architectures add latency, cost, and coordination overhead. The right approach isn't switching between preset roles — it's one Claude that deeply understands this specific project.

### The user is always in control

- Claude writes context files, but the user can read and edit them at any time
- Every proactive suggestion is just that — a suggestion. "I noticed X, want me to save this?"
- Context files are plain markdown — inspectable, shareable, version-controllable
- The user can delete any file and Claude starts fresh on that topic
- Corrections are immediate: "Don't do that" → Claude updates the relevant file
- A "reset persona" option exists for when the project direction changes fundamentally

## Proactive behaviors

Atelier doesn't wait to be asked. It takes initiative, then defers to the user:

### Always-on (silent)

- **Post-compaction distillation** — writes to context files after every compaction
- **Vocabulary learning** — picks up domain terms from documents in the project
- **Structure awareness** — understands how files are organized, updates when things move
- **Preference tracking** — records formatting, tone, and style preferences from corrections

### Suggest-then-act (needs user nod)

- **New context file** — "I've noticed several patterns. Want me to save them?"
- **Pattern conflict** — "You asked for informal tone, but your last 3 messages were formal. Which do you prefer?"
- **Stale context** — "Your decisions.md references a vendor you haven't mentioned in 2 months. Still relevant?"
- **Missing context** — "I keep needing to re-learn your file naming convention. Want me to document it?"

### Never (user must initiate)

- Deleting context files
- Changing fundamental project identity
- Sharing context with other projects
- Modifying files outside `.atelier/`

## Smart loading (don't waste the window)

The naive approach — inject all memory files into the system prompt — falls apart as memory grows. A project with 20 memory files would burn thousands of tokens before the conversation even starts. Research from Cursor, Manus, and Anthropic points to a better architecture:

### Dynamic retrieval, not pre-loading

Always load the essentials:
- `context.md` — project identity, always relevant
- `preferences.md` — how the user wants things done

Everything else is **discoverable on demand.** Claude knows which memory files exist (a one-line manifest) and reads them when a conversation touches that topic. If the user asks about a past decision, Claude reads `decisions.md`. If domain terms come up, it reads `vocabulary.md`. Files that aren't relevant stay on disk.

Cursor proved this approach: dynamic context discovery produced a **46.9% reduction in total tokens** compared to pre-loading everything. The model performs better with less context when that context is highly relevant.

### Attention-aware ordering

LLMs have a "lost in the middle" problem — content at the start and end of the prompt gets more attention than content buried in the middle. Atelier exploits this:

```
System prompt structure:
  1. [START] Project identity (context.md) — stable, cached
  2. [MIDDLE] Loaded memory files — relevant to current topic
  3. [END] Active objectives / current session state — recency bias
```

Manus discovered that continuously writing to a `todo.md` at the end of context — effectively "reciting objectives into recency-favored attention positions" — dramatically improved task coherence across long sessions. Atelier should do the same: the current task state always sits at the end of the prompt.

### KV-cache friendly structure

API cost matters. Anthropic's prompt caching gives 10x cost reduction for cached tokens. To maximize cache hits:

- **Stable content first:** Project identity, vocabulary, patterns rarely change → cached across all requests in a session
- **Volatile content last:** Session state, recent preferences → changes per request, never cached
- **No timestamps in the prompt prefix** — a single changed character invalidates the entire downstream cache
- **Append-only within a session** — new context is added at the end, preserving the cached prefix

### Project structure map

On project open, Atelier auto-generates a lightweight structural map — file tree with key document names, not contents. This gives Claude spatial awareness ("the contracts are in /legal, the budget is in /finance") without reading every file. Inspired by Aider's repo-map, which found that structural understanding without full content lets the model navigate large projects effectively.

### Progressive decay

Not all memories are equally relevant forever. Entries that haven't been touched in N sessions should automatically condense:

- **Recent (< 5 sessions):** Full detail — "Chose Stripe over Square because Square's API doesn't support recurring billing and the client needs subscription management"
- **Aging (5–20 sessions):** Key facts — "Chose Stripe for recurring billing support"
- **Old (20+ sessions):** One-liner or archived — "Payment: Stripe"

This keeps memory files lean without losing information entirely. Archived entries move to `.atelier/memory/archive/` and can be recovered if they become relevant again.

## How this relates to the CLI

Atelier wraps the Claude CLI. The living context system works through:

1. **System prompt injection** — context files are loaded and passed via `--append-system-prompt` (keeps the CLI's default tool instructions intact) or `--system-prompt-file` (loads from a file, cleaner for multi-file memory). Ordered for cache efficiency.
2. **`SessionStart` hook (compact matcher)** — Claude Code fires a `SessionStart` hook with `"matcher": "compact"` specifically after context compaction. Anything the hook writes to stdout becomes context in the fresh window. This is the purpose-built mechanism for post-compaction distillation — no need to detect compaction events separately.
3. **Context file management** — Atelier reads/writes `.atelier/memory/` files using the host filesystem (not through the CLI)
4. **Manifest-based discovery** — Claude receives a manifest of available memory files and reads them on demand via tools, not pre-loaded

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "compact",
      "hooks": [{
        "type": "command",
        "command": "~/.atelier/hooks/inject-context.sh"
      }]
    }]
  }
}
```

The hook script reads `.atelier/memory/` files and writes the essentials (`context.md`, `preferences.md`, manifest) to stdout. The CLI receives this as fresh context automatically.

### Coexistence with Claude Code's auto-memory

Claude Code has its own auto-memory system (`~/.claude/projects/*/memory/MEMORY.md`). For developer projects that use both Atelier and the CLI directly, these two memory systems could conflict — both writing preferences, both trying to be authoritative. Atelier's memory files (`.atelier/memory/`) are project-scoped and multi-file; Claude Code's are user-scoped and single-file. The resolution: Atelier's context files take precedence when present (they're loaded via system prompt), and Claude Code's auto-memory is additive. A `SessionStart` hook can merge or suppress the CLI's auto-memory when Atelier's richer context is available.

The CLI doesn't need to know about living context. It just receives a system prompt that happens to be very good because Atelier maintains it.

## Implementation

### Phase 1 — Hook-Based Distillation ✅

Distillation fully migrated from app-side code to CLI hooks via `atelier-hooks` helper binary.

**What's built:**
- `HooksManager` — registers hooks in `.claude/settings.local.json`, coexists with user hooks
- `atelier-hooks` helper binary — `distill` and `reinject` subcommands, compiled into `Contents/Helpers/`
- `DistillationEngine` — prompt construction + output validation (canonical logic, reused by helper)
- `MemoryStore` — reads/writes category files in `.atelier/memory/` on disk
- `ContextFileLoader` — discovers memory files at project root, injects with `<project-memory>` wrapper

**Hooks registered:**
- `Stop` (async) — distills learnings after each response
- `PreCompact[auto]` (sync) — saves learnings before context compresses
- `SessionStart[compact/startup/resume]` — re-injects learnings into fresh context

**What was removed:**
- `ConversationSummarizer` — replaced by transcript-based summarization in helper binary
- `triggerDistillation()` in `ConversationWindow` — replaced by `Stop` hook

### Phase 2 — Multi-File Memory ✅

Memory split from a single `learnings.md` into separate category files that grow independently.

**What's built:**
- `MemoryStore` rewritten with `read(category:)`, `write(category:)`, `readAll()`, `listFiles()`
- `atelier-hooks distill` splits Haiku output by `## ` heading into separate files
- `atelier-hooks reinject` reads all `.md` files from memory directory
- `HooksManager` shell fallback updated to read all `*.md` files

**Category files:**
- `preferences.md` — user preferences ("Use DD/MM/YYYY", "Prefers bullet points")
- `decisions.md` — key decisions and rationale ("Chose Stripe because...")
- `patterns.md` — recurring patterns ("Files organized by client name")
- `corrections.md` — explicit corrections ("Don't use 'leverage', say 'use'")

**Merge strategy:** Haiku receives all existing category file contents and produces a merged update. New entries are added, contradicted entries are replaced, still-valid entries are preserved.

### Phase 3 — Smart Loading

- Add file size monitoring — split a file when it exceeds ~100 lines
- **Switch from injection to manifest-based discovery** — always load `context.md` + `preferences.md`, everything else via one-line manifest read on demand (see "Smart loading" section)
- `PostToolUse[Write|Edit]` hook tracks file changes → updates project structure map automatically

### Phase 4 — Project Fingerprinting

- On first session, scan project directory structure
- Identify primary domain(s) based on file types, names, and directory patterns
- Generate initial `context.md` with inferred project identity
- Present to user for confirmation: "I think this is a [type] project. Does this look right?"
- `SessionStart[startup]` hook on first session triggers fingerprinting

### Phase 5 — Proactive Suggestions

- Track patterns across sessions (corrections, repeated instructions, style preferences)
- After confidence threshold is met (3+ consistent signals), offer to save
- UI for viewing and managing suggestions (dismiss, accept, modify)
- Respect dismissals permanently — never re-suggest the same thing
- `PostToolUseFailure` hook records failed approaches automatically

### Phase 6 — Context Health

- Dashboard showing active context files and their token cost
- Staleness detection — flag entries that haven't been relevant in N sessions
- Conflict detection — flag contradictions between context files
- Token budget visualization — "Your context uses X of Y available tokens"
- `InstructionsLoaded` hook verifies memory files are being read and tracks load order

## Dependencies

- architecture/09-hooks-infrastructure.md (hook management — the foundation for all of this)
- context/01-project-context-files.md (discovery and loading)
- architecture/04-session-persistence.md (session history feeds distillation)
- experience/03-conversational-flow.md (inline suggestions for proactive offers)

## Why This Is the Moat

Every AI tool will eventually be fast. Every AI tool will eventually have a nice UI. But **a project that has been using Atelier for 3 months is profoundly better than a fresh start anywhere else.** The accumulated context — preferences, decisions, vocabulary, patterns — is a switching cost that benefits the user, not locks them in.

The user's project folder contains everything. They can move it, share it, version it. But the intelligence embedded in those context files makes Atelier irreplaceable through quality, not captivity.

---

*Back to [Index](../../INDEX.md)*
