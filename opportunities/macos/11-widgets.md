# Desktop Widgets

> **Category:** macOS Integration
> **Type:** New Capability · **Priority:** Medium
> **Milestone:** M5

---

## Problem

Atelier runs in the background for long tasks — processing documents, waiting for approvals, managing token budgets. Users have no ambient visibility into what's happening without switching to the app or checking the menu bar.

## Solution

WidgetKit widgets for the macOS desktop and Notification Center, providing at-a-glance status without any app switching.

### Widget families

**Small — Active Status**
- Current project name and session state (idle / working / needs attention)
- Token usage ring (percentage of budget consumed)
- Tap to open the active project window

**Medium — Project Summary**
- Active project with current task description
- Token usage bar with remaining budget
- Last activity timestamp
- Quick action button: "New Conversation"

**Large — Multi-Project Dashboard**
- Up to 3 active projects with status indicators
- Aggregated token usage across all projects
- Pending approval count with "Review" deep link
- Recent completions list

### Implementation

- **WidgetKit extension** — separate target in the Xcode project, shares data via App Group container
- **Timeline provider** — `TimelineProvider` with `.atEnd` reload policy; push updates via `WidgetCenter.shared.reloadAllTimelines()` when session state changes
- **Data sharing** — `AppGroupStore` (or shared `UserDefaults` suite) writes lightweight status snapshots from the main app; widget reads them
- **Deep links** — each widget action uses `widgetURL` or `Link` to open the relevant project window via the app's URL scheme
- **Interactivity** — use interactive widgets (Button/Toggle in widget) for quick actions like pausing a task or dismissing a notification, without opening the app

### What it doesn't do

No conversation UI in the widget. No streaming responses. Widgets are read-only status surfaces with lightweight actions — the menu bar popover and project windows handle real interaction.

## Dependencies

- architecture/01-application-shell.md (app must be running or have background refresh)
- hub/05-token-usage-visibility.md (token data model to surface in widgets)
- macos/05-menu-bar-agent.md (complementary — menu bar for interaction, widgets for ambient awareness)

## Notes

Widgets are the lowest-friction way to keep Atelier visible on the desktop. They complement the menu bar agent: the menu bar is for quick interaction, widgets are for passive awareness. Together they make Atelier feel present without demanding attention.

---

*Back to [Index](../../INDEX.md)*
