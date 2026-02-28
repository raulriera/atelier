# Atelier — Opportunity Index

> A native macOS application replacing Claude Cowork's Electron shell. A single adaptive conversation in a window — no modes, no tabs, no sidebars. Speed and simplicity are the moats.

---

## Summary

| Metric | Count |
|--------|-------|
| **Total opportunities** | 35 |
| **Categories** | 5 (Architecture, Security, Experience, Context, macOS) |
| **Milestones** | 6 (M0–M5) |

---

## Milestones

Build order. Each milestone produces something usable and testable. Earlier milestones are smaller — start shipping fast, widen the scope as the foundation proves out.

| Milestone | Theme | Delivers |
|-----------|-------|----------|
| **M0** | Skeleton | Native window, basic VM, files move between host and VM |
| **M1** | Safe foundation | Network locked down, file permissions, deletion safety, credentials in Keychain |
| **M2** | The product | Window & conversation, project model, context files, sessions survive reboot |
| **M3** | Intelligence | Embedded Code terminal, approval flow, token visibility, prompt injection defense |
| **M4** | Native power | System services, menu bar, notifications, Shortcuts |
| **M5** | Growth & polish | Chat integration, onboarding, workflows, Spotlight, drag-drop, everything else |

---

## M0 — Skeleton

Prove the architecture works. De-risk first: get the VM running, then file sharing, then wrap it in the real app shell.

| # | Opportunity | Type | Status | Link |
|---|-----------|------|--------|------|
| 1.1 | Sandboxed Execution | Improvement | 🔨 In progress | [→](opportunities/architecture/02-sandboxed-execution.md) |
| 1.2 | File Sharing (Host ↔ VM) | Improvement | 🔲 Not started | [→](opportunities/architecture/03-file-sharing.md) |
| 1.3 | Application Shell | Improvement | 🔲 Not started | [→](opportunities/architecture/01-application-shell.md) |

---

## M1 — Safe Foundation

Harden the sandbox before exposing it to user workloads. No one should use Atelier and lose data or leak secrets.

| # | Opportunity | Type | Status | Link |
|---|-----------|------|--------|------|
| 2.1 | Network Isolation | Improvement | 🔲 Not started | [→](opportunities/security/01-network-isolation.md) |
| 2.2 | File Access Permissions | Improvement | 🔲 Not started | [→](opportunities/security/02-file-access-permissions.md) |
| 2.3 | File Deletion Safety | New | 🔲 Not started | [→](opportunities/security/06-file-deletion-safety.md) |
| 2.4 | Credential Storage | Improvement | 🔲 Not started | [→](opportunities/security/04-credential-storage.md) |

---

## M2 — The Product

This is where Atelier stops being a tech demo and becomes a product. The window, the conversation, the project model, context files, and persistent sessions.

| # | Opportunity | Type | Status | Link |
|---|-----------|------|--------|------|
| 3.1 | Window & Conversation | New | 🔲 Not started | [→](opportunities/experience/01-window-conversation.md) |
| 3.2 | Project Workspace | New | 🔲 Not started | [→](opportunities/experience/02-project-workspace.md) |
| 3.3 | Project Context Files (COWORK.md) | New | 🔲 Not started | [→](opportunities/context/01-project-context-files.md) |
| 3.4 | Session Persistence | New | 🔲 Not started | [→](opportunities/architecture/04-session-persistence.md) |
| 3.5 | Conversation & Data Model | New | 🔲 Not started | [→](opportunities/architecture/06-conversation-model.md) |

---

## M3 — Intelligence

The features that make Atelier smart — embedded Claude Code, approval gates, cost awareness, and prompt injection defense.

| # | Opportunity | Type | Status | Link |
|---|-----------|------|--------|------|
| 4.1 | Claude Code Integration | New | 🔲 Not started | [→](opportunities/hub/01-claude-code-integration.md) |
| 4.2 | Approval & Review Flow | New | 🔲 Not started | [→](opportunities/context/04-approval-review-flow.md) |
| 4.3 | Token Usage Visibility | New | 🔲 Not started | [→](opportunities/hub/05-token-usage-visibility.md) |
| 4.4 | Prompt Injection Defense | New | 🔲 Not started | [→](opportunities/security/03-prompt-injection-defense.md) |

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

---

## M5 — Growth & Polish

Expand the product surface. Chat integration, onboarding, workflows, and all the quality-of-life integrations.

