import Cocoa
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let permissionsManager = PermissionsManager()
    let selectionMonitor = SelectionMonitor()
    let tooltipWindow = TooltipWindow()
    let rewriteService = RewriteService()
    let accessibilityManager = AccessibilityManager()
    let hotkeyManager = HotkeyManager()

    private var selectedText: String = ""
    private var lastSelectionRect: CGRect = .zero
    private var currentTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isTrusted = AXIsProcessTrusted()
        Logger.permissions.info("App launched — AXIsProcessTrusted: \(isTrusted)")
        
        if isTrusted {
            startMonitoring()
        } else {
            permissionsManager.openAccessibilitySettingsDirectly()
            permissionsManager.startPolling()
        }

        NotificationCenter.default.addObserver(
            forName: .accessibilityPermissionGranted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.startMonitoring()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        selectionMonitor.stop()
        hotkeyManager.stop()
        currentTask?.cancel()
    }

    // MARK: - Start monitoring

    private func startMonitoring() {
        selectionMonitor.start { [weak self] result in
            guard let self else { return }
            self.handleSelection(result)
        }
        
        hotkeyManager.start { [weak self] in
            self?.handleHotkeyTrigger()
        }
        
        Logger.permissions.info("Selection monitoring active")
    }
    
    func restartMonitoring() {
        Logger.permissions.info("Manually restarting monitoring...")
        selectionMonitor.stop()
        hotkeyManager.stop()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startMonitoring()
        }
    }

    // MARK: - Selection handling

    private func handleSelection(_ result: SelectionResult) {
        if tooltipWindow.isVisible,
           tooltipWindow.windowFrame.contains(CGPoint(x: result.screenRect.midX, y: result.screenRect.midY)) {
            return
        }

        if tooltipWindow.isVisible && tooltipWindow.isInteracting && result.text == selectedText {
            return
        }

        currentTask?.cancel()
        currentTask = nil

        selectedText = result.text
        lastSelectionRect = result.screenRect

        if tooltipWindow.isVisible {
            tooltipWindow.hide()
        }

        tooltipWindow.showMiniIcon(near: result.screenRect)
        setupTooltipCallbacks()
    }
    
    // MARK: - Hotkey handling
    
    private func handleHotkeyTrigger() {
        if tooltipWindow.isVisible && tooltipWindow.isMiniIcon {
            tooltipWindow.updateUI(.collapsed)
            return
        }
        
        let text = getSelectedTextViaClipboard()
        
        if let text = text, !text.isEmpty, text.count >= AppConstants.minSelectionLength {
            selectedText = text
            let mouseLocation = NSEvent.mouseLocation
            lastSelectionRect = CGRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 1)
            
            if tooltipWindow.isVisible {
                tooltipWindow.hide()
            }
            
            tooltipWindow.show(near: lastSelectionRect)
            setupTooltipCallbacks()
        } else {
            let mouseLocation = NSEvent.mouseLocation
            let rect = CGRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 1)
            
            if tooltipWindow.isVisible {
                tooltipWindow.hide()
            }
            
            tooltipWindow.showNoSelection(near: rect)
        }
    }
    
    private func getSelectedTextViaClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        let backup = backupPasteboard(pasteboard)
        
        pasteboard.clearContents()
        
        simulateKeystroke(virtualKey: 0x08, flags: .maskCommand) // Cmd+C
        
        usleep(AppConstants.clipboardReadDelay)
        
        let text = pasteboard.string(forType: .string)
        
        restorePasteboard(pasteboard, from: backup)
        
        return text
    }
    
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
    
    private func simulateKeystroke(virtualKey: CGKeyCode, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: false)
        keyDown?.flags = flags
        keyUp?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    private func setupTooltipCallbacks() {
        tooltipWindow.onRephrase = { [weak self] in
            self?.performRephrase()
        }

        tooltipWindow.onReplace = { [weak self] text in
            self?.accessibilityManager.replaceSelectedText(with: text)
            self?.tooltipWindow.hide()
        }

        tooltipWindow.onCopy = { [weak self] text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            self?.tooltipWindow.hide()
        }

        tooltipWindow.onCancel = { [weak self] in
            self?.currentTask?.cancel()
            self?.currentTask = nil
        }

        tooltipWindow.onRetry = { [weak self] in
            self?.performRephrase()
        }
    }

    // MARK: - Rephrase

    private func performRephrase() {
        currentTask?.cancel()

        tooltipWindow.updateUI(.loading)

        let text = selectedText
        currentTask = Task {
            do {
                let result = try await rewriteService.rewrite(text: text)
                guard !Task.isCancelled else { return }
                tooltipWindow.updateUI(.result(result))
            } catch is CancellationError {
                // User cancelled — do nothing
            } catch {
                guard !Task.isCancelled else { return }
                let message = (error as? RewriteService.RewriteError)?.errorDescription ?? error.localizedDescription
                tooltipWindow.updateUI(.error(message))
            }
        }
    }
}
