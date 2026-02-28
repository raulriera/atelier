import SwiftUI
import AtelierDesign

struct StreamingIndicator: View {
    @State private var phase: Int = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.contentTertiary)
                    .frame(width: 6, height: 6)
                    .opacity(phase == index ? 1.0 : 0.3)
            }
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                withAnimation(Motion.streaming) {
                    phase = (phase + 1) % 3
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}
