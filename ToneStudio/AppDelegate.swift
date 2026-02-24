import Cocoa
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let permissionsManager = PermissionsManager()
    let selectionMonitor = SelectionMonitor()
    let tooltipWindow = TooltipWindow()
    let editorWindow = EditorWindow()
    let rewriteService = RewriteService()
    let feedbackService = FeedbackService()
    let accessibilityManager = AccessibilityManager()
    let hotkeyManager = HotkeyManager()
    
    private var serviceProvider: ServiceProvider?

    private var selectedText: String = ""
    private var lastSelectionRect: CGRect = .zero
    private var currentTask: Task<Void, Never>?
    private var editorTask: Task<Void, Never>?
    private var lastEditorInput: String = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isTrusted = AXIsProcessTrusted()
        Logger.permissions.info("App launched — AXIsProcessTrusted: \(isTrusted)")
        
        // Register macOS Services
        registerServices()
        
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
    
    // MARK: - Services Registration
    
    private func registerServices() {
        serviceProvider = ServiceProvider(appDelegate: self)
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()
        Logger.services.info("Registered macOS Services")
    }

    func applicationWillTerminate(_ notification: Notification) {
        selectionMonitor.stop()
        hotkeyManager.stop()
        currentTask?.cancel()
        editorTask?.cancel()
    }

    // MARK: - Start monitoring

    private func startMonitoring() {
        selectionMonitor.start { [weak self] result in
            guard let self else { return }
            self.handleSelection(result)
        }
        
        hotkeyManager.start(
            callback: { [weak self] in
                self?.handleHotkeyTrigger()
            },
            editorCallback: { [weak self] in
                self?.handleEditorHotkey()
            }
        )
        
        setupEditorCallbacks()
        
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
        // Don't show tooltip when editor window is visible
        if editorWindow.isVisible {
            return
        }
        
        // Don't interfere if click is inside the tooltip window
        if tooltipWindow.isVisible,
           tooltipWindow.windowFrame.contains(CGPoint(x: result.screenRect.midX, y: result.screenRect.midY)) {
            return
        }

        // Don't reset if we're already interacting with the same text
        if tooltipWindow.isVisible && tooltipWindow.isInteracting && result.text == selectedText {
            return
        }

        // Cancel any pending tasks before changing state
        currentTask?.cancel()
        currentTask = nil

        // Update state
        selectedText = result.text
        lastSelectionRect = result.screenRect

        // Hide existing tooltip before showing new one
        if tooltipWindow.isVisible {
            tooltipWindow.hide()
        }

        // Small delay to ensure clean state transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            // Double-check editor isn't visible after delay
            guard !self.editorWindow.isVisible else { return }
            self.tooltipWindow.showMiniIcon(near: result.screenRect)
            self.setupTooltipCallbacks()
        }
    }
    
    // MARK: - Hotkey handling
    
    private func handleHotkeyTrigger() {
        if tooltipWindow.isVisible && tooltipWindow.isMiniIcon {
            tooltipWindow.updateUI(.collapsed)
            return
        }
        
        Task {
            let text = await selectionMonitor.getSelectedText()
            
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
    }
    
    
    private func setupTooltipCallbacks() {
        tooltipWindow.onRephrase = { [weak self] in
            self?.performRephrase()
        }

        tooltipWindow.onReplace = { [weak self] text in
            self?.accessibilityManager.replaceSelectedText(with: text)
            self?.cleanupTooltipState()
        }

        tooltipWindow.onCopy = { [weak self] text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            self?.cleanupTooltipState()
        }

        tooltipWindow.onCancel = { [weak self] in
            self?.cleanupTooltipState()
        }

        tooltipWindow.onRetry = { [weak self] in
            self?.performRephrase()
        }
    }
    
    private func cleanupTooltipState() {
        currentTask?.cancel()
        currentTask = nil
        tooltipWindow.hide()
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
    
    // MARK: - Editor
    
    private func handleEditorHotkey() {
        // If editor is visible, toggle it off
        if editorWindow.isVisible {
            editorWindow.hide()
            return
        }
        
        // Always hide tooltip first to clean up state
        if tooltipWindow.isVisible {
            tooltipWindow.hide()
        }
        
        // Cancel any pending tooltip tasks
        currentTask?.cancel()
        currentTask = nil
        
        // Try to get selected text to pre-fill using SelectedTextKit
        Task {
            let text = await selectionMonitor.getSelectedText()
            
            if let text = text, !text.isEmpty, text.count >= AppConstants.minSelectionLength {
                selectedText = text
                editorWindow.showWithText(text)
            } else {
                editorWindow.show()
            }
        }
    }
    
    func openEditor() {
        handleEditorHotkey()
    }
    
    func openEditorWithText(_ text: String) {
        if tooltipWindow.isVisible {
            tooltipWindow.hide()
        }
        currentTask?.cancel()
        currentTask = nil
        
        selectedText = text
        editorWindow.showWithText(text)
    }
    
    // MARK: - Service Handlers
    
    func handleServiceRephrase(text: String, pasteboard: NSPasteboard) async {
        Logger.services.info("Handling service rephrase for \(text.count) chars")
        
        do {
            let result = try await rewriteService.rewrite(text: text)
            pasteboard.clearContents()
            pasteboard.setString(result, forType: .string)
            Logger.services.info("Service rephrase completed, result written to pasteboard")
        } catch {
            Logger.services.error("Service rephrase failed: \(error.localizedDescription)")
        }
    }
    
    private func setupEditorCallbacks() {
        editorWindow.onGenerate = { [weak self] text in
            self?.lastEditorInput = text
            self?.performEditorRewrite(text: text)
        }
        
        editorWindow.onCopy = { text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            Logger.editor.info("Copied result to clipboard")
        }
        
        editorWindow.onTryAgain = { [weak self] in
            guard let self, !self.lastEditorInput.isEmpty else { return }
            self.performEditorRewrite(text: self.lastEditorInput)
        }
        
        editorWindow.onLike = { [weak self] resultText in
            self?.submitFeedback(type: "thumbs_up", content: resultText)
        }
        
        editorWindow.onDislike = { [weak self] resultText in
            self?.submitFeedback(type: "thumbs_down", content: resultText)
        }
    }
    
    private func submitFeedback(type: String, content: String) {
        Task {
            do {
                try await feedbackService.submit(
                    feedbackType: type,
                    messageContent: content,
                    originalContent: lastEditorInput
                )
            } catch {
                Logger.feedback.error("Failed to submit feedback: \(error.localizedDescription)")
            }
        }
    }
    
    private func performEditorRewrite(text: String) {
        editorTask?.cancel()
        
        editorWindow.updateState(.loading)
        
        editorTask = Task {
            do {
                // Pass the entire input as the prompt - user can include instructions in their text
                let result = try await rewriteService.rewrite(text: text, prompt: text)
                guard !Task.isCancelled else { return }
                editorWindow.updateState(.result(result))
            } catch is CancellationError {
                // User cancelled
            } catch {
                guard !Task.isCancelled else { return }
                let message = (error as? RewriteService.RewriteError)?.errorDescription ?? error.localizedDescription
                editorWindow.updateState(.error(message))
            }
        }
    }
}
