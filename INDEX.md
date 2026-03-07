# Atelier — Opportunity Index

> A native macOS application replacing Claude Cowork's Electron shell. A single adaptive conversation in a window — no modes, no tabs, no sidebars. Speed and simplicity are the moats.

---

## Summary

| Metric | Count |
|--------|-------|
| **Total opportunities** | 45 |
| **Categories** | 6 (Architecture, Security, Experience, Context, Hub, macOS) |
| **Milestones** | 6 (M0–M5) |

---

## Milestones

Build order. Each milestone produces something usable and testable. Earlier milestones are smaller — start shipping fast, widen the scope as the foundation proves out.

| Milestone | Theme | Delivers |
|-----------|-------|----------|
| **M0** | Conversation | Native window, API connection, basic conversation working |
| **M1** | Safe foundation | Sandboxed execution, file sharing, network isolation, permissions, credentials |
| **M2** | The product | Project model, context files, session persistence, conversational flow |
| **M3** | Intelligence | Embedded Code terminal, approval flow, token visibility, capabilities, prompt injection defense |
| **M4** | Native power | System services, menu bar, notifications, Shortcuts, **scheduled tasks & templates** |
| **M5** | Growth & polish | Onboarding, Spotlight, drag-drop, and everything else |

---

## M0 — Conversation

Ship the core experience first: open the app, talk to Claude, get a response. Conversation-first means validating the product before the infrastructure. Container and sandbox come later.

| # | Opportunity | Type | Status | Link |
|---|-----------|------|--------|------|
| 1.1 | Application Shell | New | ✅ Done | [→](opportunities/architecture/01-application-shell.md) |
| 1.2 | Conversation & Data Model | New | ✅ Done | [→](opportunities/architecture/06-conversation-model.md) |
| 1.3 | Window & Conversation | New | ✅ Done | [→](opportunities/experience/01-window-conversation.md) |
| 1.P | **Polish:** ~~Reading width (720pt max), minimum window size, scroll edge effect~~ | HIG | ✅ Done | — |

---

## M1 — Safe Foundation

Stand up the sandbox and lock it down. Get the container running, file sharing working, and security hardened — so M2 can open real projects safely.

| # | Opportunity | Type | Status | Link |
|---|-----------|------|--------|------|
| 2.1 | Sandboxed Execution | Improvement | 🔨 In progress | [→](opportunities/architecture/02-sandboxed-execution.md) |
| 2.2 | File Sharing (Host ↔ VM) | Improvement | 🔲 Not started | [→](opportunities/architecture/03-file-sharing.md) |
| 2.3 | Network Isolation | Improvement | 🔲 Not started | [→](opportunities/security/01-network-isolation.md) |
| 2.4 | File Access Permissions | Improvement | 🔲 Not started | [→](opportunities/security/02-file-access-permissions.md) |
| 2.5 | File Deletion Safety | New | 🔲 Not started | [→](opportunities/security/06-file-deletion-safety.md) |
| 2.6 | Credential Storage | Improvement | 🔲 Not started | [→](opportunities/security/04-credential-storage.md) |
| 2.7 | CLI Filesystem Boundary | New | 🔨 In progress (Phase 1–2 ✅) | [→](opportunities/security/07-cli-filesystem-boundary.md) |

---

## M2 — The Product

With a working conversation (M0) and a safe sandbox (M1), this is where Atelier becomes a real product. Open projects, context files, persistent sessions, and rich inline content.

| # | Opportunity | Type | Status | Link |
|---|-----------|------|--------|------|
| 3.1 | Project Workspace | New | ✅ Done | [→](opportunities/experience/02-project-workspace.md) |
| 3.2 | Project Context Files | New | ✅ Done | [→](opportunities/context/01-project-context-files.md) |
| 3.3 | Session Persistence | New | ✅ Done | [→](opportunities/architecture/04-session-persistence.md) |
| 3.4 | Conversational Flow | New | ✅ Done | [→](opportunities/experience/03-conversational-flow.md) |
| 3.5 | Living Context | New | 🔨 In progress (Phase 1–2 ✅) | [→](opportunities/context/05-living-context.md) |
| 3.6 | Hooks Infrastructure | New | 🔨 In progress (Phase 1–3 ✅) | [→](opportunities/architecture/09-hooks-infrastructure.md) |
| 3.7 | Session Browser | New | 🔲 Not started | [→](opportunities/experience/05-session-browser.md) |
| 3.P | **Polish:** ~~Status icon pairings~~ | HIG | ✅ Done | — |

