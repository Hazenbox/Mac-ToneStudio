import Cocoa
import OSLog
import IOKit.hid

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let permissionsManager = PermissionsManager()
    let selectionMonitor = SelectionMonitor()
    let tooltipWindow = TooltipWindow()
    let rewriteService = RewriteService()
    let feedbackService = FeedbackService()
    let accessibilityManager = AccessibilityManager()
    let hotkeyManager = HotkeyManager()
    
    private var serviceProvider: ServiceProvider?

    private var selectedText: String = ""
    private var lastSelectionRect: CGRect = .zero
    private var currentTask: Task<Void, Never>?
    private var lastTooltipPrompt: String = ""
    
    private enum LastChatAction {
        case rephrase
        case customPrompt(String)
        case regenerate
    }
    private var lastChatAction: LastChatAction = .rephrase
    private var isRetryInProgress = false
    
    // MARK: - Preflight
    
    private enum PreflightResult {
        case proceed(GenerationContext?)
        case localResponse(String)
    }
    
    private func preflight(_ text: String) async -> PreflightResult {
        let safetyResult = await SafetyGateService.shared.classify(text)
        
        switch safetyResult.routing {
        case .proceedNormal:
            return .proceed(nil)
            
        case .proceedWithDisclaimer, .proceedModified:
            var ctx = GenerationContext.default
            ctx.channel = .chat
            if let maxW = safetyResult.modifications.maxWarmth {
                ctx.warmth = min(ctx.warmth, maxW)
            }
            if let tone = safetyResult.modifications.toneLock {
                ctx.persona = tone
            }
            return .proceed(ctx)
            
        case .emergencyResponse:
            if let info = safetyResult.modifications.emergencyInfo {
                return .localResponse(buildEmergencyMessage(info))
            }
            return .localResponse(buildGenericBlockMessage())
            
        case .blockAndLog:
            return .localResponse(buildGenericBlockMessage())
        }
    }
    
    private func buildEmergencyMessage(_ info: EmergencyInfo) -> String {
        var lines = [info.immediateMessage, ""]
        for helpline in info.helplines {
            let availability = helpline.available24x7 ? "(24/7)" : ""
            lines.append("\(helpline.name): \(helpline.number) \(availability)")
        }
        return lines.joined(separator: "\n")
    }
    
    private func buildGenericBlockMessage() -> String {
        "i can't help with that topic, but if you need immediate assistance, please call 112 (emergency services)."
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isTrusted = AXIsProcessTrusted()
        let inputMonitoringStatus = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        let hasInputMonitoring = (inputMonitoringStatus == kIOHIDAccessTypeGranted)
        
        // Use NSLog for immediate output that always shows
        NSLog("🚀 ToneStudio launched")
        NSLog("   Accessibility: %d", isTrusted ? 1 : 0)
        NSLog("   Input Monitoring: %d (status: %d)", hasInputMonitoring ? 1 : 0, inputMonitoringStatus.rawValue)
        
        Logger.permissions.info("App launched — Accessibility: \(isTrusted), Input Monitoring: \(hasInputMonitoring)")
        
        // Register macOS Services
        registerServices()
        
        // Always start monitoring - let it fail gracefully if permissions missing
        // This allows hotkeys to work even if event tap fails
        NSLog("📡 Starting monitoring...")
        startMonitoring()
        
        // If permissions missing, also open settings
        if !isTrusted {
            NSLog("⚠️ Accessibility not granted - opening settings")
            permissionsManager.openAccessibilitySettingsDirectly()
            permissionsManager.startPolling()
        }
        
        if !hasInputMonitoring {
            NSLog("⚠️ Input Monitoring not granted - requesting")
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        }

        NotificationCenter.default.addObserver(
            forName: .accessibilityPermissionGranted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                print("✅ Accessibility permission granted notification received")
                self.restartMonitoring()
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
    }

    // MARK: - Start monitoring

    private func startMonitoring() {
        NSLog("📡 startMonitoring() called")
        
        selectionMonitor.start { [weak self] result in
            guard let self else { return }
            NSLog("📝 Selection detected: %@...", String(result.text.prefix(50)))
            self.handleSelection(result)
        }
        
        hotkeyManager.start(
            callback: { [weak self] in
                NSLog("⌨️ Rephrase hotkey triggered!")
                self?.handleHotkeyTrigger()
            },
            editorCallback: { [weak self] in
                NSLog("⌨️ Editor hotkey triggered!")
                self?.handleEditorHotkey()
            }
        )
        
        // Set up stress test callback (Cmd+Shift+Control+T)
        hotkeyManager.setStressTestCallback { [weak self] in
            self?.runStressTests()
        }
        
        NSLog("✅ Monitoring started successfully")
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
    
    private var lastSelectionResult: SelectionResult?

    private func handleSelection(_ result: SelectionResult) {
        // Don't interfere if click is inside the tooltip window
        let clickPoint = result.tooltipAnchorPoint
        if tooltipWindow.isVisible,
           tooltipWindow.windowFrame.contains(clickPoint) {
            return
        }

        // Don't reset if we're in an interactive state (chat, options, etc.)
        // This allows users to select text from other apps while keeping the chat open
        if tooltipWindow.isVisible && tooltipWindow.isInteracting {
            return
        }

        // Cancel any pending tasks before changing state
        currentTask?.cancel()
        currentTask = nil

        // Update state
        selectedText = result.text
        lastSelectionRect = result.selectionBounds
        lastSelectionResult = result

        // Hide existing tooltip before showing new one (force hide to allow new selection)
        if tooltipWindow.isVisible {
            tooltipWindow.hide(force: true)
        }

        // Small delay to ensure clean state transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.tooltipWindow.showMiniIcon(for: result)
            self.setupTooltipCallbacks()
        }
    }
    
    // MARK: - Hotkey handling
    
    private func handleHotkeyTrigger() {
        if tooltipWindow.isVisible && tooltipWindow.isMiniIcon {
            tooltipWindow.setSelectedText(selectedText)
            tooltipWindow.updateUI(.optionsMenu)
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
                
                tooltipWindow.setSelectedText(text)
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
        tooltipWindow.setSelectedText(selectedText)
        
        tooltipWindow.onRephrase = { [weak self] in
            self?.performRephraseInChat()
        }

        tooltipWindow.onReplace = { [weak self] text in
            self?.accessibilityManager.replaceSelectedText(with: text)
            self?.cleanupTooltipState()
        }

        tooltipWindow.onCopy = { [weak self] text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }

        tooltipWindow.onCancel = { [weak self] in
            self?.cleanupTooltipState()
        }

        tooltipWindow.onRetry = { [weak self] in
            guard let self else { return }
            self.isRetryInProgress = true
            switch self.lastChatAction {
            case .rephrase:
                self.performRephraseInChat()
            case .customPrompt(let prompt):
                self.performCustomPromptInChat(prompt)
            case .regenerate:
                self.performRegenerateInChat()
            }
        }
        
        tooltipWindow.onCustomPrompt = { [weak self] prompt in
            self?.performCustomPromptInChat(prompt)
        }
        
        tooltipWindow.onRegenerate = { [weak self] in
            self?.performRegenerateInChat()
        }
        
        tooltipWindow.onFeedback = { [weak self] feedbackType, content in
            self?.submitTooltipFeedback(type: feedbackType, content: content)
        }
        
        tooltipWindow.onClearSelectedText = { [weak self] in
            self?.selectedText = ""
        }
    }
    
    private func cleanupTooltipState() {
        currentTask?.cancel()
        currentTask = nil
        tooltipWindow.hide()
    }
    
    // MARK: - Conversational Message Detection
    
    private func isConversationalMessage(_ message: String) -> Bool {
        let normalized = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Common acknowledgments and greetings
        let conversationalStarters = [
            "ok", "okay", "k", "got it", "thanks", "thank you", "thx", "ty",
            "cool", "great", "nice", "perfect", "awesome", "good", "understood",
            "noted", "hi", "hello", "hey", "sure", "yes", "no", "alright",
            "sounds good", "that works", "looks good", "love it", "done"
        ]
        
        // Check if message matches or starts with conversational word
        for starter in conversationalStarters {
            if normalized == starter ||
               normalized.hasPrefix(starter + " ") ||
               normalized.hasPrefix(starter + ",") ||
               normalized.hasPrefix(starter + "!") ||
               normalized.hasPrefix(starter + ".") {
                return true
            }
        }
        
        // Short messages without action verbs are likely conversational
        if normalized.count < 25 {
            let actionVerbs = [
                "rephrase", "rewrite", "make", "change", "convert",
                "translate", "fix", "improve", "shorten", "expand",
                "write", "edit", "modify", "update", "add", "remove"
            ]
            let hasActionVerb = actionVerbs.contains { normalized.contains($0) }
            if !hasActionVerb {
                return true
            }
        }
        
        return false
    }

    // MARK: - Rephrase in Chat

    private func performRephraseInChat() {
        currentTask?.cancel()
        lastTooltipPrompt = ""
        lastChatAction = .rephrase
        
        let text = selectedText
        guard !text.isEmpty else {
            tooltipWindow.appendMessage(ChatMessage(
                role: .assistant,
                content: "Select some text first, then I can rephrase it for you."
            ))
            tooltipWindow.updateUI(.chatWindow)
            tooltipWindow.enableInput()
            return
        }
        
        tooltipWindow.setLastAction("Rephrase with Jio Voice and Tone")
        tooltipWindow.showInlineLoading()
        tooltipWindow.updateUI(.chatLoading)

        currentTask = Task {
            do {
                let result = try await rewriteService.rewrite(text: text)
                guard !Task.isCancelled else { return }
                tooltipWindow.hideInlineLoading()
                tooltipWindow.appendMessage(ChatMessage(role: .assistant, content: result))
                tooltipWindow.updateUI(.chatWindow)
                tooltipWindow.enableInput()
            } catch is CancellationError {
                // User cancelled
            } catch {
                guard !Task.isCancelled else { return }
                tooltipWindow.hideInlineLoading()
                let message = (error as? RewriteService.RewriteError)?.errorDescription ?? error.localizedDescription
                tooltipWindow.updateUI(.error(message))
            }
        }
    }
    
    private func performCustomPromptInChat(_ prompt: String) {
        currentTask?.cancel()
        lastTooltipPrompt = prompt
        lastChatAction = .customPrompt(prompt)
        
        if !isRetryInProgress {
            tooltipWindow.appendMessage(ChatMessage(role: .user, content: prompt))
        }
        isRetryInProgress = false
        
        tooltipWindow.showInlineLoading()
        tooltipWindow.updateUI(.chatLoading)

        // Skip context for conversational messages (acknowledgments, greetings, etc.)
        let isConversational = isConversationalMessage(prompt)
        let hasContext = !selectedText.isEmpty && !isConversational
        let textToSend = hasContext ? selectedText : prompt
        let safeText = textToSend.count < 3
            ? textToSend + String(repeating: " ", count: 3 - textToSend.count)
            : textToSend
        let history = tooltipWindow.getConversationHistory()

        currentTask = Task {
            let preflightResult = await preflight(prompt)
            guard !Task.isCancelled else { return }
            
            switch preflightResult {
            case .localResponse(let message):
                tooltipWindow.hideInlineLoading()
                tooltipWindow.appendMessage(ChatMessage(role: .assistant, content: message))
                tooltipWindow.updateUI(.chatWindow)
                tooltipWindow.enableInput()
                return
                
            case .proceed(let safetyContext):
                do {
                    let result = try await rewriteService.rewrite(
                        text: safeText, prompt: prompt, isChat: true,
                        context: safetyContext,
                        conversationHistory: history
                    )
                    guard !Task.isCancelled else { return }
                    tooltipWindow.hideInlineLoading()
                    tooltipWindow.appendMessage(ChatMessage(role: .assistant, content: result))
                    tooltipWindow.updateUI(.chatWindow)
                    tooltipWindow.enableInput()
                } catch is CancellationError {
                    // User cancelled
                } catch {
                    guard !Task.isCancelled else { return }
                    tooltipWindow.hideInlineLoading()
                    let message = (error as? RewriteService.RewriteError)?.errorDescription ?? error.localizedDescription
                    tooltipWindow.updateUI(.error(message))
                    tooltipWindow.enableInput()
                }
            }
        }
    }
    
    private func performRegenerateInChat() {
        currentTask?.cancel()
        lastChatAction = .regenerate
        
        tooltipWindow.showInlineLoading()
        tooltipWindow.updateUI(.chatLoading)

        let prompt = lastTooltipPrompt
        // Skip context for conversational messages (acknowledgments, greetings, etc.)
        let isConversational = isConversationalMessage(prompt)
        let hasContext = !selectedText.isEmpty && !isConversational
        let textToSend = hasContext ? selectedText : prompt
        let safeText = textToSend.count < 3
            ? textToSend + String(repeating: " ", count: 3 - textToSend.count)
            : textToSend
        let useChat = !prompt.isEmpty
        let history = tooltipWindow.getConversationHistory()
        
        currentTask = Task {
            if useChat {
                let preflightResult = await preflight(prompt)
                guard !Task.isCancelled else { return }
                
                var safetyContext: GenerationContext? = nil
                switch preflightResult {
                case .localResponse(let message):
                    tooltipWindow.hideInlineLoading()
                    tooltipWindow.appendMessage(ChatMessage(role: .assistant, content: message))
                    tooltipWindow.updateUI(.chatWindow)
                    tooltipWindow.enableInput()
                    return
                case .proceed(let ctx):
                    safetyContext = ctx
                }
                
                do {
                    let result = try await rewriteService.rewrite(
                        text: safeText, prompt: prompt, isChat: true,
                        context: safetyContext,
                        conversationHistory: history
                    )
                    guard !Task.isCancelled else { return }
                    tooltipWindow.hideInlineLoading()
                    tooltipWindow.appendMessage(ChatMessage(role: .assistant, content: result))
                    tooltipWindow.updateUI(.chatWindow)
                    tooltipWindow.enableInput()
                } catch is CancellationError {
                    // User cancelled
                } catch {
                    guard !Task.isCancelled else { return }
                    tooltipWindow.hideInlineLoading()
                    let message = (error as? RewriteService.RewriteError)?.errorDescription ?? error.localizedDescription
                    tooltipWindow.updateUI(.error(message))
                    tooltipWindow.enableInput()
                }
            } else {
                do {
                    let result = try await rewriteService.rewrite(text: safeText)
                    guard !Task.isCancelled else { return }
                    tooltipWindow.hideInlineLoading()
                    tooltipWindow.appendMessage(ChatMessage(role: .assistant, content: result))
                    tooltipWindow.updateUI(.chatWindow)
                    tooltipWindow.enableInput()
                } catch is CancellationError {
                    // User cancelled
                } catch {
                    guard !Task.isCancelled else { return }
                    tooltipWindow.hideInlineLoading()
                    let message = (error as? RewriteService.RewriteError)?.errorDescription ?? error.localizedDescription
                    tooltipWindow.updateUI(.error(message))
                    tooltipWindow.enableInput()
                }
            }
        }
    }
    
    private func submitTooltipFeedback(type: String, content: String) {
        Task {
            do {
                try await feedbackService.submit(
                    feedbackType: type,
                    messageContent: content,
                    originalContent: selectedText
                )
                Logger.feedback.info("Tooltip feedback submitted: \(type)")
            } catch {
                Logger.feedback.error("Failed to submit tooltip feedback: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Editor (now unified with chat window)
    
    private func handleEditorHotkey() {
        // If chat window is already visible, toggle it off
        if tooltipWindow.isVisible {
            tooltipWindow.hide()
            currentTask?.cancel()
            currentTask = nil
            return
        }
        
        // Try to get selected text to pre-fill
        Task {
            let text = await selectionMonitor.getSelectedText()
            if let text = text, !text.isEmpty, text.count >= AppConstants.minSelectionLength {
                selectedText = text
                tooltipWindow.showCentered(withText: text)
            } else {
                selectedText = ""
                tooltipWindow.showCentered(withText: nil)
            }
            setupTooltipCallbacks()
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
        tooltipWindow.showCentered(withText: text)
        setupTooltipCallbacks()
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
    
    // MARK: - Stress Tests
    
    private func runStressTests() {
        NSLog("🧪 Running stress tests...")
        
        Task {
            let report = await StressTestRunner.shared.runAllTests()
            
            await MainActor.run {
                // Save report to file
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let reportPath = documentsPath.appendingPathComponent("ToneStudio_StressTest_Report.txt")
                
                do {
                    try report.write(to: reportPath, atomically: true, encoding: .utf8)
                    NSLog("📄 Stress test report saved to: \(reportPath.path)")
                    
                    // Open the report file
                    NSWorkspace.shared.open(reportPath)
                } catch {
                    NSLog("❌ Failed to save report: \(error)")
                }
                
                // Also log to console
                print(report)
            }
        }
    }
}
