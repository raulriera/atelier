import SwiftUI
import AtelierDesign
import AtelierKit

struct SystemEventCell: View {
    let event: SystemEvent

    var body: some View {
        Label(event.message, systemImage: iconName)
            .systemContainer()
            .foregroundStyle(foregroundStyle)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var iconName: String {
        switch event.kind {
        case .error:
            "exclamationmark.triangle"
        case .sessionStarted:
            "bubble.left"
        case .info:
            "info.circle"
        }
    }

    private var foregroundStyle: AnyShapeStyle {
        switch event.kind {
        case .error:
            AnyShapeStyle(.statusError)
        default:
            AnyShapeStyle(.contentSecondary)
        }
    }
}
