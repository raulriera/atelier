# Atelier — Opportunity Index

> A comprehensive feature audit of Claude Cowork's current Electron implementation vs. what a native Swift/AppKit macOS application unlocks. Each opportunity is documented in detail with implementation strategies, dependencies, and estimated impact.

---

## Summary

| Metric | Count |
|--------|-------|
| **Total opportunities** | 30 |
| **New capabilities** (gaps in current Cowork) | 17 |
| **Improvements** (native is significantly better) | 13 |
| **Critical priority** (must ship in v1) | 10 |
| **High priority** (important for differentiation) | 13 |
| **Medium priority** (nice to have) | 6 |
| **Low priority** (future consideration) | 1 |

---

## 1. Architecture & Performance

The foundation: replacing Electron + Chromium with native Swift, and optimizing the VM layer that runs Claude Code under the hood.

| # | Opportunity | Type | Priority | Link |
|---|-----------|------|----------|------|
| 1.1 | Application Shell | Improvement | 🔴 Critical | [→ Details](opportunities/architecture/01-application-shell.md) |
| 1.2 | Sandboxed Execution | Improvement | 🔴 Critical | [→ Details](opportunities/architecture/02-sandboxed-execution.md) |
| 1.3 | File Sharing (Host ↔ VM) | Improvement | 🟠 High | [→ Details](opportunities/architecture/03-file-sharing.md) |
| 1.4 | Session Persistence | 🆕 New | 🔴 Critical | [→ Details](opportunities/architecture/04-session-persistence.md) |
| 1.5 | Memory Management | Improvement | 🟠 High | [→ Details](opportunities/architecture/05-memory-management.md) |

**Key wins:** ~75% less RAM, instant startup, sessions that survive sleep/reboot, dynamic VM memory scaling.

---

## 2. Context Control & Agent Intelligence

The #1 gap identified by professional users: Cowork lacks the precision context control that makes Claude Code powerful.

| # | Opportunity | Type | Priority | Link |
|---|-----------|------|----------|------|
| 2.1 | Project Context Files (COWORK.md) | 🆕 New | 🔴 Critical | [→ Details](opportunities/context-control/01-project-context-files.md) |
| 2.2 | Task Templates & Workflows | 🆕 New | 🟠 High | [→ Details](opportunities/context-control/02-task-templates-workflows.md) |
| 2.3 | Multi-Agent Orchestration Visibility | Improvement | 🟡 Medium | [→ Details](opportunities/context-control/03-multi-agent-orchestration.md) |
| 2.4 | Approval & Review Flow | 🆕 New | 🔴 Critical | [→ Details](opportunities/context-control/04-approval-review-flow.md) |

**Key wins:** Repeatable, consistent results via context files. Touch ID for destructive operations. Visual workflow builder with Shortcuts integration.

---

## 3. macOS Integration

The entire reason to go native — deep integration with macOS system services that Electron simply cannot access.

| # | Opportunity | Type | Priority | Link |
|---|-----------|------|----------|------|
| 3.1 | System Services | 🆕 New | 🟠 High | [→ Details](opportunities/macos-integration/01-system-services.md) |
| 3.2 | Spotlight & System Search | 🆕 New | 🟡 Medium | [→ Details](opportunities/macos-integration/02-spotlight-search.md) |
| 3.3 | Drag & Drop | 🆕 New | 🟡 Medium | [→ Details](opportunities/macos-integration/03-drag-and-drop.md) |
| 3.4 | Quick Look Previews | 🆕 New | 🟡 Low | [→ Details](opportunities/macos-integration/04-quick-look-previews.md) |
| 3.5 | Menu Bar Agent | 🆕 New | 🟠 High | [→ Details](opportunities/macos-integration/05-menu-bar-agent.md) |
| 3.6 | Shortcuts & Automation | 🆕 New | 🟠 High | [→ Details](opportunities/macos-integration/06-shortcuts-automation.md) |
| 3.7 | Rich Notifications | Improvement | 🟡 Medium | [→ Details](opportunities/macos-integration/07-notifications.md) |
| 3.8 | File System Events & Folder Watching | 🆕 New | 🟠 High | [→ Details](opportunities/macos-integration/08-file-system-events.md) |

**Key wins:** Right-click → "Process with Claude" from any app. Menu bar agent for zero-friction access. Auto-trigger workflows when files appear in watched folders. Full Shortcuts.app integration.

---

## 4. Security & Privacy

Addressing the critical vulnerabilities exposed within 48 hours of Cowork's launch, plus enterprise compliance requirements.

