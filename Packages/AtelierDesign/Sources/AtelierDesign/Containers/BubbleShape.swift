import SwiftUI

/// Messages.app-style speech bubble with a curved tail protrusion.
///
/// The tail extends slightly beyond the bubble's bounding rect —
/// approximately 6pt horizontally. This is fine when used as a
/// `.background(_, in:)` shape since SwiftUI does not clip backgrounds.
///
/// - `tailEdge: .trailing` — tail at bottom-right (user / sent messages)
/// - `tailEdge: .leading`  — tail at bottom-left  (assistant / received messages)
public struct BubbleShape: Shape {
    public enum TailEdge: Sendable {
        case leading
        case trailing
    }

    public var tailEdge: TailEdge

    public init(tailEdge: TailEdge) {
        self.tailEdge = tailEdge
    }

    public func path(in rect: CGRect) -> Path {
        switch tailEdge {
        case .trailing: trailingPath(in: rect)
        case .leading:  leadingPath(in: rect)
        }
    }

    // MARK: - Trailing tail (user messages)

    private func trailingPath(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let w = rect.maxX
        let h = rect.maxY

        return Path { p in
            // Top-left corner
            p.move(to: CGPoint(x: r, y: 0))

            // Top edge → top-right corner
            p.addLine(to: CGPoint(x: w - r, y: 0))
            p.addArc(
                center: CGPoint(x: w - r, y: r), radius: r,
                startAngle: .degrees(-90), endAngle: .degrees(0),
                clockwise: false
            )

            // Right edge down to tail start
            p.addLine(to: CGPoint(x: w, y: h - 10))

            // Tail: curve outward then down to the tip
            p.addCurve(
                to: CGPoint(x: w + 6, y: h),
                control1: CGPoint(x: w, y: h - 3),
                control2: CGPoint(x: w + 6, y: h - 2)
            )

            // Tail tip: sweep back left along bottom
            p.addCurve(
                to: CGPoint(x: w - 12, y: h),
                control1: CGPoint(x: w + 2, y: h + 1),
                control2: CGPoint(x: w - 4, y: h)
            )

            // Bottom edge → bottom-left corner
            p.addLine(to: CGPoint(x: r, y: h))
            p.addArc(
                center: CGPoint(x: r, y: h - r), radius: r,
                startAngle: .degrees(90), endAngle: .degrees(180),
                clockwise: false
            )

            // Left edge → top-left corner
            p.addLine(to: CGPoint(x: 0, y: r))
            p.addArc(
                center: CGPoint(x: r, y: r), radius: r,
                startAngle: .degrees(180), endAngle: .degrees(270),
                clockwise: false
            )

            p.closeSubpath()
        }
    }

    // MARK: - Leading tail (assistant messages)

    private func leadingPath(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let w = rect.maxX
        let h = rect.maxY

        return Path { p in
            // Top-right corner
            p.move(to: CGPoint(x: w - r, y: 0))

            // Top edge → top-left corner
            p.addLine(to: CGPoint(x: r, y: 0))
            p.addArc(
                center: CGPoint(x: r, y: r), radius: r,
                startAngle: .degrees(-90), endAngle: .degrees(180),
                clockwise: true
            )

            // Left edge down to tail start
            p.addLine(to: CGPoint(x: 0, y: h - 10))

            // Tail: curve outward then down to the tip
            p.addCurve(
                to: CGPoint(x: -6, y: h),
                control1: CGPoint(x: 0, y: h - 3),
                control2: CGPoint(x: -6, y: h - 2)
            )

            // Tail tip: sweep back right along bottom
            p.addCurve(
                to: CGPoint(x: 12, y: h),
                control1: CGPoint(x: -2, y: h + 1),
                control2: CGPoint(x: 4, y: h)
            )

            // Bottom edge → bottom-right corner
            p.addLine(to: CGPoint(x: w - r, y: h))
            p.addArc(
                center: CGPoint(x: w - r, y: h - r), radius: r,
                startAngle: .degrees(90), endAngle: .degrees(0),
                clockwise: true
            )

            // Right edge → top-right corner
            p.addLine(to: CGPoint(x: w, y: r))
            p.addArc(
                center: CGPoint(x: w - r, y: r), radius: r,
                startAngle: .degrees(0), endAngle: .degrees(-90),
                clockwise: true
            )

            p.closeSubpath()
        }
    }
}
