# Plugin Management

> **Category:** Hub / Unified Experience
> **Type:** Improvement · **Priority:** 🟠 High

---

## Current State (Electron / Cowork)

11+ starter plugins, private enterprise marketplaces via GitHub — but management is clunky and the failure rate is approximately 25%. Plugins fail silently, there's no crash isolation (a bad plugin can destabilize the app), and no health monitoring.

## Native macOS Approach

Native plugin manager with health monitoring, auto-retry, and fallback logic. **Swift Package Manager** or **XPC-based** plugin architecture for crash isolation — a bad plugin can't take down Atelier.

### Implementation Strategy

- **XPC-based isolation:** Each plugin runs in its own XPC service process. If a plugin crashes, the main app is unaffected — the XPC service restarts automatically and the user sees a "Plugin restarted" notification.
- **Health monitoring:** Continuous health checks per plugin: response time, error rate, last successful operation, memory usage. Visualized in a SwiftUI dashboard.
- **Auto-retry with backoff:** Failed plugin operations automatically retry with exponential backoff (1s → 2s → 4s → 8s). After 3 failures, the plugin is marked degraded and the user is notified.
- **Plugin marketplace:** A native App Store-style browser for discovering, installing, and updating plugins. Ratings, reviews, and verified publisher badges.
- **Version management:** Automatic plugin updates with rollback capability. Pin specific versions for stability in enterprise environments.
- **Configuration UI:** Each plugin gets a native SwiftUI settings panel (auto-generated from a plugin manifest) — no more editing JSON config files.

### Key Dependencies

- XPC Services framework for crash isolation
- Swift Package Manager for plugin distribution
- Plugin manifest schema (JSON/YAML)

---

*Back to [Index](../../INDEX.md)*
