import SwiftUI
import AtelierDesign

/// Shows how long a tool has been running, appearing only after a short delay
/// so quick operations don't flash a timestamp.
///
/// Uses `Text(_:style: .relative)` which SwiftUI auto-updates — no timers needed.
struct ElapsedTimeLabel: View {
    /// When the operation started.
    let since: Date

    /// How many seconds to wait before showing the label.
    private let threshold: TimeInterval = 10

    @State private var isVisible = false

    var body: some View {
        Group {
            if isVisible {
                Text(since, style: .relative)
                    .font(.metadata)
                    .foregroundStyle(.contentTertiary)
                    .monospacedDigit()
                    .transition(.opacity)
            }
        }
        .task {
            let elapsed = Date.now.timeIntervalSince(since)
            let remaining = threshold - elapsed
            if remaining <= 0 {
                isVisible = true
            } else {
                try? await Task.sleep(for: .seconds(remaining))
                withAnimation(Motion.morph) {
                    isVisible = true
                }
            }
        }
    }
}

#Preview("Elapsed Time Label") {
    VStack(spacing: 20) {
        HStack {
            Text("Just started")
            Spacer()
            ElapsedTimeLabel(since: Date())
            ProgressView().controlSize(.mini)
        }

        HStack {
            Text("Running for 30s")
            Spacer()
            ElapsedTimeLabel(since: Date(timeIntervalSinceNow: -30))
            ProgressView().controlSize(.mini)
        }

        HStack {
            Text("Running for 2 min")
            Spacer()
            ElapsedTimeLabel(since: Date(timeIntervalSinceNow: -120))
            ProgressView().controlSize(.mini)
        }
    }
    .padding()
    .frame(width: 400)
}
