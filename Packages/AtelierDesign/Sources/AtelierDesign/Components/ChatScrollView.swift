import SwiftUI

/// Distance from the bottom edge (in points) within which the scroll
/// view is considered "at the bottom" for auto-scroll purposes.
private nonisolated let bottomThreshold: CGFloat = 80

/// A bottom-anchored scroll view for chat-style content.
///
/// Automatically scrolls to the bottom when new content arrives and the user
/// is already near the bottom. When scrolled up, a glass arrow button appears
/// to jump back down.
///
/// ```swift
/// ChatScrollView {
///     ForEach(messages) { message in
///         MessageCell(message: message)
///     }
/// }
/// ```
public struct ChatScrollView<Content: View>: View {
    @ViewBuilder let content: Content

    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    @State private var isAtBottom = true

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ScrollView {
            content
        }
        .defaultScrollAnchor(.bottom)
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            let bottomEdge = geometry.contentOffset.y + geometry.containerSize.height
            return bottomEdge >= geometry.contentSize.height - bottomThreshold
        } action: { _, newValue in
            isAtBottom = newValue
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentSize.height
        } action: { oldHeight, newHeight in
            if isAtBottom, newHeight > oldHeight {
                scrollPosition.scrollTo(edge: .bottom)
            }
        }
        // Workaround: LazyVStack does not render cells when combined with
        // .defaultScrollAnchor(.bottom). The anchor positions the viewport
        // at the bottom, but LazyVStack calculates visible cells top-down
        // and never realises content exists. When the container size changes
        // (e.g. overlay appears/dismisses, window resizes), a programmatic
        // scroll-to-bottom forces a layout pass that fixes it.
        // https://developer.apple.com/forums/thread/741406
        .onScrollGeometryChange(for: CGSize.self) { geometry in
            geometry.containerSize
        } action: { _, _ in
            if isAtBottom {
                scrollPosition.scrollTo(edge: .bottom)
            }
        }
        .overlay(alignment: .bottom) {
            Group {
                if !isAtBottom {
                    scrollToBottomButton
                        .padding(.bottom, Spacing.sm)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(Motion.morph, value: isAtBottom)
        }
    }

    private var scrollToBottomButton: some View {
        Button {
            withAnimation(Motion.morph) {
                scrollPosition.scrollTo(edge: .bottom)
            }
        } label: {
            Image(systemName: "arrow.down")
                .font(.body.weight(.semibold))
                .frame(width: 32, height: 32)
                .contentShape(.interaction, Circle())
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .buttonStyle(.plain)
    }
}

#Preview {
    ChatScrollView {
        LazyVStack {
            ForEach(0..<50, id: \.self) { i in
                Text("Message \(i)")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: i.isMultiple(of: 2) ? .leading : .trailing)
            }
        }
    }
}