---

## M3 — Intelligence

The features that make Atelier smart — embedded Claude Code, approval gates, cost awareness, capabilities (built-in MCP servers, on-demand activation), and prompt injection defense.

| # | Opportunity | Type | Status | Link |
|---|-----------|------|--------|------|
| 4.1 | Claude Code Integration | New | 🔨 In progress | [→](opportunities/hub/01-claude-code-integration.md) |
| 4.2 | Approval & Review Flow | New | ✅ Done | [→](opportunities/context/04-approval-review-flow.md) |
| 4.3 | Token Usage Visibility | New | ✅ Done | [→](opportunities/hub/05-token-usage-visibility.md) |
| 4.4 | Capabilities | New | 🔨 In progress | [→](opportunities/hub/03-plugin-management.md) |
| 4.5 | Cloud Connectors | New | 🔲 Not started | [→](opportunities/hub/06-cloud-connectors.md) |
| 4.6 | Prompt Injection Defense | New | 🔲 Not started | [→](opportunities/security/03-prompt-injection-defense.md) |
| 4.7 | MCP Helper Kit | Improvement | 🔲 Not started | [→](opportunities/architecture/08-mcp-helper-kit.md) |
| 4.P | **Polish:** ~~Evaluate system Liquid Glass button styles for approval actions~~ | HIG | ✅ Done | — |

---

## M4 — Native Power

macOS differentiation. These are the features that make people say "this could only exist on Mac."

| # | Opportunity | Type | Status | Link |
|---|-----------|------|--------|------|
| 5.1 | System Services | New | 🔲 Not started | [→](opportunities/macos/01-system-services.md) |
| 5.2 | Menu Bar Agent | New | 🔲 Not started | [→](opportunities/macos/05-menu-bar-agent.md) |
| 5.3 | Rich Notifications | Improvement | 🔲 Not started | [→](opportunities/macos/07-notifications.md) |
| 5.4 | Shortcuts & Automation | New | 🔲 Not started | [→](opportunities/macos/06-shortcuts-automation.md) |
| 5.5 | Memory Management | Improvement | 🔲 Not started | [→](opportunities/architecture/05-memory-management.md) |
| 5.6 | Scheduled Tasks & Templates | New | 🔲 Not started | [→](opportunities/context/02-task-templates-workflows.md) |

---

## M5 — Growth & Polish

Expand the product surface. Chat integration, onboarding, workflows, and all the quality-of-life integrations.

| # | Opportunity | Type | Status | Link |
|---|-----------|------|--------|------|
| 6.1 | Onboarding & Setup | New | 🔲 Not started | [→](opportunities/experience/04-onboarding.md) |
| 6.2 | File System Events | New | 🔲 Not started | [→](opportunities/macos/08-file-system-events.md) |
| ~~6.3~~ | ~~Capabilities~~ | — | — | Moved to M3 (4.4) |
| 6.4 | Capability Health | Improvement | 🔲 Not started | [→](opportunities/hub/04-mcp-connector-health.md) |
| 6.5 | Multi-Agent Orchestration | Improvement | 🔲 Not started | [→](opportunities/context/03-multi-agent-orchestration.md) |
| 6.6 | Spotlight & System Search | New | 🔲 Not started | [→](opportunities/macos/02-spotlight-search.md) |
| 6.7 | Drag & Drop | New | 🔲 Not started | [→](opportunities/macos/03-drag-and-drop.md) |
| 6.8 | Clipboard Integration | New | 🔲 Not started | [→](opportunities/macos/09-clipboard-integration.md) |
| 6.9 | Document Generation | Improvement | 🔲 Not started | [→](opportunities/macos/10-document-generation.md) |
| 6.10 | Quick Look Previews | New | 🔲 Not started | [→](opportunities/macos/04-quick-look-previews.md) |
| 6.11 | Audit & Compliance | New | 🔲 Not started | [→](opportunities/security/05-audit-compliance.md) |
| 6.12 | Desktop Widgets | New | 🔲 Not started | [→](opportunities/macos/11-widgets.md) |
| 6.13 | Focus Filters | New | 🔲 Not started | [→](opportunities/macos/12-focus-filters.md) |

