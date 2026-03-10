# Focus Filters

> **Category:** macOS Integration
> **Type:** New Capability · **Priority:** Low
> **Milestone:** M5 · **Status:** 🔲 Not started

---

## Problem

When users enable a Focus mode (Work, Personal, Do Not Disturb), Atelier has no way to adapt. All notifications fire regardless, and all projects are equally visible — even irrelevant ones.

## Solution

**`SetFocusFilterIntent`** via App Intents: users configure per-Focus behavior directly in System Settings.

### What it filters

- **Notifications** — filter by project and severity. Critical alerts (destructive operations) always break through.
- **Projects** — filter which projects appear in the menu bar and window list.
- **Widgets** — WidgetKit natively supports Focus filtering, showing only relevant projects.

### What it doesn't do

No automatic Focus activation. Atelier responds to whatever Focus the user has set — it doesn't try to change it.

Nearly free once App Intents and notifications are in place. Small surface area, big native-feel payoff — Atelier behaves like a first-class citizen of the Focus system.

---

*Back to [Index](../../INDEX.md)*
