import SwiftUI

@main
struct AtelierApp: App {
    var body: some Scene {
        WindowGroup {
            ConversationWindow()
        }
        .defaultSize(width: 600, height: 700)
    }
}
