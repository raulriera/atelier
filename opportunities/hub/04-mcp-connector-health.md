# MCP Connector Health Dashboard

> **Category:** Hub / Unified Experience
> **Type:** Improvement · **Priority:** 🟠 High

---

## Current State (Electron / Cowork)

Approximately 25% reported failure rate for connectors, with no visibility into connector status or errors. Connectors fail silently — users discover failures only when expected results don't appear. No retry mechanisms, no connection logs, and re-authentication requires navigating obscure settings.

## Native macOS Approach

**Connector dashboard** with real-time health indicators, retry queues, connection logs, and one-click re-auth. Background health checks via `URLSession` background tasks.

### Implementation Strategy

- **Health dashboard:** A dedicated SwiftUI view showing every connected MCP server as a card: connection status (green/yellow/red), last successful request timestamp, average response time, error rate over the last 24 hours, and a one-click re-authenticate button.
- **Background health checks:** Use `URLSession.shared.dataTask` with background configuration to ping each MCP server every 5 minutes. Update status silently.
- **Retry queue:** Failed MCP operations are queued for automatic retry. Users can see the queue, manually retry, or dismiss failed operations.
- **Connection logs:** Detailed logs per connector showing every request/response, latency, errors, and payload sizes. Filterable by time range and status.
- **Proactive alerts:** If a connector's health degrades (error rate >10%, latency >5s), notify the user before they encounter a failure during a task.
- **One-click re-auth:** OAuth token expiration is the most common failure. A "Re-authenticate" button opens the OAuth flow inline without leaving Atelier.

### Key Dependencies

- URLSession background tasks for health monitoring
- SwiftUI dashboard with real-time updates
- MCP server health check protocol
- OAuth re-authentication flow (ASWebAuthenticationSession)

---

*Back to [Index](../../INDEX.md)*
