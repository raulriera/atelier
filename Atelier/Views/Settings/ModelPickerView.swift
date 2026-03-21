import SwiftUI
import AtelierDesign
import AtelierKit

struct ModelPickerView: View {
    @Binding var selection: ModelConfiguration

    var body: some View {
        Menu {
            Picker(selection: $selection) {
                ForEach(ModelConfiguration.allModels) { model in
                    Text(model.friendlyName).tag(model)
                }
            } label: {
                Text(selection.friendlyName)
            }
            .pickerStyle(.inline)
        } label: {
            Text(selection.friendlyName)
                .font(.metadata)
                .foregroundStyle(.contentSecondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
