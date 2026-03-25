import SwiftUI

@main
struct AvalonApp: App {
    @State private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appSettings)
        }
    }
}
