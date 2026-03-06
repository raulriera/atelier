# Focus Filters

> **Category:** macOS Integration
> **Type:** New Capability · **Priority:** Low
> **Milestone:** M5

---

## Problem

When users enable a Focus mode (Work, Personal, Do Not Disturb, or a custom Focus), Atelier has no way to adapt its behavior. All notifications fire regardless of context, and all projects are equally visible — even when a user's "Personal" Focus has nothing to do with their work projects.

## Solution

Implement `SetFocusFilterIntent` via the App Intents framework so users can configure per-Focus behavior directly in System Settings > Focus.

### What it filters

**Notifications**
- Filter notifications by project — e.g., "Work" Focus only surfaces notifications from work-related projects
- Filter by severity — allow only approval-needed and error notifications during "Do Not Disturb," suppress completions and status updates
- Pair with `UNNotificationCategory` interrupt levels: critical alerts (destructive operations) always break through

**Projects**
- Filter which projects appear in the menu bar agent's active list
- Optionally hide project windows not matching the current Focus (via `NSWindow.isExcludedFromWindowsMenu`)

**Widgets**
- WidgetKit natively supports Focus filtering — widgets can show only Focus-relevant projects

### Implementation

```
// FocusFilter.swift — App Intents extension

struct AtelierFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Atelier"
    static var description: IntentDescription = "Choose which Atelier projects and notifications appear during this Focus."

    @Parameter(title: "Projects")
    var allowedProjects: [ProjectEntity]?

    @Parameter(title: "Notification Level", default: .all)
    var notificationLevel: NotificationFilterLevel

    func perform() async throws -> some IntentResult {
        AtelierFocusState.shared.update(
            allowedProjects: allowedProjects,
            notificationLevel: notificationLevel
        )
        return .result()
    }
}
```

- **App Intents framework** — `SetFocusFilterIntent` conformance surfaces Atelier in System Settings > Focus > Focus Filters
- **ProjectEntity** — `AppEntity` conformance on the project model so users can pick specific projects in the Focus configuration UI
- **Notification gating** — before posting any `UNNotificationRequest`, check `AtelierFocusState` to decide whether it should be delivered
- **Widget filtering** — pass the active Focus filter context to `TimelineProvider` so widgets render only relevant projects

### What it doesn't do

No automatic Focus activation. Atelier doesn't switch the user's Focus mode — it only responds to whatever Focus the user has set. The user stays in control.

## Dependencies

- macos/06-shortcuts-automation.md (App Intents framework — Focus Filters are a specialization of App Intents)
- macos/07-notifications.md (notification categories and interrupt levels must exist first)
- macos/11-widgets.md (widget filtering is a natural extension)

## Notes

Focus Filters are nearly free once App Intents and notifications are in place. The implementation is a single `SetFocusFilterIntent` conformance plus a lightweight state object that other subsystems check. Small surface area, big native-feel payoff — Atelier behaves like a first-class citizen of the Focus system instead of an app that ignores it.

---

*Back to [Index](../../INDEX.md)*
