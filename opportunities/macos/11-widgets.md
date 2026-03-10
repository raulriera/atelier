# Desktop Widgets

> **Category:** macOS Integration
> **Type:** New Capability · **Priority:** Medium
> **Milestone:** M5 · **Status:** 🔲 Not started

---

## Problem

Atelier runs in the background for long tasks. Users have no ambient visibility into what's happening without switching to the app or checking the menu bar.

## Solution

WidgetKit widgets for the macOS desktop and Notification Center — at-a-glance status without app switching.

### Widget families

- **Small** — Active project status + token usage ring. Tap to open.
- **Medium** — Current task description, token usage bar, last activity, "New Conversation" action.
- **Large** — Up to 3 active projects, aggregated token usage, pending approval count, recent completions.

### What it doesn't do

No conversation UI in the widget. No streaming responses. Widgets are read-only status surfaces with lightweight actions — the menu bar popover and project windows handle real interaction.

Widgets complement the menu bar agent: the menu bar is for quick interaction, widgets are for passive awareness. Together they make Atelier feel present without demanding attention.

---

*Back to [Index](../../INDEX.md)*
