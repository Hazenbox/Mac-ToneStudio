import Cocoa
import OSLog
import Combine
import IOKit.hid

@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var isAccessibilityGranted = false
    @Published private(set) var isInputMonitoringGranted = false

    private var pollTimer: Timer?

    func checkAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        isAccessibilityGranted = trusted
        return trusted
    }
    
    func checkInputMonitoring() -> Bool {
        let status = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        let granted = (status == kIOHIDAccessTypeGranted)
        isInputMonitoringGranted = granted
        Logger.permissions.info("Input Monitoring check — status: \(status.rawValue), granted: \(granted)")
        return granted
    }
    
    func requestInputMonitoring() -> Bool {
        let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        isInputMonitoringGranted = granted
        Logger.permissions.info("Input Monitoring requested — granted: \(granted)")
        return granted
    }
    
    func checkAllPermissions() -> Bool {
        let accessibility = checkAccessibility()
        let inputMonitoring = checkInputMonitoring()
        Logger.permissions.info("Permissions check — Accessibility: \(accessibility), Input Monitoring: \(inputMonitoring)")
        return accessibility && inputMonitoring
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

        // Instant check when the user switches back to any app after visiting System Settings
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                let granted = self.checkAccessibility()
                if granted {
                    Logger.permissions.info("Accessibility granted (app-switch check)")
                    self.stopPolling()
                    NotificationCenter.default.post(name: .accessibilityPermissionGranted, object: nil)
                }
            }
        }

        // Fallback timer in case the notification fires before System Settings has saved the change
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
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
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

    func openAccessibilitySettingsDirectly() {
        // Trigger the system prompt first (shows "ToneStudio wants to control your computer" dialog)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        // Also open System Settings to the Accessibility pane so user can toggle it on
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openInputMonitoringSettings() {
        // Request Input Monitoring permission (this will trigger the system dialog)
        _ = requestInputMonitoring()
        // Also open System Settings to the Input Monitoring pane
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openAllPermissionSettings() {
        // Request both permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        _ = requestInputMonitoring()
        
        // Open Privacy & Security pane
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
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
