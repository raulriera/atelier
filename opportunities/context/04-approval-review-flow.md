# Approval & Review Flow

> **Category:** Context Control & Agent Intelligence
> **Type:** New Capability · **Priority:** Critical
> **Milestone:** M3

---

## Problem

Every tool call is either silently approved or shows a generic permission dialog. There's no middle ground — no "notify but don't block," no risk-based escalation, no biometric gate for dangerous actions. Users either approve everything blindly or get approval fatigue.

## Solution

### Four-tier approval system

| Tier | Behavior | Example |
|------|----------|---------|
| **Silent** | Auto-approved, no UI | Read a file in the project folder |
| **Notify** | Executes, shows a notification | Web search, file creation |
| **Confirm** | Blocks until user approves | Send email, delete file, write outside project |
| **Biometric** | Requires Touch ID | Access SSH keys, send to external API |

### Inline approval cards

Approval requests appear inline in the conversation timeline — not in a modal or system dialog. Each card shows a plain-English description of what Claude wants to do, the risk level, and approve/deny buttons. Cards use the same design language as other timeline content.

### Adaptive tiers

The system learns from user behavior. If a user always approves "create file in project folder," that action can migrate from Confirm to Silent for this project. If a user denies web fetches, those stay at Confirm. Adaptation is per-project — a developer project and a personal project have different trust profiles.

---

*Back to [Index](../../INDEX.md)*
