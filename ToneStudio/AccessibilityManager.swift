import Cocoa
import ApplicationServices
import OSLog

/// Result containing the bounds of the currently selected text
struct SelectionBounds {
    let rect: CGRect           // Full selection bounds in screen coordinates (AppKit: bottom-left origin)
    let firstLineRect: CGRect  // Bounds of just the first line (for multi-line selections)
}

@MainActor
final class AccessibilityManager {
    
    // MARK: - Get Selection Bounds
    
    /// Gets the screen bounds of the currently selected text using Accessibility API
    /// Returns nil if unable to get bounds (no selection, app doesn't support AX, etc.)
    func getSelectionBounds() -> SelectionBounds? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRaw: AnyObject?
        
        // Get the focused UI element
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRaw
        ) == .success else {
            Logger.accessibility.debug("getSelectionBounds: Could not get focused element")
            return nil
        }
        
        let focused = focusedRaw as! AXUIElement
        
        // Get the selected text range
        var selectedRangeRaw: AnyObject?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeRaw
        ) == .success else {
            Logger.accessibility.debug("getSelectionBounds: Could not get selected text range")
            return nil
        }
        
        // Get the bounds for the selected range
        var boundsRaw: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
            focused,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            selectedRangeRaw!,
            &boundsRaw
        ) == .success else {
            Logger.accessibility.debug("getSelectionBounds: Could not get bounds for range")
            return nil
        }
        
        // Extract the CGRect from the AXValue
        var selectionRect = CGRect.zero
        guard AXValueGetValue(boundsRaw as! AXValue, .cgRect, &selectionRect) else {
            Logger.accessibility.debug("getSelectionBounds: Could not extract CGRect from AXValue")
            return nil
        }
        
        // Convert from CG coordinates (top-left origin) to AppKit coordinates (bottom-left origin)
        let appKitRect = cgRectToAppKit(selectionRect)
        
        // For multi-line selections, get just the first line bounds
        // We do this by getting bounds for a small range at the start
        let firstLineRect = getFirstLineBounds(focused: focused, fullRange: selectedRangeRaw!) ?? appKitRect
        
        Logger.accessibility.info("getSelectionBounds: Got bounds \(String(describing: appKitRect)), firstLine: \(String(describing: firstLineRect))")
        return SelectionBounds(rect: appKitRect, firstLineRect: firstLineRect)
    }
    
    /// Gets the bounds of just the first line of a selection (for multi-line selections)
    private func getFirstLineBounds(focused: AXUIElement, fullRange: AnyObject) -> CGRect? {
        // Get the range value
        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(fullRange as! AXValue, .cfRange, &range) else {
            return nil
        }
        
        // If selection is small, just use the full bounds
        if range.length <= 1 {
            return nil
        }
        
        // Create a range for just the first character to get first line position
        var firstCharRange = CFRange(location: range.location, length: 1)
        guard let firstCharRangeValue = AXValueCreate(.cfRange, &firstCharRange) else {
            return nil
        }
        
        var firstCharBoundsRaw: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
            focused,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            firstCharRangeValue,
            &firstCharBoundsRaw
        ) == .success else {
            return nil
        }
        
        var firstCharRect = CGRect.zero
        guard AXValueGetValue(firstCharBoundsRaw as! AXValue, .cgRect, &firstCharRect) else {
            return nil
        }
        
        return cgRectToAppKit(firstCharRect)
    }
    
    /// Convert CG coordinates (top-left origin) to AppKit coordinates (bottom-left origin)
    private func cgRectToAppKit(_ cgRect: CGRect) -> CGRect {
        guard let primaryScreen = NSScreen.screens.first else {
            return cgRect
        }
        let screenHeight = primaryScreen.frame.height
        return CGRect(
            x: cgRect.origin.x,
            y: screenHeight - cgRect.origin.y - cgRect.height,
            width: cgRect.width,
            height: cgRect.height
        )
    }

    // MARK: - Replace Selected Text
    
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
