# Audit & Compliance

> **Category:** Security & Privacy
> **Type:** 🆕 New Capability · **Priority:** 🟠 High

---

## Current State (Electron / Cowork)

No audit logs, no Compliance API integration, no Data Exports. Anthropic's own documentation states: "Do not use for regulated workloads." Conversation history is stored locally only. Activity is not captured in enterprise Audit Logs, Compliance API, or Data Exports — a non-starter for finance, healthcare, legal, and government teams.

## Native macOS Approach

**Unified Logging** (`os_log`) with structured audit events. Export to SIEM via `OSLogStore`. Local SQLite audit database with encryption at rest. Compliance-ready activity reports.

### Implementation Strategy

- **Structured audit log:** Every significant action is logged via `os_log` with structured metadata: timestamp, session ID, action type, file paths involved, model used, token count, approval status, and user identity.
- **Local audit database:** Mirror events to an encrypted SQLite database (`SQLCipher`) for offline querying, reporting, and compliance exports.
- **Export formats:** One-click export to CSV, JSON, or SIEM-compatible formats (CEF, LEEF). Schedule automated exports to a designated folder or network share.
- **Compliance dashboard:** A dedicated SwiftUI view showing: all file access events (who read/wrote what, when), all external API calls (which connector, what data sent), approval history (who approved what, via what method), and token usage per session/user.
- **Retention policies:** Configurable log retention (30/60/90/365 days). Automatic purging with secure deletion.
- **MDM integration:** Expose compliance settings via `com.apple.configuration.managed` so IT admins can enforce audit policies via Jamf, Mosyle, or other MDM tools.

### Key Dependencies

- `os_log` and `OSLogStore` for system logging
- SQLCipher for encrypted local database
- MDM managed app configuration support

---

*Back to [Index](../../INDEX.md)*
