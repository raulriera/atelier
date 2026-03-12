# Atelier — Opportunity Index

> A native macOS application replacing Claude Cowork's Electron shell. A single adaptive conversation in a window — no modes, no tabs, no sidebars. Speed and simplicity are the moats.
>
> **Competitive reality:** Cowork already has scheduled tasks with full MCP access, cloud connectors (Calendar, Gmail, Drive, DocuSign), and a plugin marketplace. Atelier competes on native speed, resource efficiency, macOS integration (Services, Shortcuts, Spotlight, widgets, Focus filters), and background execution via launchd. If it's not faster or more native, it has no reason to exist.

---

## Milestones

Build order. Each milestone produces something usable and testable.

| Milestone | Theme | Delivers |
|-----------|-------|----------|
| **M0** | Conversation | Native window, API connection, basic conversation working |
| **M1** | Safe foundation | CLI filesystem boundary, file permissions, hooks, path guard |
| **M2** | The product | Project model, context files, session persistence, conversational flow |
| **M3** | Intelligence | Approval flow, token visibility, capabilities, prompt injection defense |
| **M4** | Native power | System services, menu bar, notifications, Shortcuts, scheduled tasks |
| **M5** | Growth & polish | Onboarding, Spotlight, drag-drop, and everything else |

---

## M0 — Conversation ✅

All done: Application Shell, Conversation Model, Window & Conversation, polish (reading width, min window size, scroll edge).

| Opportunity | Link |
|-------------|------|
| Application Shell | [→](opportunities/architecture/01-application-shell.md) |
| Conversation & Data Model | [→](opportunities/architecture/06-conversation-model.md) |
| Window & Conversation | [→](opportunities/experience/01-window-conversation.md) |

---

## M1 — Safe Foundation ✅

All done: File Access Permissions, File Deletion Safety, CLI Filesystem Boundary.

| Opportunity | Status | Link |
|-------------|--------|------|
| File Access Permissions | ✅ Done | [→](opportunities/security/02-file-access-permissions.md) |
| File Deletion Safety | ✅ Done | [→](opportunities/security/06-file-deletion-safety.md) |
| CLI Filesystem Boundary | ✅ Done | [→](opportunities/security/07-cli-filesystem-boundary.md) |
| Credential Storage | 🔲 Not started | [→](opportunities/security/04-credential-storage.md) |

---

## M2 — The Product ✅

All done: Project Workspace, Context Files, Session Persistence, Conversational Flow, Living Context, Hooks Infrastructure, Session Browser, polish (status icon pairings).

| Opportunity | Link |
|-------------|------|
| Project Workspace | [→](opportunities/experience/02-project-workspace.md) |
| Project Context Files | [→](opportunities/context/01-project-context-files.md) |
| Session Persistence | [→](opportunities/architecture/04-session-persistence.md) |
| Conversational Flow | [→](opportunities/experience/03-conversational-flow.md) |
| Living Context | [→](opportunities/context/05-living-context.md) |
| Hooks Infrastructure | [→](opportunities/architecture/09-hooks-infrastructure.md) |
| Session Browser | [→](opportunities/experience/05-session-browser.md) |

---

## M3 — Intelligence

| Opportunity | Status | Link |
|-------------|--------|------|
| Claude Code Integration | ✅ Done | [→](opportunities/hub/01-claude-code-integration.md) |
| Approval & Review Flow | ✅ Done | [→](opportunities/context/04-approval-review-flow.md) |
| Token Usage Visibility | ✅ Done | [→](opportunities/hub/05-token-usage-visibility.md) |
| Capabilities | ✅ Done | [→](opportunities/hub/03-plugin-management.md) |
| Cloud Connectors | 🔲 Not started | [→](opportunities/hub/06-cloud-connectors.md) |
| Prompt Injection Defense | ✅ Done | [→](opportunities/security/03-prompt-injection-defense.md) |
| MCP Helper Kit | ✅ Done | [→](opportunities/architecture/08-mcp-helper-kit.md) |

---

## M4 — Native Power

| Opportunity | Status | Link |
|-------------|--------|------|
| System Services | 🔲 Not started | [→](opportunities/macos/01-system-services.md) |
| Menu Bar Agent | 🔲 Not started | [→](opportunities/macos/05-menu-bar-agent.md) |
| Rich Notifications | 🔲 Not started | [→](opportunities/macos/07-notifications.md) |
| Shortcuts & Automation | 🔲 Not started | [→](opportunities/macos/06-shortcuts-automation.md) |
| Memory Management | 🔲 Not started | [→](opportunities/architecture/05-memory-management.md) |
| Scheduled Tasks & Templates | 🔨 In progress (data+UI+scheduler helper done, blocked on template save UI + Shortcuts) | [→](opportunities/context/02-task-templates-workflows.md) |

---

## M5 — Growth & Polish

| Opportunity | Status | Link |
|-------------|--------|------|
| Onboarding & Setup | 🔲 Not started | [→](opportunities/experience/04-onboarding.md) |
| File System Events | 🔲 Not started | [→](opportunities/macos/08-file-system-events.md) |
| Capability Health | 🔲 Not started | [→](opportunities/hub/04-mcp-connector-health.md) |
| Multi-Agent Orchestration | 🔲 Not started | [→](opportunities/context/03-multi-agent-orchestration.md) |
| Spotlight & System Search | 🔲 Not started | [→](opportunities/macos/02-spotlight-search.md) |
| Drag & Drop | 🔨 In progress | [→](opportunities/macos/03-drag-and-drop.md) |
| Clipboard Integration | 🔲 Not started | [→](opportunities/macos/09-clipboard-integration.md) |
| Document Generation | 🔲 Not started | [→](opportunities/macos/10-document-generation.md) |
| Quick Look Previews | 🔲 Not started | [→](opportunities/macos/04-quick-look-previews.md) |
| Audit & Compliance | 🔲 Not started | [→](opportunities/security/05-audit-compliance.md) |
| Desktop Widgets | 🔲 Not started | [→](opportunities/macos/11-widgets.md) |
| Focus Filters | 🔲 Not started | [→](opportunities/macos/12-focus-filters.md) |

---

## Unscheduled

| Opportunity | Status | Link |
|-------------|--------|------|
| Async File I/O on Hot Paths | 🔲 Not started | [→](opportunities/architecture/07-async-file-io.md) |
| Task Tracking (TodoWrite) | ✅ Done | [→](opportunities/hub/07-task-tracking.md) |
| Multi-Window Session Isolation | ✅ Done | [→](opportunities/architecture/10-multi-window-isolation.md) |
