# Conversation & Data Model

> **Category:** Architecture
> **Type:** New Capability · **Priority:** Critical
> **Milestone:** M0 · **Status:** ✅ Done

---

## Problem

The conversation timeline is the entire product surface. Every feature — chatting, task execution, file operations, approvals, results — renders into this one timeline. Without a well-defined data model, nothing else can be built.

## Solution

### Sessions within a project

A project contains multiple sessions (conversations). Each session is a self-contained timeline with its own history and context.

- Opening a project shows the most recent session
- `Cmd+N` starts a fresh session within the same project window
- Previous sessions are accessible via search or the inspector
- Project context carries across all sessions; conversation history does not leak between them

This maps to how people work: Monday's itinerary research is a different conversation than Tuesday's packing list, but they're in the same trip folder.

### Storage: files, not a database

All data is plain files — JSON for metadata, JSONL for timelines. Inspectable, portable, append-only for fast writes during streaming. No database migrations, no schema versioning. A 500-message session is a few hundred KB.

### Timeline content: tagged data

Each timeline item has a type tag and conforms to a protocol. Content types include: user messages, assistant messages, file cards, artifacts, diffs, tool uses, progress, approvals, results, and system events.

The `unknown` case is the future-proofing escape hatch — unknown content types degrade gracefully instead of crashing. New content types are added by adding a case, a struct, and a cell view.

### The drillable assistant message

An assistant message's `children` array contains the work that happened during that response — file reads, tool uses, generated artifacts. The default view shows text. Expanding reveals nested cards.

### Streaming

The engine returns an `AsyncStream` of timeline events. Text deltas grow the active message in place. Tool uses appear as children. SwiftUI re-renders minimally per delta.

### The engine abstraction

The conversation engine is a protocol. Today it wraps the Claude CLI. Tomorrow it could wrap the Claude Code SDK or something else entirely. The engine receives the message, project context, and session history, and returns a stream of events.

## Notes

This model is the spine of the entire app. The decisions here — files over database, tagged data for extensibility, sessions for conversation lifecycle — are load-bearing. The `unknown` content type case is non-negotiable.

---

*Back to [Index](../../INDEX.md)*