| # | Opportunity | Type | Priority | Link |
|---|-----------|------|----------|------|
| 4.1 | Network Isolation | Improvement | 🔴 Critical | [→ Details](opportunities/security/01-network-isolation.md) |
| 4.2 | File Access Permissions | Improvement | 🔴 Critical | [→ Details](opportunities/security/02-file-access-permissions.md) |
| 4.3 | Prompt Injection Defense | 🆕 New | 🔴 Critical | [→ Details](opportunities/security/03-prompt-injection-defense.md) |
| 4.4 | Credential Storage | Improvement | 🟠 High | [→ Details](opportunities/security/04-credential-storage.md) |
| 4.5 | Audit & Compliance | 🆕 New | 🟠 High | [→ Details](opportunities/security/05-audit-compliance.md) |

**Key wins:** Block the exfiltration attack vector. Keychain + Secure Enclave for credentials. Content sanitization pipeline for prompt injection. Compliance-ready audit logs.

---

## 5. Hub / Unified Experience

The vision: one app that unifies Chat, Cowork, and Code with shared context — not three disconnected tools.

| # | Opportunity | Type | Priority | Link |
|---|-----------|------|----------|------|
| 5.1 | Claude Code Integration | 🆕 New | 🔴 Critical | [→ Details](opportunities/hub-experience/01-claude-code-integration.md) |
| 5.2 | Claude Chat Integration | 🆕 New | 🟠 High | [→ Details](opportunities/hub-experience/02-claude-chat-integration.md) |
| 5.3 | Plugin Management | Improvement | 🟠 High | [→ Details](opportunities/hub-experience/03-plugin-management.md) |
| 5.4 | MCP Connector Health Dashboard | Improvement | 🟠 High | [→ Details](opportunities/hub-experience/04-mcp-connector-health.md) |
| 5.5 | Token Usage Visibility | 🆕 New | 🔴 Critical | [→ Details](opportunities/hub-experience/05-token-usage-visibility.md) |

**Key wins:** Embedded Claude Code terminal in the same window. Start in chat, promote to Cowork task. Real-time token meter with cost estimates before execution.

---

## 6. Document & File Handling

Making file operations safe, integrated, and delightful on macOS.

| # | Opportunity | Type | Priority | Link |
|---|-----------|------|----------|------|
| 6.1 | Document Generation | Improvement | 🟡 Medium | [→ Details](opportunities/document-handling/01-document-generation.md) |
| 6.2 | Clipboard Integration | 🆕 New | 🟡 Medium | [→ Details](opportunities/document-handling/02-clipboard-integration.md) |
| 6.3 | File Deletion Safety | 🆕 New | 🔴 Critical | [→ Details](opportunities/document-handling/03-file-deletion-safety.md) |

**Key wins:** Never permanently delete — always Trash + APFS snapshots. ⌘Z undo for file operations. Process clipboard contents via global hotkey.

---

## Recommended v1 Scope (Critical Items)

These 10 items form the minimum viable Atelier:

1. **Application Shell** — SwiftUI/AppKit replacing Electron
2. **Sandboxed Execution** — Direct Virtualization.framework from Swift
3. **Session Persistence** — Background tasks + Launch Agent
4. **Project Context Files** — COWORK.md system
5. **Approval & Review Flow** — Touch ID + diff previews
6. **Network Isolation** — Block exfiltration vectors
7. **File Access Permissions** — Sandbox + audit trail
8. **Prompt Injection Defense** — Content sanitization pipeline
9. **Claude Code Integration** — Embedded terminal, shared context
10. **Token Usage Visibility** — Real-time meter + cost estimates

---

## Directory Structure

```
atelier/
├── INDEX.md                              ← You are here
└── opportunities/
    ├── architecture/
    │   ├── 01-application-shell.md
    │   ├── 02-sandboxed-execution.md
    │   ├── 03-file-sharing.md
    │   ├── 04-session-persistence.md
    │   └── 05-memory-management.md
    ├── context-control/
    │   ├── 01-project-context-files.md
    │   ├── 02-task-templates-workflows.md
    │   ├── 03-multi-agent-orchestration.md
    │   └── 04-approval-review-flow.md
    ├── macos-integration/
    │   ├── 01-system-services.md
    │   ├── 02-spotlight-search.md
    │   ├── 03-drag-and-drop.md
    │   ├── 04-quick-look-previews.md
    │   ├── 05-menu-bar-agent.md
    │   ├── 06-shortcuts-automation.md
    │   ├── 07-notifications.md
    │   └── 08-file-system-events.md
    ├── security/
    │   ├── 01-network-isolation.md
    │   ├── 02-file-access-permissions.md
    │   ├── 03-prompt-injection-defense.md
    │   ├── 04-credential-storage.md
    │   └── 05-audit-compliance.md
    ├── hub-experience/
    │   ├── 01-claude-code-integration.md
    │   ├── 02-claude-chat-integration.md
    │   ├── 03-plugin-management.md
    │   ├── 04-mcp-connector-health.md
    │   └── 05-token-usage-visibility.md
    └── document-handling/
        ├── 01-document-generation.md
        ├── 02-clipboard-integration.md
        └── 03-file-deletion-safety.md
```
