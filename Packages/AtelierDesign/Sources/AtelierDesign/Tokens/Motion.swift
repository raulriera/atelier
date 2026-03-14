import SwiftUI

/// Motion vocabulary for the conversation timeline.
///
/// Every element has a defined entrance, state change, and exit.
/// See DESIGN.md for the full motion rules and anti-patterns.
///
/// ## Rules
/// - **Enter with spring** — alive, physical, has weight.
/// - **Settle with ease-out** — comfortable, reaches equilibrium.
/// - **Exit with opacity** — quiet, doesn't compete for attention.
/// - **Morph, don't swap** — labels, icons, states transition smoothly.
/// - **Scale delight to rarity** — streaming text (constant) = subtle 80ms fade;
///   approval card (occasional) = spring entrance.
/// - **Respect `accessibilityReduceMotion`** — SwiftUI handles this automatically.
@MainActor
public enum Motion {

    // MARK: - Curves

    /// Elements entering the timeline — alive, with weight.
    public static let appear: Animation = .spring(duration: 0.3, bounce: 0.15)

    /// Reaching equilibrium after a change.
    public static let settle: Animation = .easeOut(duration: 0.2)

    /// Streaming text chunks — fast, unobtrusive.
    public static let streaming: Animation = .easeIn(duration: 0.08)

    /// Label and state morphs — smooth, spring-based.
    public static let morph: Animation = .spring(duration: 0.25, bounce: 0.1)

    // MARK: - Transitions

    /// New messages entering the conversation timeline.
    public static let timelineInsert: AnyTransition = .move(edge: .bottom)
        .combined(with: .opacity)

    /// Cards appearing in the timeline.
    public static let cardReveal: AnyTransition = .scale(scale: 0.95)
        .combined(with: .opacity)

    /// Approval cards — push in from bottom, fade out.
    public static let approvalAppear: AnyTransition = .asymmetric(
        insertion: .push(from: .bottom),
        removal: .opacity
    )

    /// Inspector panel — slides in from trailing edge, slides out.
    public static let inspectorSlide: AnyTransition = .move(edge: .trailing)
}
