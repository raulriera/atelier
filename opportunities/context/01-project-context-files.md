# Project Context Files

> **Category:** Context Control & Agent Intelligence
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical

---

## Current State (Electron / Cowork)

No equivalent to Claude Code's `CLAUDE.md`. Prompts in Cowork are one-off and ephemeral. Users cannot define persistent instructions, project-specific rules, or reusable context that the agent automatically loads. This is the single biggest gap identified by professional users — as one agency put it: "The power of Claude Code isn't that it runs in a terminal. The power is Context Control."

## Native macOS Approach

**The folder is the persona.** A context file in a project folder defines who Claude is in that context — its role, its knowledge, its rules. No "persona builder" UI, no configuration screens. Just a text file.

### How it works

A context file is a markdown file placed in any folder. When a user opens that folder as a project, Atelier auto-loads the context file and Claude adapts accordingly.

**For a travel planner:**
```markdown
# Trip: Japan 2026

I'm planning a 2-week trip to Japan in October.
Budget: moderate (not backpacker, not luxury).
I love ramen, onsen, and architecture.
Avoid tourist traps. Prefer local recommendations.
```

**For a small business CRM:**
```markdown
# Martinez Plumbing — Client Management

Help me track clients, follow-ups, and invoices.
Client folders are organized by name.
Always be professional and concise in drafts.
When I ask about follow-ups, check file dates to find stale clients.
```

**For a developer:**
```markdown
---
capabilities: [web-search]
---
# Atelier

A native macOS app. Swift 6.2+, macOS 26.
See CLAUDE.md for conventions.
```

### The context builds itself

Most users won't create a context file on day one. That's fine. Over time, patterns emerge:

1. **Day one:** User opens a folder and chats. No context file. Claude is generic.
2. **After a few sessions:** Claude notices patterns — "You always ask me to format dates as DD/MM/YYYY" or "You prefer bullet points over paragraphs."
3. **Claude offers:** *"I've noticed some patterns in how you like things done. Want me to save them so I remember next time?"*
4. **User agrees:** Claude writes a context file to the project folder. Next session, it's loaded automatically.
5. **Over time:** The context file grows as preferences accumulate. The user can edit it directly if they want, but they never have to.

### File format

Markdown-based, with optional YAML frontmatter for structured config:

```markdown
---
capabilities: [web-search, google-calendar]
approval: destructive_only
---
# Project instructions

Free-form instructions in natural language.
Claude reads this as context for every session in this project.
```

Frontmatter is optional. A context file can be as simple as a single sentence.

### Discovery and inheritance

- When a user opens a folder, Atelier looks for context files: `CLAUDE.md`, `COWORK.md`, or `.atelier/context.md`
- Walks up the directory tree (like `.gitignore`) — parent context is inherited, child context overrides
- Multiple context files merge: parent provides defaults, child provides specifics
- Claude Code also supports `.claude/rules/` directories with path-scoped rule files (rules that only apply when editing files matching a glob pattern). For developer projects, Atelier should discover and load these alongside context files so CLI and GUI behavior stays consistent

### Who writes context files?

| User level | How they get context |
|-----------|---------------------|
| Everyone | Claude offers to save patterns after a few sessions |
| Regular users | Edit the context file Claude created, or write their own |
| Teams | Share context files via git or file sharing |
| Power users | Write detailed context with YAML frontmatter, capability declarations, and rules |

## Implementation

### Phase 1 — Auto-Discovery & Loading

- Scan project folder for context files (CLAUDE.md, COWORK.md, .atelier/context.md)
- Walk up directory tree, merge parent → child (child overrides)
- Load context into the `ProjectContext` that the `ConversationEngine` receives
- Spotlight-indexable via `mdimporter` so users can find context files system-wide

### Phase 2 — Self-Building Context

- Track user patterns across sessions (formatting preferences, recurring instructions, common corrections)
- After N sessions with consistent patterns, offer to save them
- Generate a context file draft and show it to the user for approval before writing
- Never write to the user's folder without explicit consent

### Phase 3 — Context Editor

- Built-in editor for viewing/editing context files (simple markdown with syntax highlighting)
- Accessible from the inspector panel or project settings
- Live preview: "Here's how Claude will interpret this"

### Phase 4 — Template Library

- Starter templates for common use cases: travel planning, client management, writing projects, financial analysis, software development
- Offered contextually when a project is opened and no context file exists
- Templates are starting points, not rigid structures

## Dependencies

- experience/02-project-workspace.md (project model — context files are per-project)
- architecture/06-conversation-model.md (context feeds into the ConversationEngine)
- hub/03-plugin-management.md (capability declarations in frontmatter)

## Notes

The context file is the simplest, most powerful feature in Atelier. It's what makes Claude remember you, adapt to your project, and get better over time. It's also just a text file — inspectable, editable, shareable, versionable. No magic, no lock-in.

The self-building behavior is the key to making this work for non-technical users. Your wife doesn't need to write a context file — Claude will offer to create one after she's planned a few trips.

---

*Back to [Index](../../INDEX.md)*
