# Menu Bar Agent

> **Category:** macOS Integration
> **Type:** New Capability · **Priority:** High
> **Milestone:** M4 · **Status:** 🔲 Not started

---

## Problem

To interact with Claude, users must bring the full app window to the foreground. This is disruptive when working in other applications — sometimes you just want to ask a quick question without leaving what you're doing.

## Solution

A menu bar icon that provides quick access to Claude from anywhere — without opening a full project window.

### What it does

- **Status indicator** — shows whether Claude is idle, working, or needs attention (waiting for approval)
- **Quick conversation** — click the icon (or global hotkey) to open a popover with a text field. Ask a question, get an answer. No project context — just a quick chat
- **Active session status** — see which project windows have active work, one-click jump to any of them
- **Token usage glance** — current billing period usage, always one look away
- **Drag-drop target** — drag files onto the icon to start a conversation with those files as context

### What it doesn't do

No "mini app in the menu bar." The menu bar agent is a quick access point, not a replacement for project windows. If you need to do real work, the full window is one click away.

The menu bar agent is the lightest possible entry point to Claude. It respects the document-based window model — it's a doorbell, not a room.

---

*Back to [Index](../../INDEX.md)*
