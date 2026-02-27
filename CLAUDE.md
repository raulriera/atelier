# Atelier

A native macOS application (Swift/AppKit) replacing Claude Cowork's Electron shell. The goal is deep macOS integration, better security, and a unified hub for Chat, Cowork, and Code — things Electron fundamentally cannot deliver.

## Project structure

- `INDEX.md` — Master index organized by milestones (M0–M5), with status tracking
- `opportunities/` — Detailed write-ups for each opportunity, grouped by domain:
  - `architecture/` — App shell, VM execution, file sharing, sessions, memory
  - `security/` — Network isolation, file permissions, prompt injection, credentials, audit, deletion safety
  - `experience/` — Hub navigation, project workspace, conversational flow, onboarding
  - `context/` — Project context files, templates, multi-agent visibility, approvals
  - `hub/` — Code/Chat integration, plugins, MCP health, token usage
  - `macos/` — System services, Spotlight, drag-drop, menu bar, Shortcuts, FSEvents, clipboard, document generation

## Current status

Planning phase — milestones defined, opportunity audit complete. No code yet.

## Milestones (build order)

- **M0 — Skeleton:** Native window + basic VM + file sharing
- **M1 — Safe foundation:** Network isolation + file permissions + deletion safety + credentials
- **M2 — The product:** Hub navigation + project model + context files + session persistence
- **M3 — Intelligence:** Code integration + approval flow + token visibility + prompt injection defense
- **M4 — Native power:** System services + menu bar + notifications + Shortcuts + memory management
- **M5 — Growth & polish:** Chat integration, onboarding, workflows, Spotlight, drag-drop, and remaining items

## Conventions

- Opportunity files use markdown with consistent structure (Problem, Solution, Implementation, Dependencies, Priority)
- Status tracking uses: 🔲 Not started, 🔨 In progress, ✅ Done, ⏸️ Paused
- When editing opportunity files, preserve the existing markdown structure
- Categories are organized by domain; milestones define build order
