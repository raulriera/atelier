# Atelier

A native macOS application replacing Claude Cowork's Electron shell. A single adaptive conversation in a window — no modes, no tabs, no sidebars. Projects are windows. The app progressively discloses complexity as the user's needs grow.

## Core principles

- **Speed is the product.** The conversation timeline must be ultra responsive. Every interaction — scrolling, typing, rendering inline cards, showing diffs — must feel instant. Measure performance continuously and steer code toward it. If it's not fast, nothing else matters.
- **Simplicity is the product.** Start with the least UI possible. A text field and a conversation. Everything else surfaces only when needed. Progressive disclosure over feature dumps.
- **Speed and simplicity are our moats.** These aren't nice-to-haves. They're the reason to exist as a native app instead of Electron. Every architectural decision should be justified by one or both.

## Project structure

- `INDEX.md` — Master index organized by milestones (M0–M5), with status tracking
- `opportunities/` — Detailed write-ups for each opportunity, grouped by domain:
  - `architecture/` — App shell, VM execution, file sharing, sessions, memory, conversation model
  - `security/` — Network isolation, file permissions, prompt injection, credentials, audit, deletion safety
  - `experience/` — Window & conversation, project workspace, conversational flow, onboarding
  - `context/` — Project context files, templates, multi-agent visibility, approvals
  - `hub/` — Code/Chat integration, plugins, MCP health, token usage
  - `macos/` — System services, Spotlight, drag-drop, menu bar, Shortcuts, FSEvents, clipboard, document generation

## Code structure

When implementation begins, the codebase follows Swift Package conventions:

```
Atelier/
├── Package.swift
├── Sources/
│   ├── Atelier/                  ← Main app target (SwiftUI app entry point)
│   ├── AtelierKit/               ← Core logic: project model, session management, container lifecycle
│   ├── ContainerService/         ← Containerization wrapper: image management, container lifecycle
│   └── SecurityService/          ← Keychain, file permissions, network isolation
├── Tests/
│   ├── AtelierKitTests/
│   ├── ContainerServiceTests/
│   └── SecurityServiceTests/
└── Resources/
```

**Principles:**
- Business logic lives in library targets (`AtelierKit`, `ContainerService`, `SecurityService`), not in the app target
- The app target (`Atelier`) is thin — just SwiftUI views wiring up the libraries
- Each library target has a matching test target
- Use package boundaries (`public` vs default `internal`) for access control — not `private` within a single package
- One type per file. Multiple types in a file only if they are strictly related and private to each other
- This structure enables sharing logic with a potential visionOS/iPadOS port

## Platform

- **macOS 26+** (Tahoe), Apple Silicon only
- **Swift 6.2+**, Xcode 26
- Containerization via [apple/containerization](https://github.com/apple/containerization) Swift package (VM-per-container, OCI images, sub-second startup)

## Current status

Planning phase — milestones defined, opportunity audit complete. No code yet.

## Milestones (build order)

- **M0 — Skeleton:** Native window + basic VM + file sharing
- **M1 — Safe foundation:** Network isolation + file permissions + deletion safety + credentials
- **M2 — The product:** Window & conversation + project model + context files + session persistence
- **M3 — Intelligence:** Code integration + approval flow + token visibility + prompt injection defense
- **M4 — Native power:** System services + menu bar + notifications + Shortcuts + memory management
- **M5 — Growth & polish:** Chat integration, onboarding, workflows, Spotlight, drag-drop, and remaining items

## Conventions

### Commits

- NEVER add `Co-Authored-By` or any AI attribution to commits
- All commits MUST use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`

**Scopes** (match the opportunity categories): `architecture`, `security`, `experience`, `context`, `hub`, `macos`

Examples:
- `docs(experience): add window & conversation opportunity`
- `feat(architecture): scaffold SwiftUI app shell`
- `fix(security): correct network isolation allowlist parsing`
- `chore: update milestone status in INDEX`

### Testing

- Every new feature or module MUST include tests
- Tests live in matching `Tests/` targets (e.g., `AtelierKitTests` for `AtelierKit`)
- Use Swift Testing (`@Test`, `#expect`) over XCTest for new tests — it's the modern framework for Swift 6.2+
- Test public API surface; don't test private implementation details
- Async code should be tested with `async` test functions
- Use protocols and dependency injection to make code testable without real containers or network calls
- Run tests with `swift test` or `xcodebuild test`

### Opportunity files

- Use markdown with consistent structure (Problem, Solution, Implementation, Dependencies, Priority)
- Preserve the existing markdown structure when editing
- Categories are organized by domain; milestones define build order

### Status tracking

- 🔲 Not started
- 🔨 In progress
- ✅ Done
- ⏸️ Paused
