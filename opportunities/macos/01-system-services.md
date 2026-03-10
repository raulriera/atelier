# System Services

> **Category:** macOS Integration
> **Type:** New Capability · **Priority:** High
> **Milestone:** M4 · **Status:** 🔲 Not started

---

## Problem

To use Claude with text from another app, users must copy text, switch to Atelier, paste, get a result, copy it back, and switch to the original app. Six steps and two context switches for what should be one action.

## Solution

Register as a **macOS Service** via `NSServicesProvider`: select text in any app → right-click → "Process with Claude." Results replace the selection in-place — zero context switches.

- **Service actions:** Summarize, Rewrite, Translate, Analyze (opens a full session)
- **In-place replacement:** For rewrite/translate, the result replaces the selection in the source app
- **Keyboard shortcuts:** Users assign global shortcuts via System Settings → Keyboard → Services
- **Rich content:** Accepts both `NSAttributedString` and file selections

This is impossible in Electron — macOS Services require a native app bundle with `Info.plist` declarations.

---

*Back to [Index](../../INDEX.md)*
