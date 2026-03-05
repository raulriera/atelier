import SwiftUI
import AtelierDesign
import AtelierKit

struct ModelPickerView: View {
    @Binding var selection: ModelConfiguration

    var body: some View {
        Menu {
            ForEach(ModelConfiguration.allModels) { model in
                Button {
                    selection = model
                } label: {
                    if model.modelId == selection.modelId {
                        Label(model.displayName, systemImage: "checkmark")
                    } else {
                        Text(model.displayName)
                    }
                }
            }
        } label: {
            Text(selection.displayName)
                .font(.metadata)
                .foregroundStyle(.contentSecondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
