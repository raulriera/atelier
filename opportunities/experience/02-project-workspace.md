# Project Workspace

> **Category:** Experience
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical
> **Milestone:** M2

---

## Problem

Cowork has no concept of a "project." Every session starts from scratch — you pick a folder, grant access, explain what you're working on. There's no memory between sessions. If you work on the same codebase every day, you repeat yourself every day.

Claude Code solves this with CLAUDE.md files, but Cowork doesn't read them. Chat doesn't know about either. Nothing connects.

## Solution

A project is the fundamental unit of organization in Atelier:

**A project = a folder + context + sessions + settings.**

- **Open a folder** → a new window appears with the project loaded. Atelier auto-detects existing CLAUDE.md, COWORK.md, .git, package.json, etc. and tells you what it found.
- **Every window is a project.** The conversation, the files, the settings — all scoped to this folder, in this window.
- **Context is inherited.** Every new session in a project starts with that project's context files already loaded. No re-explanation.
- **Settings are per-project.** Approval levels, allowed tools, network rules, MCP connectors — configured once, remembered across sessions.
- **Recent projects live in File → Open Recent.** Standard macOS document behavior. `⌘⇧O` quick-opens any project by name.

### Project lifecycle

1. **Open** — `⌘O` to select a folder, or drag onto dock icon. A new window opens.
2. **Discover** — Atelier scans the folder and tells you what it found. No wizard, no multi-step setup.
3. **Work** — Conversations accumulate, context builds over time.
4. **Return** — File → Open Recent, or `⌘⇧O`. The project opens exactly where you left off.

### Who uses projects?

Projects aren't just for developers. A writer opens their manuscript folder. A researcher opens their papers folder. An analyst opens their data folder. Atelier adapts its initial summary and capabilities to what it finds — not everyone sees `.git` and "3 targets."

## Implementation

### Phase 1 — Project Model

- `Project` as an `@Observable class`: root path, display name, icon, creation date, last opened, detected type
- Security-Scoped Bookmarks for persistent folder access across launches
- Project metadata stored in `~/.atelier/projects/` (or in `.atelier/` within the project folder)
- Auto-detection: scan for CLAUDE.md, COWORK.md, .git, and common file types to determine project kind (code, writing, research, mixed)

### Phase 2 — Window Lifecycle

- Each project opens in its own `Window` via `openWindow(value:)` or a document-based scene
- Window restoration: reopening Atelier restores all previously open project windows
- `⌘⇧O` quick-open with fuzzy matching on project name and path
- Drag folder onto Atelier dock icon to open as new project window

### Phase 3 — Per-Project Settings

- Settings pane scoped to project: approval levels, network rules, allowed tools
- Override hierarchy: global defaults → project settings → session overrides
- Export/import project config for team sharing

## Dependencies

- architecture/01-application-shell.md (window shell)
- experience/01-window-conversation.md (window-per-project model)
- context/01-project-context-files.md (COWORK.md discovery)

## Notes

This is what makes Atelier feel like *your* workspace rather than a chat window with extra steps. The project model is the connective tissue between every other feature. But it should never feel like "project management" — opening a folder and starting to talk should be all it takes.

---

## Current Implementation Status

> ✅ **Core project workspace architecture is implemented and in use.**

What's now implemented:
- `Project` model and `ProjectStore` registry in AtelierKit
- `WindowGroup(for: UUID.self)` with per-window project identity and restoration fallback
- `Cmd+N` creates a new project window (scratch project), `Cmd+O` opens a folder as a project
- Per-project scoped state and storage:
  - Sessions in `Application Support/Atelier/projects/{projectID}/sessions/`
  - File access bookmarks in `Application Support/Atelier/projects/{projectID}/bookmarks.json`
  - Capability settings in `Application Support/Atelier/projects/{projectID}/capabilities.json`
- `ProjectWindow` flow:
  - No root folder yet → folder selection view
  - Root folder set → conversation window with project-scoped dependencies

Remaining polish from this opportunity:
1. `Cmd+Shift+O` quick-open with fuzzy project search
2. Export/import project configuration for sharing
3. Additional project discovery UX polish

---

*Back to [Index](../../INDEX.md)*
