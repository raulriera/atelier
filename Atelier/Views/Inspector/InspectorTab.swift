import SwiftUI

/// The tabs available in the inspector sidebar.
///
/// Each tab corresponds to one section of the always-open inspector,
/// switched via a segmented control in the inspector header.
enum InspectorTab: String, CaseIterable, Identifiable {
    case capabilities
    case automations
    case detail

    var id: String { rawValue }

    /// SF Symbol for the segmented control.
    var systemImage: String {
        switch self {
        case .capabilities: "puzzlepiece.extension"
        case .automations: "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
        case .detail: "info.circle"
        }
    }

    /// Accessibility label for the tab.
    var label: String {
        switch self {
        case .capabilities: "Capabilities"
        case .automations: "Automations"
        case .detail: "Detail"
        }
    }
}
