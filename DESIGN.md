# Design System

The visual contract for Atelier. Every view, every component, every animation references this document.

## Principles

Inspired by [Benji Taylor](https://benji.org)'s work on Honk, Family, Liveline, and cmdk. Credit to his writing on [Honkish](https://benji.org/honkish) and [Family Values](https://benji.org/family-values) for articulating these ideas.

### 1. Simplicity, Fluidity, Delight

Three pillars from Family's design philosophy. Fundamentals at your fingertips, everything else appears as it becomes relevant. Each transition feels like a natural progression. Deliberately crafted moments that make interactions memorable.

### 2. One Thing Breathing

From Liveline: "the chart as one thing breathing rather than a bunch of parts updating independently." The conversation timeline should feel like a single living entity — messages, cards, progress indicators all part of the same flow, not discrete widgets bolted together.

### 3. Delight Inversely Correlates with Frequency

Rare events get more personality. Frequent interactions get subtle polish.

| Frequency | Example | Motion |
|-----------|---------|--------|
| Constant | Streaming text | Quiet 80ms fade-in |
| Frequent | New message lands | Soft spring settle |
| Occasional | New session starts | Warm spring entrance |
| Rare | First capability enabled | Celebratory moment |

Repeating the same delight animation dulls it. Scale personality to rarity.

### 4. No Static Transitions

"Even minor UI elements animate to reinforce user actions and prevent disorientation." Nothing should pop into existence. Nothing should vanish. Everything enters, settles, and exits with purpose. A button label changing from "Send" to "Cancel" should morph, not snap.

### 5. Tactile Satisfaction

Every action should feel physically rewarding. Visual feedback confirms user intent immediately. The send button compresses on press. A message landing in the timeline has weight. An approval card has presence.

### 6. Calibrated Information Density

"How much context you need depends entirely on the problem." A simple chat message needs minimal chrome. A diff review needs syntax highlighting and line numbers. An approval needs a clear description and one-tap action. Show the right amount for the situation — never more, never less.

### 7. Gradual Revelation

"Like seeing parts of a room through an open doorway." The interface unfolds progressively — identical to our progressive disclosure principle, but applied to animation too. A card doesn't dump all its content at once; it appears compact and expands on interaction.

---

## Tokens

### Colors — ShapeStyle extensions

Colors are exposed as `ShapeStyle` extensions, not a parallel namespace. This integrates natively with `.foregroundStyle()`, `.background()`, and `.fill()`.

Custom surface colors live in the `AtelierColors` asset catalog. Every color must provide four variants: light, dark, light + increased contrast, dark + increased contrast. The increased contrast variants must provide significantly higher visual differentiation — not just a minor tweak. This is required by the [HIG](https://developer.apple.com/design/human-interface-guidelines/color) for Liquid Glass adaptivity and the Increase Contrast accessibility setting. ShapeStyle conformances wrap them for type safety.

**Surfaces** (backgrounds):

| Token | Usage |
|-------|-------|
| `.surfaceDefault` | Default window/view background |
| `.surfaceTinted` | User messages, active elements |
| `.surfaceElevated` | Cards, popovers, elevated content |
| `.surfaceOverlay` | Overlays, dimming layers |

**Content** (foreground):

| Token | Usage |
|-------|-------|
| `.contentPrimary` | Main text, headings |
| `.contentSecondary` | Captions, metadata, timestamps |
| `.contentTertiary` | Placeholders, disabled text |
| `.contentAccent` | Interactive elements, links (system accent color) |

**Status** — never rely on color alone ([HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility)). Every status indicator must pair its color with a distinct icon or text label so the state is perceivable without color vision.

| Token | Usage | Required pairing |
|-------|-------|-----------------|
| `.statusSuccess` | Completed actions, positive states | Checkmark icon or "Done" label |
| `.statusWarning` | Caution states, budget alerts | Warning triangle icon or descriptive label |
| `.statusError` | Failed actions, destructive states | X-circle icon or error description |

**Usage:**
```swift
.foregroundStyle(.contentPrimary)
.background(.surfaceTinted)
.fill(.statusSuccess)
```

### Typography — Font extensions

Extend `Font` directly with semantic roles mapped to system text styles. macOS does not support Dynamic Type — text does not scale with a system setting. However, using system text styles ensures correct weight, size, and tracking, and prepares for a potential iPadOS/visionOS port where Dynamic Type applies.

| Token | Base | Usage |
|-------|------|-------|
| `.conversationBody` | `.body` | Message text |
| `.conversationCode` | `.body.monospaced()` | Inline code, code blocks |
| `.cardTitle` | `.headline` | Card headings, file names |
| `.cardBody` | `.subheadline` | Card descriptions |
| `.sectionTitle` | `.title3` | Section labels |
| `.tokenCount` | `.caption2.monospacedDigit()` | Token/cost display |
| `.metadata` | `.caption` | Timestamps, secondary info |

**Usage:**
```swift
.font(.conversationBody)
.font(.tokenCount)
```

### Spacing

A 4-point grid. Seven values cover every use case.

| Token | Value | Usage |
|-------|-------|-------|
| `Spacing.xxs` | 4pt | Tight gaps (icon–label) |
| `Spacing.xs` | 8pt | Related element spacing |
| `Spacing.sm` | 12pt | Compact padding |
| `Spacing.md` | 16pt | Standard padding, card insets |
| `Spacing.lg` | 24pt | Section spacing |
| `Spacing.xl` | 32pt | Major section breaks |
| `Spacing.xxl` | 48pt | Full-width breathing room |

**Usage:**
```swift
.padding(Spacing.md)
VStack(spacing: Spacing.sm) { }
```

### Radii

Always paired with `.continuous` corner style (Apple's superellipse).

| Token | Value | Usage |
|-------|-------|-------|
| `Radii.sm` | 6pt | Small elements, badges |
| `Radii.md` | 10pt | Cards, containers |
| `Radii.lg` | 16pt | Large cards, panels |

**Usage:**
```swift
.clipShape(.rect(cornerRadius: Radii.md, style: .continuous))
```

### Motion

Motion is where "one thing breathing" becomes real. Every timeline element has a defined entrance, state change, and exit.

**Curves:**

| Token | Definition | Usage |
|-------|------------|-------|
| `Motion.appear` | `.spring(duration: 0.3, bounce: 0.15)` | Elements entering the timeline |
| `Motion.settle` | `.easeOut(duration: 0.2)` | Reaching equilibrium |
| `Motion.streaming` | `.easeIn(duration: 0.08)` | Streaming text chunks |
| `Motion.morph` | `.spring(duration: 0.25, bounce: 0.1)` | Label/state changes |

**Transitions:**

| Token | Definition | Usage |
|-------|------------|-------|
| `Motion.timelineInsert` | Move from bottom + opacity | New messages entering |
| `Motion.cardReveal` | Scale from 0.95 + opacity | Cards appearing |
| `Motion.approvalAppear` | Push from bottom (in), opacity (out) | Approval cards |

**Motion rules:**
- **Enter with spring** — alive, physical, has weight (principle 5)
- **Settle with ease-out** — comfortable, reaches equilibrium (principle 4)
- **Exit with opacity** — quiet, doesn't compete for attention
- **Morph, don't swap** — labels, icons, states transition smoothly (principle 4)
- **Scale delight to rarity** — see principle 3 table above
- **Respect `accessibilityReduceMotion`** — SwiftUI handles this automatically

**Anti-patterns:**
- ❌ Stacking modals that demand sequential attention
- ❌ Raw JSON / technical details shown to the user
- ❌ Identical repeated UI with no differentiation
- ❌ Jarring appearance with no transition
- ✅ Inline cards that flow into the timeline with spring animation
- ✅ Human-readable descriptions with one-tap actions
- ✅ Related approvals grouped into a single card
- ✅ Cards that settle into the timeline and wait patiently

---

## Styles

### ButtonStyle

macOS 26 system Liquid Glass button styles. No custom `ButtonStyle` conformances needed — the system handles sizing, background, and interaction effects.

| Style | Usage |
|-------|-------|
| `.glassProminent` | Primary actions: Send, Approve |
| `.glass(.clear)` | Secondary actions: Cancel, Dismiss |
| `.glass` | In-card actions: Add Folder, View Diff |
| `.plain` | Icon-only buttons (no glass chrome) |

```swift
Button("Send") { }.buttonStyle(.glassProminent)
Button("Cancel") { }.buttonStyle(.glass(.clear))
Button("View Diff") { }.buttonStyle(.glass)
```

### LabelStyle

| Style | API | Usage |
|-------|-----|-------|
| `.caption` | `CaptionLabelStyle` | Muted icon + text for metadata |

```swift
Label("847 tokens", systemImage: "number").labelStyle(.caption)
```

---

## Containers

View modifiers that apply padding, background, and corner radius. Clean defaults — visual refinement happens in Xcode with live previews.

| Modifier | Background | Padding | Usage |
|----------|------------|---------|-------|
| `.tintedContainer()` | `.surfaceTinted` | 12H / 8V | User messages |
| `.plainContainer()` | None | 12H / 8V | Assistant messages |
| `.cardContainer()` | `.surfaceElevated` | 12pt | File cards, approvals, elevated content |
| `.systemContainer()` | None (text styling only) | — | System/status messages |

```swift
Text(message.text).tintedContainer()
VStack { diffView }.cardContainer()
```

---

## Components

### ComposeField

The message input. TextEditor with placeholder, submit button, and auto-grow behavior.

```swift
ComposeField(text: $draft, placeholder: "Message Claude...") {
    sendMessage()
}
```

### SectionDivider

Styled divider between conversation sections.

```swift
SectionDivider()
```

---

## Layout

The conversation timeline must look great from the narrowest useful window to full-screen ultrawide. The HIG says: *"Support arbitrary window sizes. Allow people to resize their window to the width and height that works for them, and adjust your content accordingly."*

### Reading width

Unbounded text lines are hard to read. The timeline content (messages, cards, system events) has a maximum reading width that keeps line lengths comfortable.

| Token | Value | Usage |
|-------|-------|-------|
| `Layout.readingWidth` | 720pt | Maximum width for timeline content |
| `Layout.minimumWindowWidth` | 420pt | Minimum usable window width |
| `Layout.minimumWindowHeight` | 480pt | Minimum usable window height |

The timeline is always horizontally centered in the available space. At narrow widths it fills the window with horizontal padding; beyond `readingWidth` it stops growing and whitespace appears on the sides.

```
┌──────────────────────────────────────────────┐
│ toolbar (fills width)                        │
├──────────────────────────────────────────────┤
│         ┌──────────────────┐                 │
│         │  timeline        │                 │
│         │  (≤ readingWidth) │                 │
│         │  centered        │                 │
│         └──────────────────┘                 │
├──────────────────────────────────────────────┤
│         ┌──────────────────┐                 │
│         │  compose field   │                 │
│         └──────────────────┘                 │
└──────────────────────────────────────────────┘
```

### Cards

Cards (`cardContainer()`) fill the timeline width up to `readingWidth`. They never float narrower than their content and never stretch beyond the reading column.

### Inspector

The inspector panel uses SwiftUI's `.inspector()` modifier — a system-provided split view that handles resizing, collapse, and safe area automatically. It compresses the timeline in-place; it does not overlay content.

- Default width: 280pt
- Collapsible via `⌥⌘I` or toolbar button
- At narrow window widths (< ~700pt), the inspector should auto-collapse or present as a sheet to avoid crushing the timeline below usable width

### Full-screen behavior

Full-screen on large displays exaggerates the whitespace flanking the reading column. This is correct — the reading width stays fixed. The toolbar and compose field stretch to fill; the content does not. This mirrors how apps like Mail and Notes handle wide layouts.

### Minimum window size

Set via `.defaultSize()` and `.windowResizability()` in the scene declaration. The window should never shrink below `minimumWindowWidth × minimumWindowHeight` — below that, the compose field and timeline become unusable.

---

## Liquid Glass Policy

macOS 26 applies Liquid Glass automatically to navigation chrome (toolbars, tab bars). We follow Apple's guidance:

- **Navigation elements** — get Liquid Glass automatically via system styling
- **Content** — never gets Liquid Glass. Conversation text, cards, code blocks stay on solid surfaces
- **Custom chrome** — use `.glassEffect()` only for navigation-adjacent elements if needed

We don't fight the system. We don't apply glass to content.

---

## Extension Rules

When adding new tokens for future milestones:

1. **Colors** — add to `ShapeStyles.swift` + asset catalog. Use semantic names (`.surfaceCode`, not `.darkBlue`)
2. **Typography** — add to `Font+Atelier.swift`. Map to system text styles
3. **Spacing** — rarely needs extension. The 7-value scale covers most cases
4. **Motion** — add to `Motion.swift`. Document enter/settle/exit pattern
5. **Styles** — prefer system styles (`.glass`, `.glassProminent`). Only add custom conformances (`LabelStyle`, `ToggleStyle`) when no system style fits
6. **Containers** — one file per container modifier. Document intended usage

Every new token must be documented in this file before use in views.
