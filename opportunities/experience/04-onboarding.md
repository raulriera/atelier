# Onboarding & Setup

> **Category:** Experience
> **Type:** 🆕 New Capability · **Priority:** 🟠 High

---

## Problem

Getting started with Claude's tools today requires multiple disconnected setup steps: create an account, get an API key, install Cowork, install Claude Code separately, configure MCP servers via JSON files, grant folder permissions one at a time. Each tool has its own auth flow. Power users tolerate this; everyone else bounces.

## Solution

The fastest onboarding possible: sign in and start talking.

### First Launch

1. **Sign in** — Anthropic account or API key. One step.
2. **Done.** A window opens with a greeting and a text field. Start talking.

That's it. No folder picker, no security wizard, no feature tour. You're in a conversation.

### Everything else happens naturally

- **Projects** — The first time you drag a folder onto the window or use `⌘O`, you've created a project. Atelier scans it, tells you what it found, and the conversation is now scoped. No separate "project setup" flow.
- **Permissions** — When Claude first needs to do something sensitive, you see an approval. Your response teaches the app what you trust. No upfront security preferences picker.
- **Features** — macOS integrations, keyboard shortcuts, the inspector panel — these surface through contextual hints as you use the app. "Tip: you can right-click any text in other apps to send it to Claude." They appear once, at the right moment, then fade.

### Migration

For users coming from existing tools:

- Detect existing Claude Code installations and offer to import CLAUDE.md files
- Detect existing Cowork sessions and offer to import history
- Detect existing MCP server configs and offer to migrate

Migration is offered once, on first launch, and never mentioned again.

## Implementation

### Phase 1 — Auth

- `ASWebAuthenticationSession` for OAuth, or manual API key entry with validation
- Keychain storage for credentials from the start
- On success: open a blank conversation window. No further setup.

### Phase 2 — Project Discovery (On Demand)

- Triggered when user opens a folder, not during onboarding
- Scan for: .git, CLAUDE.md, COWORK.md, and common file types (code, documents, images, data)
- Generate project summary using Claude (optional, with user consent)
- Store project metadata and Security-Scoped Bookmark

### Phase 3 — Contextual Hints

- A lightweight hint system that surfaces tips at relevant moments
- Each hint shows once (or a configurable number of times), then never again
- Hints are dismissible and the entire system can be turned off
- Examples: keyboard shortcuts during relevant actions, macOS integration features when the user could benefit from them

### Phase 4 — Migration

- Scan for existing `~/.claude/` configuration
- Parse existing MCP server JSON configs
- Import conversation history from Cowork's Electron storage
- Presented as a one-time, skippable offer

## Dependencies

- experience/02-project-workspace.md (project model, triggered later)
- security/04-credential-storage.md (Keychain for auth)

## Notes

Onboarding is the first impression. The bar is: sign in, see a window, start talking. Every additional step before that first conversation is a failure. Everything else — projects, permissions, features — arrives when the user is ready for it, not when we think they should learn it.

---

*Back to [Index](../../INDEX.md)*
