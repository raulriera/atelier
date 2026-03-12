# Prompt Injection Defense

> **Category:** Security & Privacy
> **Type:** New Capability · **Priority:** Critical
> **Milestone:** M3 · **Status:** ✅ Done

---

## Problem

Users drag documents into conversations. Those documents can contain hidden instructions — white-on-white text in a PDF, invisible characters in a .docx, metadata fields with injected prompts. If Claude reads these without sanitization, the injected text becomes part of its instructions.

Combined with silent file access and WebFetch, this creates a complete attack chain: inject → read sensitive files → exfiltrate.

## Solution

1. **Structured wrapping** — file attachments and all capability tool output wrapped in `<untrusted_document>` tags so Claude treats external content as data, not instructions
2. **System prompt policy** — explicit instructions forbidding compliance with embedded directives found in untrusted content
3. **Invisible Unicode stripping** — `ContentSanitizer` strips zero-width characters, bidirectional overrides, tag characters, and BOM from text attachments before sending

### Defense-in-depth

Sanitization is one layer. Even if it fails:
- **Path boundary** (07) prevents reading sensitive files
- **Network isolation** (01) prevents exfiltration
- **Audit logging** (05) records everything for analysis

No single layer is sufficient. All together make successful injection require bypassing multiple independent controls.

---

*Back to [Index](../../INDEX.md)*
