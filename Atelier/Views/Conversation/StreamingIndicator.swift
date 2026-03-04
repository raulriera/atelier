import SwiftUI
import AtelierDesign

struct StreamingIndicator: View {
    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 0.3)) { timeline in
            let phase = Int(timeline.date.timeIntervalSinceReferenceDate / 0.3) % 3
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.contentTertiary)
                        .frame(width: 6, height: 6)
                        .opacity(phase == index ? 1.0 : 0.3)
                        .animation(Motion.streaming, value: phase)
                }
            }
            // Match the height of a single line of conversationBody text
            // so the speech bubble doesn't collapse to just the dots.
            .frame(minHeight: 20)
        }
    }
}
