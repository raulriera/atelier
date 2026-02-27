# Token Usage Visibility

> **Category:** Hub / Unified Experience
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical

---

## Current State (Electron / Cowork)

Opaque — users report burning through Max tier allocations ($200/month) in as few as 10–20 operations without warning. There is no real-time usage meter, no per-task cost breakdown, no spending alerts, and no way to estimate the cost of a task before executing it. This is consistently one of the top user complaints.

## Native macOS Approach

**Real-time token meter** in the UI (like a data usage widget). Per-task cost estimation before execution. Budget alerts and configurable spending limits. Historical usage charts.

### Implementation Strategy

- **Token meter widget:** A persistent, compact widget in Atelier's toolbar showing: tokens used / total allocation for the billing period, a progress bar with color coding (green → yellow → orange → red), and estimated remaining tasks at current usage rate.
- **Pre-execution estimates:** Before starting a task, show an estimated token cost based on: input size (file count, total bytes), task complexity (simple organization vs. multi-step analysis), model selection (Opus vs. Sonnet sub-agents), and historical data from similar past tasks.
- **Per-task accounting:** After each task completes, show a detailed breakdown: input tokens, output tokens, sub-agent usage, total cost equivalent.
- **Budget alerts:** Configurable thresholds: "Alert me at 50%, 75%, 90% usage." Delivered via native notifications (critical alert at 90%).
- **Spending limits:** Optional hard limit: "Stop executing tasks after X tokens." Prevents unexpected billing surprises.
- **Historical charts:** Recharts-style usage charts (implemented natively with Swift Charts) showing daily/weekly/monthly usage trends, per-category breakdowns (file org vs. document gen vs. analysis), and cost efficiency over time.
- **Menu bar display:** Token usage visible in the menu bar agent — always one glance away.

### User Flow

```
User: "Analyze all PDFs in ~/Contracts/ and create a summary spreadsheet"

App shows estimate panel:
┌─────────────────────────────────────┐
│  Estimated Usage                    │
│                                     │
│  📁 47 PDF files (~12MB total)      │
│  🤖 Lead agent: Opus               │
│  🤖 Sub-agents: ~3x Sonnet         │
│  📊 Est. tokens: ~45,000           │
│  💰 ~2.3% of monthly allocation    │
│                                     │
│  Remaining after task: ~87%         │
│                                     │
│  [Run Task]  [Adjust Settings]      │
└─────────────────────────────────────┘
```

### Key Dependencies

- Anthropic API usage tracking endpoints
- Swift Charts framework for visualization
- UserNotifications for budget alerts
- Historical usage database (SwiftData/CoreData)

---

*Back to [Index](../../INDEX.md)*