---

## Unscheduled / Cross-Cutting

Opportunities tracked in the repo but not yet assigned to a numbered milestone.

| # | Opportunity | Type | Status | Link |
|---|-----------|------|--------|------|
| U1 | Async File I/O on Hot Paths | Technical Debt | 🔲 Not started | [→](opportunities/architecture/07-async-file-io.md) |
| U2 | Task Tracking (TodoWrite) | Bug | 🔴 Broken | [→](opportunities/hub/07-task-tracking.md) |
| U3 | Multi-Window Session Isolation | Bug | 🔨 In progress (fix implemented) | [→](opportunities/architecture/10-multi-window-isolation.md) |

---

## Categories (by folder)

For browsing by domain rather than build order.

### Architecture (`opportunities/architecture/`)
The foundation — native app shell, VM execution, file sharing, sessions, memory.

| File | Milestone |
|------|-----------|
| [01-application-shell.md](opportunities/architecture/01-application-shell.md) | M0 |
| [02-sandboxed-execution.md](opportunities/architecture/02-sandboxed-execution.md) | M1 |
| [03-file-sharing.md](opportunities/architecture/03-file-sharing.md) | M1 |
| [04-session-persistence.md](opportunities/architecture/04-session-persistence.md) | M2 |
| [05-memory-management.md](opportunities/architecture/05-memory-management.md) | M4 |
| [06-conversation-model.md](opportunities/architecture/06-conversation-model.md) | M0 |
| [07-async-file-io.md](opportunities/architecture/07-async-file-io.md) | — |
| [08-mcp-helper-kit.md](opportunities/architecture/08-mcp-helper-kit.md) | M3 |
| [09-hooks-infrastructure.md](opportunities/architecture/09-hooks-infrastructure.md) | M2 |
| [10-multi-window-isolation.md](opportunities/architecture/10-multi-window-isolation.md) | — |

### Security (`opportunities/security/`)
Network isolation, file permissions, prompt injection, credentials, audit, deletion safety.

| File | Milestone |
|------|-----------|
| [01-network-isolation.md](opportunities/security/01-network-isolation.md) | M1 |
| [02-file-access-permissions.md](opportunities/security/02-file-access-permissions.md) | M1 |
| [03-prompt-injection-defense.md](opportunities/security/03-prompt-injection-defense.md) | M3 |
| [04-credential-storage.md](opportunities/security/04-credential-storage.md) | M1 |
| [05-audit-compliance.md](opportunities/security/05-audit-compliance.md) | M5 |
| [06-file-deletion-safety.md](opportunities/security/06-file-deletion-safety.md) | M1 |
| [07-cli-filesystem-boundary.md](opportunities/security/07-cli-filesystem-boundary.md) | M1 |

### Experience (`opportunities/experience/`)
The product UX — window & conversation, project model, conversational flow, onboarding.

| File | Milestone |
|------|-----------|
| [01-window-conversation.md](opportunities/experience/01-window-conversation.md) | M0 |
| [02-project-workspace.md](opportunities/experience/02-project-workspace.md) | M2 |
| [03-conversational-flow.md](opportunities/experience/03-conversational-flow.md) | M2 |
| [04-onboarding.md](opportunities/experience/04-onboarding.md) | M5 |
| [05-session-browser.md](opportunities/experience/05-session-browser.md) | M2 |

### Context (`opportunities/context/`)
Project context files, templates, multi-agent visibility, approval flow.

| File | Milestone |
|------|-----------|
| [01-project-context-files.md](opportunities/context/01-project-context-files.md) | M2 |
| [02-task-templates-workflows.md](opportunities/context/02-task-templates-workflows.md) | M4 |
| [03-multi-agent-orchestration.md](opportunities/context/03-multi-agent-orchestration.md) | M5 |
| [04-approval-review-flow.md](opportunities/context/04-approval-review-flow.md) | M3 |
| [05-living-context.md](opportunities/context/05-living-context.md) | M2 |

### Hub (`opportunities/hub/`)
Code integration, capabilities, capability health, token usage.

