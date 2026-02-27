# Application Shell

> **Category:** Architecture & Performance
> **Type:** Improvement · **Priority:** 🔴 Critical

---

## Current State (Electron / Cowork)

Electron (Chromium wrapper) — high RAM usage (~500MB+), slow startup, non-native UI rendering. The Claude Desktop app is confirmed to be built with Electron by Boris Cherny, a Claude Code team engineer. This means every instance runs a full Chromium browser engine alongside Atelierlication logic, resulting in a heavy memory footprint, sluggish launch times, and a UI that doesn't match macOS conventions (no native menu behaviors, no system font rendering, no respect for Reduce Motion or other accessibility settings).

## Native macOS Approach

**SwiftUI / AppKit** — native rendering engine, ~50–80% less RAM, instant startup, full respect for system accessibility and appearance settings.

### Implementation Strategy

- **UI Layer:** SwiftUI for the conversational interface, settings, and dashboards. AppKit bridging (via `NSViewRepresentable`) for advanced controls like the embedded terminal view and custom text editors.
- **Rendering:** Native Metal-backed rendering via SwiftUI — no Chromium overhead. Text rendering uses CoreText, matching system fonts and Dynamic Type.
- **Accessibility:** Automatic VoiceOver support, Reduce Motion, Increase Contrast, and all macOS accessibility features come free with native controls.
- **Appearance:** Automatic Dark Mode, accent color, sidebar tinting, and vibrancy (`NSVisualEffectView`) — Atelier looks like it belongs on macOS.
- **Launch time:** Ateliers launch in <1 second vs. 3–5 seconds for Electron.

### Estimated Impact

| Metric | Electron | Native | Improvement |
|--------|----------|--------|-------------|
| Cold launch | 3–5s | <1s | ~80% faster |
| Idle RAM | ~500MB+ | ~80–120MB | ~75% less |
| Scroll/animation | 30–60fps | 120fps (ProMotion) | Buttery smooth |
| Battery drain | High (Chromium) | Low (Metal) | Significant |

### Key Dependencies

- Swift 6.2+, macOS 26 minimum deployment target (aligned with Containerization framework requirement)
- SwiftUI for primary UI, AppKit for specialized views
- Combine / async-await for reactive data flow

### Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| SwiftUI maturity gaps for complex layouts | AppKit bridging for edge cases |
| Loss of cross-platform code sharing | Isolate platform-agnostic logic into a Swift package; share with potential visionOS/iPadOS port |
| Smaller talent pool than web devs | Core architecture can be designed by 2–3 senior Swift engineers |

---

*Back to [Index](../../INDEX.md)*
