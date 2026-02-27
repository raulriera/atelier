# Project Context Files

> **Category:** Context Control & Agent Intelligence
> **Type:** 🆕 New Capability · **Priority:** 🔴 Critical

---

## Current State (Electron / Cowork)

No equivalent to Claude Code's `CLAUDE.md`, Rules, or Skills system. Prompts in Cowork are one-off and ephemeral. Users cannot define persistent instructions, project-specific rules, or reusable context that the agent automatically loads when accessing a directory. This is the single biggest gap identified by professional users — as one agency put it: "The power of Claude Code isn't that it runs in a terminal. The power is Context Control."

## Native macOS Approach

Implement a native **`.coworkrc` / `COWORK.md`** system: per-folder instruction files that Claude auto-loads when accessing a directory. Stored as native Spotlight-indexable files with rich macOS integration.

### Implementation Strategy

- **File format:** Markdown-based `COWORK.md` files (matching Claude Code's `CLAUDE.md` convention) placed in any folder. Supports frontmatter YAML for structured config:
  ```markdown
  ---
  model: opus
  approval_required: destructive_only
  output_format: xlsx
  ---
  # Project: Q1 Financial Reports
  
  ## Context
  This folder contains monthly P&L statements in CSV format.
  Always use USD formatting with two decimal places.
  
  ## Rules
  - Never delete source CSV files
  - Output summaries to the /reports subfolder
  - Use the company template in /templates/report.xlsx
  ```
- **Auto-discovery:** When a user grants folder access, Atelier walks up the directory tree looking for `COWORK.md` files (similar to `.gitignore` resolution). Merges instructions from parent → child (child overrides parent).
- **Spotlight indexing:** Register a Spotlight importer (`mdimporter`) so users can search all their Cowork context files system-wide: "Show me all my COWORK.md files" via Spotlight or `mdfind`.
- **GUI editor:** Built-in SwiftUI editor for creating/editing `COWORK.md` files with syntax highlighting, validation, and live preview of how the instructions will be interpreted.
- **Template library:** Ship starter templates for common use cases (financial analysis, file organization, report generation, etc.).

### User Flow

```
1. User creates ~/Projects/Q1-Reports/COWORK.md
2. User asks Cowork: "Process the January data"
3. App grants access to ~/Projects/Q1-Reports/
4. App auto-discovers COWORK.md
5. Agent loads context: "This folder contains monthly P&L statements..."
6. Agent follows rules: outputs to /reports, uses template, preserves CSVs
7. Result is consistent every time, no re-explaining needed
```

### Estimated Impact

| Scenario | Current | With Context Files |
|----------|---------|-------------------|
| Repeated task on same folder | Re-explain every time | Automatic, consistent |
| Team sharing workflows | Copy-paste prompts in Slack | Share COWORK.md in git |
| Complex multi-step tasks | Unpredictable results | Guided by rules |
| Onboarding new team member | Teach them the "right prompt" | Just point them at the folder |

### Key Dependencies

- `COWORK.md` file format specification
- Spotlight importer plugin (`mdimporter`)
- SwiftUI text editor with syntax highlighting
- Directory tree walking with `FileManager.enumerator`

---

*Back to [Index](../../INDEX.md)*
