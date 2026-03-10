# Audit & Compliance

> **Category:** Security & Privacy
> **Type:** New Capability · **Priority:** High
> **Milestone:** M5 · **Status:** 🔲 Not started

---

## Problem

Regulated industries (finance, healthcare, legal) need audit trails. Even non-regulated users benefit from knowing what Claude did — especially when tools modify files, send emails, or access external services.

## Solution

Unified audit logging via `os_log` structured events, backed by an encrypted SQLite database. Every tool call, approval decision, and capability interaction is recorded with timestamp, user, project, and outcome.

- **Export formats:** CSV, JSON, CEF, LEEF for SIEM integration
- **Configurable retention:** per-project or global policies
- **MDM integration:** enterprise deployment can enforce audit requirements
- **Hook integration:** `PostToolUse`/`PreToolUse` hooks feed the audit pipeline

## Notes

This enables Atelier for regulated workloads — a differentiator over Cowork which has no audit story.

---

*Back to [Index](../../INDEX.md)*
