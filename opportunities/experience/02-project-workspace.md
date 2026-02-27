# Project Workspace

## Type
🆕 New

## Priority
🔴 Critical

---

## Problem

Cowork has no concept of a "project." Every session starts from scratch — you pick a folder, grant access, explain what you're working on. There's no memory between sessions. If you work on the same codebase every day, you repeat yourself every day.

Claude Code solves this with CLAUDE.md files, but Cowork doesn't read them. Chat doesn't know about either. Nothing connects.

## Solution

A project is the fundamental unit of organization in Atelier:

**A project = a folder + context + sessions + settings.**

- **Open a folder** → Atelier creates/discovers a project. Auto-detects existing CLAUDE.md, COWORK.md, .git, package.json, etc. to understand what it is.
- **All sessions are scoped to a project.** Chat history, Cowork tasks, Code terminal sessions — all associated with the project, accessible from the sidebar.
- **Context is inherited.** Every new session in a project starts with that project's context files already loaded. No re-explanation.
- **Settings are per-project.** Approval levels, allowed tools, network rules, MCP connectors — configured once per project, not per session.
- **Projects live in the sidebar.** Pin frequently used ones. Recent projects show automatically. Quick-switch with `⌘⇧O`.

### Project lifecycle
1. **Open** — Select folder or drag onto dock icon
2. **Configure** — First-time setup: review detected context, set permissions, connect MCPs
3. **Work** — Sessions accumulate, context builds over time
4. **Archive** — Move to archive when done, preserving history for reference

## Implementation

### Phase 1 — Project Model
- `Project` struct: root path, display name, icon, creation date, last opened
- Security-Scoped Bookmarks for persistent folder access across launches
- Project metadata stored in `~/.atelier/projects/` (or in `.atelier/` within the project folder)
- Auto-detection: scan for CLAUDE.md, COWORK.md, .git, language files

### Phase 2 — Sidebar & Switching
- `NSOutlineView` sidebar with pinned / recent / all sections
- Quick Open (`⌘⇧O`) with fuzzy matching on project name and path
- Drag folder onto Atelier icon to open as project

### Phase 3 — Per-Project Settings
- Settings pane scoped to project: approval levels, network rules, allowed tools
- Override hierarchy: global defaults → project settings → session overrides
- Export/import project config for team sharing

## Dependencies

- architecture/01-application-shell.md (window shell)
- experience/01-hub-navigation.md (sidebar integration)
- context/01-project-context-files.md (COWORK.md discovery)

## Notes

This is what makes Atelier feel like an IDE for Claude rather than a chat window with extra steps. The project model is the connective tissue between every other feature.