| File | Milestone |
|------|-----------|
| [01-claude-code-integration.md](opportunities/hub/01-claude-code-integration.md) | M3 |
| [03-plugin-management.md](opportunities/hub/03-plugin-management.md) | M3 |
| [04-mcp-connector-health.md](opportunities/hub/04-mcp-connector-health.md) | M5 |
| [05-token-usage-visibility.md](opportunities/hub/05-token-usage-visibility.md) | M3 |
| [06-cloud-connectors.md](opportunities/hub/06-cloud-connectors.md) | M3 |
| [07-task-tracking.md](opportunities/hub/07-task-tracking.md) | — |

### macOS Integration (`opportunities/macos/`)
System services, Spotlight, drag-drop, menu bar, Shortcuts, FSEvents, clipboard, document generation, widgets, Focus filters.

| File | Milestone |
|------|-----------|
| [01-system-services.md](opportunities/macos/01-system-services.md) | M4 |
| [02-spotlight-search.md](opportunities/macos/02-spotlight-search.md) | M5 |
| [03-drag-and-drop.md](opportunities/macos/03-drag-and-drop.md) | M5 |
| [04-quick-look-previews.md](opportunities/macos/04-quick-look-previews.md) | M5 |
| [05-menu-bar-agent.md](opportunities/macos/05-menu-bar-agent.md) | M4 |
| [06-shortcuts-automation.md](opportunities/macos/06-shortcuts-automation.md) | M4 |
| [07-notifications.md](opportunities/macos/07-notifications.md) | M4 |
| [08-file-system-events.md](opportunities/macos/08-file-system-events.md) | M5 |
| [09-clipboard-integration.md](opportunities/macos/09-clipboard-integration.md) | M5 |
| [10-document-generation.md](opportunities/macos/10-document-generation.md) | M5 |
| [11-widgets.md](opportunities/macos/11-widgets.md) | M5 |
| [12-focus-filters.md](opportunities/macos/12-focus-filters.md) | M5 |

---

## Directory Structure

```
atelier/
├── CLAUDE.md
├── INDEX.md                              ← You are here
├── .claude/
│   └── settings.json
└── opportunities/
    ├── architecture/
    │   ├── 01-application-shell.md
    │   ├── 02-sandboxed-execution.md
    │   ├── 03-file-sharing.md
    │   ├── 04-session-persistence.md
    │   ├── 05-memory-management.md
    │   ├── 06-conversation-model.md
    │   ├── 07-async-file-io.md
    │   ├── 08-mcp-helper-kit.md
    │   ├── 09-hooks-infrastructure.md
    │   └── 10-multi-window-isolation.md
    ├── security/
    │   ├── 01-network-isolation.md
    │   ├── 02-file-access-permissions.md
    │   ├── 03-prompt-injection-defense.md
    │   ├── 04-credential-storage.md
    │   ├── 05-audit-compliance.md
    │   ├── 06-file-deletion-safety.md
    │   └── 07-cli-filesystem-boundary.md
    ├── experience/
    │   ├── 01-window-conversation.md
    │   ├── 02-project-workspace.md
    │   ├── 03-conversational-flow.md
    │   ├── 04-onboarding.md
    │   └── 05-session-browser.md
    ├── context/
    │   ├── 01-project-context-files.md
    │   ├── 02-task-templates-workflows.md
    │   ├── 03-multi-agent-orchestration.md
    │   ├── 04-approval-review-flow.md
    │   └── 05-living-context.md
    ├── hub/
    │   ├── 01-claude-code-integration.md
    │   ├── 03-plugin-management.md
    │   ├── 04-mcp-connector-health.md
    │   ├── 05-token-usage-visibility.md
    │   ├── 06-cloud-connectors.md
    │   └── 07-task-tracking.md
    └── macos/
        ├── 01-system-services.md
        ├── 02-spotlight-search.md
        ├── 03-drag-and-drop.md
        ├── 04-quick-look-previews.md
        ├── 05-menu-bar-agent.md
        ├── 06-shortcuts-automation.md
        ├── 07-notifications.md
        ├── 08-file-system-events.md
        ├── 09-clipboard-integration.md
        ├── 10-document-generation.md
        ├── 11-widgets.md
        └── 12-focus-filters.md
```
