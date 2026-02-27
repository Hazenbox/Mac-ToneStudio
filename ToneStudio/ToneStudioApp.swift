import SwiftUI
import MenuBarExtraAccess

@main
struct ToneStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isMenuPresented = false

    var body: some Scene {
        MenuBarExtra("Tone Studio", image: "StatusBarIcon") {
            MenuBarView(
                onRestartMonitoring: {
                    appDelegate.restartMonitoring()
                },
                onOpenEditor: {
                    appDelegate.openEditor()
                }
            )
            .environmentObject(appDelegate.permissionsManager)
        }
        .menuBarExtraStyle(.window)
        .menuBarExtraAccess(isPresented: $isMenuPresented) { statusItem in
            statusItem.button?.toolTip = "Tone Studio - Rephrase selected text"
        }
    }
}
