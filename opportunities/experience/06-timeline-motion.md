# Timeline Motion & Polish

> **Category:** Experience
> **Type:** Improvement · **Priority:** High
> **Milestone:** M3

---

## Problem

DESIGN.md defines a complete motion vocabulary — `Motion.appear`, `Motion.timelineInsert`, `Motion.cardReveal`, `Motion.approvalAppear`, `Motion.morph` — but almost none of it is wired up. The conversation timeline feels static: cards pop in and out instantly, state changes snap, streaming text just appends, and 30 consecutive tool calls render as 30 identical rows with no grouping.

The design principles say "No Static Transitions" and "One Thing Breathing." The current implementation violates both.

### What's broken

| Token | Defined | Wired Up |
|-------|---------|----------|
| `Motion.timelineInsert` | `.move(edge: .bottom) + .opacity` | Never applied |
| `Motion.appear` | `.spring(0.3, bounce: 0.15)` | Only ComposeField |
| `Motion.cardReveal` | `.scale(0.95) + .opacity` | On ToolUseCell/FileCard `.transition()` but never fires — no animation context |
| `Motion.approvalAppear` | `.push(from: .bottom) / .opacity` | On ApprovalCard/AskUserCard `.transition()` but never fires |
| `Motion.morph` | `.spring(0.25, bounce: 0.1)` | Only selection highlight + scroll button |

Root cause: transitions are defined on views but no `withAnimation` or `.animation(value:)` provides the animation context. Everything is instant.

## Constraints discovered during implementation

Every approach attempted in the initial implementation spike caused crashes, constraint spam, or performance regressions. These constraints must inform the next attempt.

### 1. LazyVStack + `.animation(value:)` on ForEach causes constraint loop crashes

`.animation(Motion.appear, value: items.count)` on the ForEach triggers an infinite `NSGenericException` constraint update loop: *"The window has been marked as needing another Update Constraints in Window pass, but it has already had more Update Constraints in Window passes than there are views in the window."* This is because the animation triggers layout changes in the LazyVStack, which trigger constraint updates, which loop.

**Rule:** Never use `.animation(value:)` on a ForEach inside a LazyVStack. The animation must come from somewhere else.

### 2. Self-animating transitions cause jank during rapid insertions

`.transition(.opacity.animation(Motion.settle))` on each ForEach item fires on every insertion, even without `withAnimation`. During streaming (many tool calls in quick succession), each insertion triggers an animated layout change that cascades, causing visible jank.

**Rule:** Self-animating transitions (`.transition(X.animation(Y))`) are unsuitable for high-frequency insertions like timeline items.

### 3. `withAnimation` wrapping AppKit-backed controls generates constraint spam

`withAnimation(Motion.morph)` wrapping approval decisions animates the removal of the pending card, which contains an AppKit-backed `Menu` (`.menuStyle(.glassProminent)` uses `AppKitSegmentedControlAdaptor` internally). The AppKit control can't handle intermediate sizes during the scale transition, generating hundreds of constraint warnings per animation frame. Same issue with `ProgressView().controlSize(.mini)` in ToolUseCell/FileCard.

This is a [known SwiftUI framework limitation](https://fatbobman.com/en/posts/the_animation_mechanism_of_swiftui/): *"Controls encapsulated based on UIKit (AppKit) can hardly achieve animation control."*

**Rule:** Never animate the removal of views containing AppKit-backed controls (Menu, ProgressView, Picker with `.radioGroup`). Either use asymmetric transitions with instant removal, or avoid animating those cards entirely.

### 4. Neither `.compositingGroup()`, `.drawingGroup()`, nor `.transaction { $0.disablesAnimations = true }` prevents the AppKit constraint spam

The transition operates on the parent card view. Child controls inside still get scaled frame-by-frame during removal regardless of compositing or transaction overrides.

### 5. Session is in AtelierKit (Foundation only) — no `withAnimation` access

`Session.appendItem()`, `resolveApproval()`, `resolveAskUser()`, etc. are in AtelierKit which imports Foundation, not SwiftUI. The standard pattern of wrapping state mutations in `withAnimation` at the model layer isn't possible without adding SwiftUI as a dependency to the kit package.

The alternative — wrapping in `withAnimation` at the ConversationWindow callback sites — works but propagates animation broadly, hitting the AppKit control issue (constraint 3).

## Design categories

Two distinct categories of animated content, each requiring different treatment:

| Category | Examples | Transition style |
|----------|----------|-----------------|
| **Inline cards** (in timeline) | ApprovalCard, AskUserCard, PlanReviewCard | Scale in/out (`Motion.cardReveal`) |
| **Persistent overlays** (pinned above compose) | TaskListOverlay, future: PlanOverlay, AskUserOverlay | Slide up from bottom (`Motion.approvalAppear`) |

## Possible approaches for next attempt

### Option A: Move animation context to a thin SwiftUI wrapper

Add a `TimelineAnimationCoordinator` in the app target (not AtelierKit) that observes Session changes and selectively applies `withAnimation` only for safe transitions — skipping any items with AppKit-backed controls.

### Option B: Per-item appearance animation via `@State`

Each `TimelineItemView` tracks its own `@State private var hasAppeared = false` and animates opacity/scale on `.onAppear`. No ForEach-level animation, no `withAnimation` propagation. Simple, scoped, no AppKit interaction. Doesn't handle card state morphs (approval pending→resolved), only initial appearance.

### Option C: Resolve Issue #1 first (TimelineActions environment object)

Replace closure-based callbacks with an `@Observable TimelineActions` environment object. This makes `TimelineItemView` a pure data struct that SwiftUI can diff efficiently, and gives us a central place to wrap specific actions in `withAnimation` without broad propagation.

### Option D: Accept limitations and focus on what works

Only animate things that don't involve AppKit-backed controls:
- TaskListOverlay slide (already works via `withAnimation` in its own dismiss handler)
- Token count fade-in
- Capability suggestion bar appearance
- Tool event grouping collapse/expand (Phase 4 — purely SwiftUI views, no AppKit controls)

Skip card state morphs entirely until Apple fixes AppKit control animation in SwiftUI.

## Tool event grouping (independent of animation approach)

This is the highest-impact change and has no animation dependencies. 30 consecutive tool events should collapse into one summary line regardless of whether we solve the animation problems.

- Group runs of 3+ consecutive tool events of the same type
- Summary line: tool icon + count + description ("Read 30 files")
- Collapsed by default, expand on tap
- Expand/collapse uses `withAnimation(Motion.morph)` safely (disclosure content is pure SwiftUI, no AppKit controls)

**Files:** `TimelineView.swift` (grouping logic + `CollapsedToolGroup` view)

---

*Back to [Index](../../INDEX.md)*
