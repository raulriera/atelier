import SwiftUI

/// Allows the View menu to toggle the inspector in whichever
/// window is currently focused.
extension FocusedValues {
    @Entry var inspectorVisibility: Binding<Bool>?
}
