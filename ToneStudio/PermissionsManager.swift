import Cocoa
import OSLog
import Combine

@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var isAccessibilityGranted = false

    private var pollTimer: Timer?

    func checkAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        isAccessibilityGranted = trusted
        return trusted
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        isAccessibilityGranted = trusted
        Logger.permissions.info("Accessibility requested — granted: \(trusted)")

        if !trusted {
            startPolling()
        }
    }

    func startPolling() {
        guard pollTimer == nil else { return }
        Logger.permissions.info("Starting permission polling every \(AppConstants.permissionPollInterval)s")

        pollTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.permissionPollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                let granted = self.checkAccessibility()
                if granted {
                    Logger.permissions.info("Accessibility permission granted via polling")
                    self.stopPolling()
                    NotificationCenter.default.post(name: .accessibilityPermissionGranted, object: nil)
                }
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func showManualInstructions() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "Tone Studio needs accessibility access to detect selected text and replace it inline.\n\nPlease enable it in:\nSystem Settings → Privacy & Security → Accessibility"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension Notification.Name {
    static let accessibilityPermissionGranted = Notification.Name("accessibilityPermissionGranted")
}
