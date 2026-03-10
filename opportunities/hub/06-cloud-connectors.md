# Cloud Connectors

> **Category:** Hub / Unified Experience
> **Type:** New Capability · **Priority:** High
> **Milestone:** M3 · **Status:** 🔲 Not started

---

## Problem

Atelier's capability model covers local Mac apps — things that work instantly with zero setup. But many knowledge workers live in cloud services: Gmail, Google Calendar, Slack, Notion, Linear. Cowork ships 10+ cloud connectors with inline OAuth. Atelier has no story for cloud services.

## Solution

### Principle: local-first, cloud-optional

Cloud connectors follow the same capability model as local apps, but backed by external MCP servers. When Claude detects an intent:

1. **Local capability available?** Use it. Zero latency, works offline.
2. **No local, but cloud connector available?** Suggest connecting: "I can send this via Gmail if you connect your account."
3. **Both available?** Prefer local, but remember the user's per-project preference.

The user never thinks about "local vs. cloud." They say "send an email" and the system picks the best path.

### Never send the user to the Terminal

Every step — discovery, installation, authentication — happens inside the app with native UI. No `npm install`, no PATH variables, no config files. If it can't be done with a button tap or a browser sign-in, we haven't finished the work.

### Capability lifecycle

Available → Installing (download binary) → Installed → Authenticating (browser OAuth) → Connected → Error

Every state transition is a button tap or a browser sign-in.

### Google Workspace — first external capability

`gws` is a CLI with pre-built macOS ARM binaries that exposes Gmail, Drive, Calendar, Sheets, Docs, and Chat as an MCP server. One install, one sign-in, six services. Atelier embeds its own OAuth client ID so users never need a GCP project.

### Inline suggestion card

When Claude detects an intent, a suggestion card appears inline in the conversation showing available options — local capabilities ("Ready to use") and cloud connectors ("Sign in" / "Get"). The card is a suggestion, not a gate.

### Curated launch set

Google Workspace (6 services), Slack, Notion, Linear, Todoist. Quality over quantity — every connector must meet health standards. Never show "MCP," "connector," or "server" in the UI.

## Status

| Feature | Status |
|---------|--------|
| External capability lifecycle | 🔲 Not started |
| Google Workspace connector | 🔲 Not started |
| Inline suggestion card | 🔲 Not started |
| Registry and intent resolution | 🔲 Not started |
| Per-project preference learning | 🔲 Not started |

## Notes

The philosophy: **local-first, cloud-optional.** Cowork treats everything as a cloud connector requiring setup. Atelier's advantage is that local Mac apps work instantly — cloud connectors are for people who live in cloud ecosystems.

Never show "MCP," "plugin," "CLI," or "server" in the UI. The user sees "Gmail," "Slack," "Google Calendar" — services they already know.

---

*Back to [Index](../../INDEX.md)*
