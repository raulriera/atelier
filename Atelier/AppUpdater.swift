import Sparkle
import SwiftUI

/// Thin wrapper around Sparkle's updater controller for SwiftUI integration.
///
/// Create once at the app level and pass the `updater` to a "Check for Updates" button.
/// The feed URL is configured via the delegate to avoid requiring a manual Info.plist.
final class AppUpdater {
    static let feedURL = "https://raulriera.github.io/atelier/appcast.xml"

    private let delegate = UpdaterDelegate()
    let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
    }

    var updater: SPUUpdater { controller.updater }
}

private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        AppUpdater.feedURL
    }
}

/// A menu-bar button that triggers Sparkle's update check.
struct CheckForUpdatesView: View {
    let updater: SPUUpdater

    var body: some View {
        Button("Check for Updates…") {
            updater.checkForUpdates()
        }
    }
}