| # | Opportunity | Type | Status | Link |
|---|-----------|------|--------|------|
| 6.1 | Claude Chat Integration | New | 🔲 Not started | [→](opportunities/hub/02-claude-chat-integration.md) |
| 6.2 | Conversational Flow | New | 🔲 Not started | [→](opportunities/experience/03-conversational-flow.md) |
| 6.3 | Onboarding & Setup | New | 🔲 Not started | [→](opportunities/experience/04-onboarding.md) |
| 6.4 | Task Templates & Workflows | New | 🔲 Not started | [→](opportunities/context/02-task-templates-workflows.md) |
| 6.5 | File System Events | New | 🔲 Not started | [→](opportunities/macos/08-file-system-events.md) |
| 6.6 | Plugin Management | Improvement | 🔲 Not started | [→](opportunities/hub/03-plugin-management.md) |
| 6.7 | MCP Connector Health | Improvement | 🔲 Not started | [→](opportunities/hub/04-mcp-connector-health.md) |
| 6.8 | Multi-Agent Orchestration | Improvement | 🔲 Not started | [→](opportunities/context/03-multi-agent-orchestration.md) |
| 6.9 | Spotlight & System Search | New | 🔲 Not started | [→](opportunities/macos/02-spotlight-search.md) |
| 6.10 | Drag & Drop | New | 🔲 Not started | [→](opportunities/macos/03-drag-and-drop.md) |
| 6.11 | Clipboard Integration | New | 🔲 Not started | [→](opportunities/macos/09-clipboard-integration.md) |
| 6.12 | Document Generation | Improvement | 🔲 Not started | [→](opportunities/macos/10-document-generation.md) |
| 6.13 | Quick Look Previews | New | 🔲 Not started | [→](opportunities/macos/04-quick-look-previews.md) |
| 6.14 | Audit & Compliance | New | 🔲 Not started | [→](opportunities/security/05-audit-compliance.md) |

---

## Categories (by folder)

For browsing by domain rather than build order.

### Architecture (`opportunities/architecture/`)
The foundation — native app shell, VM execution, file sharing, sessions, memory.

| File | Milestone |
|------|-----------|
| [01-application-shell.md](opportunities/architecture/01-application-shell.md) | M0 |
| [02-sandboxed-execution.md](opportunities/architecture/02-sandboxed-execution.md) | M0 |
| [03-file-sharing.md](opportunities/architecture/03-file-sharing.md) | M0 |
| [04-session-persistence.md](opportunities/architecture/04-session-persistence.md) | M2 |
| [05-memory-management.md](opportunities/architecture/05-memory-management.md) | M4 |
| [06-conversation-model.md](opportunities/architecture/06-conversation-model.md) | M2 |

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

### Experience (`opportunities/experience/`)
The product UX — window & conversation, project model, conversational flow, onboarding.

| File | Milestone |
|------|-----------|
| [01-window-conversation.md](opportunities/experience/01-window-conversation.md) | M2 |
| [02-project-workspace.md](opportunities/experience/02-project-workspace.md) | M2 |
| [03-conversational-flow.md](opportunities/experience/03-conversational-flow.md) | M5 |
| [04-onboarding.md](opportunities/experience/04-onboarding.md) | M5 |

### Context (`opportunities/context/`)
Project context files, templates, multi-agent visibility, approval flow.

| File | Milestone |
|------|-----------|
| [01-project-context-files.md](opportunities/context/01-project-context-files.md) | M2 |
| [02-task-templates-workflows.md](opportunities/context/02-task-templates-workflows.md) | M5 |
| [03-multi-agent-orchestration.md](opportunities/context/03-multi-agent-orchestration.md) | M5 |
| [04-approval-review-flow.md](opportunities/context/04-approval-review-flow.md) | M3 |

### Hub (`opportunities/hub/`)
Code/Chat integration, plugins, MCP health, token usage.

| File | Milestone |
|------|-----------|
| [01-claude-code-integration.md](opportunities/hub/01-claude-code-integration.md) | M3 |
| [02-claude-chat-integration.md](opportunities/hub/02-claude-chat-integration.md) | M5 |
| [03-plugin-management.md](opportunities/hub/03-plugin-management.md) | M5 |
| [04-mcp-connector-health.md](opportunities/hub/04-mcp-connector-health.md) | M5 |
| [05-token-usage-visibility.md](opportunities/hub/05-token-usage-visibility.md) | M3 |

### macOS Integration (`opportunities/macos/`)
System services, Spotlight, drag-drop, menu bar, Shortcuts, FSEvents, clipboard, document generation.

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
    │   └── 06-conversation-model.md
    ├── security/
    │   ├── 01-network-isolation.md
    │   ├── 02-file-access-permissions.md
    │   ├── 03-prompt-injection-defense.md
    │   ├── 04-credential-storage.md
    │   ├── 05-audit-compliance.md
    │   └── 06-file-deletion-safety.md
    ├── experience/
    │   ├── 01-window-conversation.md
    │   ├── 02-project-workspace.md
    │   ├── 03-conversational-flow.md
    │   └── 04-onboarding.md
    ├── context/
    │   ├── 01-project-context-files.md
    │   ├── 02-task-templates-workflows.md
    │   ├── 03-multi-agent-orchestration.md
    │   └── 04-approval-review-flow.md
    ├── hub/
    │   ├── 01-claude-code-integration.md
    │   ├── 02-claude-chat-integration.md
    │   ├── 03-plugin-management.md
    │   ├── 04-mcp-connector-health.md
    │   └── 05-token-usage-visibility.md
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
        └── 10-document-generation.md
```
