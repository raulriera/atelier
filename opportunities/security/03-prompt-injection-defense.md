# Prompt Injection Defense

> **Category:** Security & Privacy
> **Type:** New Capability · **Priority:** Critical
> **Milestone:** M3 · **Status:** 🔲 Not started

---

## Problem

Users drag documents into conversations. Those documents can contain hidden instructions — white-on-white text in a PDF, invisible characters in a .docx, metadata fields with injected prompts. If Claude reads these without sanitization, the injected text becomes part of its instructions.

Combined with silent file access and WebFetch, this creates a complete attack chain: inject → read sensitive files → exfiltrate.

## Solution

### Multi-stage sanitization pipeline

1. **Format-specific stripping** — remove hidden text layers, invisible characters, suspicious metadata from each file type before Claude sees the content
2. **Structured wrapping** — sanitized content wrapped in `<untrusted_document>` tags so Claude knows to treat it as user data, not instructions
3. **Visual verification** — for high-risk documents, OCR the rendered output and compare against extracted text to detect hidden content
4. **Heuristic detection** — flag patterns that look like prompt injection ("ignore previous instructions," "you are now...")

### Defense-in-depth

Sanitization is layer 1. Even if it fails:
- **Path boundary** (07) prevents reading sensitive files
- **Network isolation** (01) prevents exfiltration
- **Audit logging** (05) records everything for analysis

No single layer is sufficient. All together make successful injection require bypassing multiple independent controls.

---

*Back to [Index](../../INDEX.md)*
