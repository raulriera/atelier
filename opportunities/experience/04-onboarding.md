# Onboarding & Setup

> **Category:** Experience
> **Type:** 🆕 New Capability · **Priority:** 🟠 High

---

## Problem

Getting started with Claude's tools today requires multiple disconnected setup steps: create an account, get an API key, install Cowork, install Claude Code separately, configure MCP servers via JSON files, grant folder permissions one at a time. Each tool has its own auth flow. Power users tolerate this; everyone else bounces.

## Solution

A single guided setup flow that gets you from launch to first useful interaction in under 2 minutes:

### First Launch Flow
1. **Sign in** — Anthropic account or API key. Single auth for all modes.
2. **Open a project** — Select a folder (or skip for general chat). Atelier scans for existing context files (CLAUDE.md, COWORK.md, .git) and shows what it found.
3. **Security preferences** — Quick picker for approval level: Cautious (approve everything), Balanced (approve destructive ops), Autonomous (trust the agent). Can change per-project later.
4. **Ready** — Drop into the project with a welcome message that reflects what was discovered ("I see this is a Swift project with 3 packages. Here's what I can help with...").

### Migration
- Detect existing Claude Code installations and offer to import CLAUDE.md files
- Detect existing Cowork sessions and offer to import history
- Detect existing MCP server configs and offer to migrate

### Progressive Feature Discovery
- Don't show everything on day one
- Surface macOS integration features contextually ("Tip: you can right-click any text in other apps to send it to Claude")
- Keyboard shortcut hints appear during relevant actions, then fade after a few uses

## Implementation

### Phase 1 — Auth & Project Setup
- `ASWebAuthenticationSession` for OAuth, or manual API key entry with validation
- Keychain storage for credentials from the start
- Folder picker with Security-Scoped Bookmark creation

### Phase 2 — Project Detection
- Scan selected folder for: .git, CLAUDE.md, COWORK.md, package.json, Package.swift, Cargo.toml, etc.
- Generate project summary using Claude (optional, with user consent)
- Store project metadata

### Phase 3 — Migration
- Scan for existing `~/.claude/` configuration
- Parse existing MCP server JSON configs
- Import conversation history from Cowork's Electron storage

## Dependencies

- experience/02-project-workspace.md (project model to set up)
- security/04-credential-storage.md (Keychain for auth)

## Notes

Onboarding is the first impression. It should feel native-Mac: clean, fast, no wizards with 10 steps. Think of how Xcode handles "Open a project" — you pick a folder and you're working.

---

*Back to [Index](../../INDEX.md)*
