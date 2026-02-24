import SwiftUI

@main
struct ToneStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Tone Studio", systemImage: "text.bubble") {
            MenuBarView(onRestartMonitoring: {
                appDelegate.restartMonitoring()
            })
            .environmentObject(appDelegate.permissionsManager)
        }
        .menuBarExtraStyle(.window)
    }
}
