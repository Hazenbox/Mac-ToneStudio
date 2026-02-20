import Cocoa
import ApplicationServices
import OSLog

@MainActor
final class AccessibilityManager {

    func replaceSelectedText(with newText: String) {
        if replaceViaAccessibility(with: newText) {
            return
        }
        Logger.accessibility.info("AX replace failed; falling back to clipboard paste")
        replaceViaClipboard(with: newText)
    }

    // MARK: - Primary: AX set attribute

    private func replaceViaAccessibility(with newText: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRaw: AnyObject?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRaw
        ) == .success else {
            Logger.accessibility.warning("Could not get focused element")
            return false
        }

        let focused = focusedRaw as! AXUIElement
        let result = AXUIElementSetAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            newText as CFString
        )

        if result == .success {
            Logger.accessibility.info("Replaced via AX setAttribute")
            return true
        }
        Logger.accessibility.warning("AX setAttribute returned \(result.rawValue)")
        return false
    }

    // MARK: - Fallback: clipboard + simulated Cmd+V

    private func replaceViaClipboard(with newText: String) {
        let pasteboard = NSPasteboard.general
        let backup = backupPasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)

        simulatePaste()

        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.clipboardRestoreDelay) {
            self.restorePasteboard(pasteboard, from: backup)
            Logger.accessibility.info("Replaced via clipboard paste; clipboard restored")
        }
    }

    private func simulatePaste() {
        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Pasteboard backup/restore

    private func backupPasteboard(_ pasteboard: NSPasteboard) -> [(NSPasteboard.PasteboardType, Data)] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        var backup: [(NSPasteboard.PasteboardType, Data)] = []
        for item in items {
            for type in item.types {
                if let data = item.data(forType: type) {
                    backup.append((type, data))
                }
            }
        }
        return backup
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard, from backup: [(NSPasteboard.PasteboardType, Data)]) {
        pasteboard.clearContents()
        if backup.isEmpty { return }
        let item = NSPasteboardItem()
        for (type, data) in backup {
            item.setData(data, forType: type)
        }
        pasteboard.writeObjects([item])
    }
}
