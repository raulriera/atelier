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
  - `hub/` — Code/Chat integration, capabilities, capability health, token usage
  - `macos/` — System services, Spotlight, drag-drop, menu bar, Shortcuts, FSEvents, clipboard, document generation

## Code structure

Xcode project for the app, independent SPM packages for libraries:

```
Atelier/
├── Atelier.xcodeproj/            ← App target (SwiftUI app, imports libraries)
├── Atelier/                      ← App sources (AtelierApp.swift, ContentView.swift, Assets)
├── AtelierTests/                 ← App unit tests
├── AtelierUITests/               ← App UI tests
├── Packages/
│   ├── AtelierDesign/            ← Design system package
│   │   ├── Package.swift
│   │   ├── Sources/AtelierDesign/
│   │   │   ├── Tokens/           ← Spacing, Radii, Motion, ShapeStyles
│   │   │   ├── Typography/       ← Font extensions
│   │   │   ├── Styles/           ← ButtonStyle, LabelStyle conformances
│   │   │   ├── Containers/       ← ViewModifier containers (tinted, plain, card, system)
│   │   │   ├── Components/       ← ComposeField, SectionDivider
│   │   │   └── Resources/        ← AtelierColors.xcassets
│   │   └── Tests/AtelierDesignTests/
│   └── AtelierKit/               ← Core logic package
│       ├── Package.swift
│       ├── Sources/AtelierKit/
│       └── Tests/AtelierKitTests/
├── DESIGN.md                     ← Visual contract: principles, tokens, styles, motion
└── opportunities/                ← Planning docs
```

**Principles:**
- Business logic lives in library packages (`Packages/AtelierKit/`, `Packages/AtelierDesign/`), not in the app target
- Each library is an independent SPM package with its own Package.swift — added to Xcode as local package dependencies
- The app target lives in an Xcode project — it needs Info.plist, entitlements, signing, app sandbox
- Each library package includes its own test target — run via `swift test` from the package directory
- Use package boundaries (`public` vs default `internal`) for access control — not `private` within a single package
- One type per file. Multiple types in a file only if they are strictly related and private to each other
- Consult `DESIGN.md` before creating any new view — every token, style, and motion pattern is documented there
- This structure enables sharing logic with a potential visionOS/iPadOS port

## Platform

- **macOS 26+** (Tahoe), Apple Silicon only
- **Swift 6.2+**, Xcode 26
- Containerization via [apple/containerization](https://github.com/apple/containerization) Swift package (VM-per-container, OCI images, sub-second startup)

## Current status

Design system (`AtelierDesign`) implemented. Package builds and tests pass. Next: Xcode project + M0 app shell.

## Milestones (build order)

- **M0 — Conversation:** Native window + API connection + basic conversation
- **M1 — Safe foundation:** Sandboxed execution + file sharing + network isolation + permissions + credentials
- **M2 — The product:** Project model + context files + session persistence + conversational flow
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

### Problem-solving approach

- **NEVER reimplement system components.** `SplitView`, `NavigationStack`, `.inspector()`, `.sheet()`, `.popover()`, `.alert()`, `.confirmationDialog()`, and other built-in SwiftUI containers are ALWAYS the right choice — no custom HStack/VStack replacements, no manual reimplementations. If a system component has a bug, work around the bug with clear comments (including radar/FB numbers when available) so the workaround can be removed when Apple fixes it.
- **Search Apple documentation and built-in APIs first.** Before writing custom workarounds, check if Apple already provides a solution. Example: `WindowGroup(for:content:defaultValue:)` exists specifically for handling nil state restoration — don't reinvent it with custom BootstrapView/claiming logic.
- **Search WWDC sessions, Swift forums, and developer blogs** for known issues and patterns before guessing at solutions.
- **Don't iterate on symptoms.** When something breaks, stop and understand the root cause before writing more code. Adding band-aids on band-aids makes things worse.
- **Simplify aggressively.** If a fix requires more than ~10 lines of new code, question whether you're solving the right problem.

### Status tracking

- 🔲 Not started
- 🔨 In progress
- ✅ Done
- ⏸️ Paused
