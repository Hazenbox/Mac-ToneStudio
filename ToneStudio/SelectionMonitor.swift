import Cocoa
import ApplicationServices
import OSLog

struct SelectionResult {
    let text: String
    let screenRect: CGRect
}

@MainActor
final class SelectionMonitor {

    typealias SelectionCallback = (SelectionResult) -> Void

    private var callback: SelectionCallback?
    private var tapThread: Thread?
    private var machPort: CFMachPort?
    private var pendingWork: DispatchWorkItem?
    private var lastMousePosition: CGPoint = .zero

    func start(callback: @escaping SelectionCallback) {
        self.callback = callback
        startEventTap()
        observeSessionChanges()
        Logger.selection.info("SelectionMonitor started")
    }

    func stop() {
        if let port = machPort {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        machPort = nil
        tapThread?.cancel()
        tapThread = nil
        pendingWork?.cancel()
        pendingWork = nil
        callback = nil
        Logger.selection.info("SelectionMonitor stopped")
    }

    // MARK: - CGEventTap (runs on background thread)

    private func startEventTap() {
        let monitor = self
        let thread = Thread {
            let mask = CGEventMask(1 << CGEventType.leftMouseUp.rawValue)

            let refcon = Unmanaged.passUnretained(monitor).toOpaque()
            guard let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: mask,
                callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                    guard let refcon else { return Unmanaged.passRetained(event) }
                    let monitor = Unmanaged<SelectionMonitor>.fromOpaque(refcon).takeUnretainedValue()

                    if type == .tapDisabledByTimeout {
                        DispatchQueue.main.async {
                            monitor.reEnableTapIfNeeded()
                        }
                        return Unmanaged.passRetained(event)
                    }

                    if type == .leftMouseUp {
                        let mousePos = event.location
                        DispatchQueue.main.async {
                            monitor.handleMouseUp(mousePosition: mousePos)
                        }
                    }

                    return Unmanaged.passRetained(event)
                },
                userInfo: refcon
            ) else {
                DispatchQueue.main.async {
                    Logger.selection.error("Failed to create CGEventTap — is accessibility granted?")
                }
                return
            }

            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)

            DispatchQueue.main.async {
                monitor.machPort = tap
            }

            CFRunLoopRun()
        }
        thread.name = "com.upen.ToneStudio.EventTap"
        thread.qualityOfService = .userInitiated
        thread.start()
        tapThread = thread
    }

    // MARK: - Session change observer (re-enable tap after screen lock)

    nonisolated private func observeSessionChanges() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.reEnableTapIfNeeded()
            }
        }
    }

    private func reEnableTapIfNeeded() {
        guard let port = machPort else {
            Logger.selection.warning("No event tap to re-enable after session change; restarting")
            if let cb = callback {
                stop()
                start(callback: cb)
            }
            return
        }
        CGEvent.tapEnable(tap: port, enable: true)
        Logger.selection.info("Re-enabled event tap after session became active")
    }

    // MARK: - Debounce

    private func handleMouseUp(mousePosition: CGPoint) {
        lastMousePosition = mousePosition
        pendingWork?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.performAXQuery()
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.debounceInterval, execute: work)
    }

    // MARK: - Accessibility queries (main thread)

    private func performAXQuery() {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedRaw: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRaw) == .success else {
            Logger.selection.debug("No focused UI element")
            return
        }
        let focused = focusedRaw as! AXUIElement

        if isSecureField(focused) {
            Logger.selection.debug("Skipping secure text field")
            return
        }

        guard let text = getSelectedText(from: focused) ?? getTextViaClipboard(),
              text.count >= AppConstants.minSelectionLength,
              text.count <= AppConstants.maxSelectionLength else {
            return
        }

        let mousePos = NSEvent.mouseLocation
        let selectionRect = CGRect(x: mousePos.x, y: mousePos.y, width: 1, height: 1)

        callback?(SelectionResult(text: text, screenRect: selectionRect))
    }

    // MARK: - Secure field check

    private func isSecureField(_ element: AXUIElement) -> Bool {
        var roleRaw: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRaw) == .success,
              let role = roleRaw as? String else {
            return false
        }
        return role == "AXSecureTextField"
    }

    // MARK: - Get selected text via AX

    private func getSelectedText(from element: AXUIElement) -> String? {
        var textRaw: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &textRaw) == .success,
              let text = textRaw as? String,
              !text.isEmpty else {
            return nil
        }
        return text
    }

    // MARK: - Clipboard-copy fallback (for browsers / Electron)

    private func getTextViaClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        let backup = backupPasteboard(pasteboard)

        pasteboard.clearContents()

        simulateKeystroke(virtualKey: 0x08, flags: .maskCommand) // Cmd+C

        usleep(AppConstants.clipboardReadDelay)

        let text = pasteboard.string(forType: .string)

        restorePasteboard(pasteboard, from: backup)

        if let text, !text.isEmpty {
            Logger.selection.debug("Got text via clipboard fallback (\(text.count) chars)")
            return text
        }
        return nil
    }

    // MARK: - Selection bounds via AX

    private func getSelectionBounds(from element: AXUIElement) -> CGRect? {
        var rangeRaw: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRaw) == .success else {
            return nil
        }

        var boundsRaw: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeRaw!,
            &boundsRaw
        ) == .success else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsRaw as! AXValue, .cgRect, &rect) else {
            return nil
        }
        return rect
    }

    // MARK: - Mouse position fallback

    private func mousePositionRect() -> CGRect {
        CGRect(x: lastMousePosition.x + 5, y: lastMousePosition.y + 10, width: 1, height: 1)
    }

    // MARK: - Coordinate conversion (AX top-left origin -> AppKit bottom-left origin)

    private func axRectToAppKit(_ axRect: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 900
        return CGRect(
            x: axRect.origin.x,
            y: primaryHeight - axRect.origin.y - axRect.height,
            width: axRect.width,
            height: axRect.height
        )
    }

    // MARK: - Pasteboard helpers

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

    // MARK: - Simulate keystroke

    private func simulateKeystroke(virtualKey: CGKeyCode, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: false)
        keyDown?.flags = flags
        keyUp?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
