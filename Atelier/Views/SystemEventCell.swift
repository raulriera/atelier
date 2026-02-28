import SwiftUI
import AtelierDesign
import AtelierKit

struct SystemEventCell: View {
    let event: SystemEvent

    var body: some View {
        Text(event.message)
            .systemContainer()
            .foregroundStyle(event.kind == .error ? AnyShapeStyle(.statusError) : AnyShapeStyle(.contentSecondary))
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
