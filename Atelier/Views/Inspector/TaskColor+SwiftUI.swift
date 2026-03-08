import SwiftUI
import AtelierKit

/// Maps ``TaskColor`` preset names to SwiftUI colors for the view layer.
extension TaskColor {
    var swiftUIColor: Color {
        switch self {
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .green: .green
        case .teal: .teal
        case .indigo: .indigo
        case .brown: .brown
        case .gray: .gray
        }
    }
}
