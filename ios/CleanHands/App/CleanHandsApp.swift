import SwiftUI

@main
struct CleanHandsApp: App {
    /// Unit tests are hosted in the app; they need no camera, renderer, or audio.
    private static let isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    var body: some Scene {
        WindowGroup {
            if Self.isTestHost {
                Color.black
            } else {
                RootView()
            }
        }
    }
}

private struct RootView: View {
    @State private var model = AppModel()

    var body: some View {
        ParticipantRootView(model: model)
            .preferredColorScheme(.dark)
    }
}
