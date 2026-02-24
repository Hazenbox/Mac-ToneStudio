import Cocoa
import OSLog

// MARK: - Custom NSPanel that can become key for text input

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Editor Window

@MainActor
final class EditorWindow: NSObject {
    
    // MARK: Callbacks
    var onGenerate: ((String, String) -> Void)?  // (text, prompt)
    var onCopy: ((String) -> Void)?
    var onReplace: ((String) -> Void)?
    var onClose: (() -> Void)?
    
    // MARK: State
    enum EditorState {
        case idle
        case loading
        case result(String)
        case error(String)
    }
    
    private var currentState: EditorState = .idle
    private var resultText: String = ""
    
    // MARK: Panel & Views
    private let panel: KeyablePanel
    private let containerView: NSVisualEffectView
    
    private var inputTextView: NSTextView!
    private var inputScrollView: NSScrollView!
    private var promptField: NSTextField!
    private var generateButton: NSButton!
    private var resultTextView: NSTextView!
    private var resultScrollView: NSScrollView!
    private var copyButton: NSButton!
    private var replaceButton: NSButton!
    private var closeButton: NSButton!
    private var titleLabel: NSTextField!
    private var promptLabel: NSTextField!
    private var loadingIndicator: NSProgressIndicator!
    private var statusLabel: NSTextField!
    private var resultContainer: NSView!
    private var actionButtonsStack: NSStackView!
    
    // MARK: Event monitors
    private var localKeyMonitor: Any?
    private var globalClickMonitor: Any?
    
    // MARK: Sizing
    private static let windowSize = NSSize(width: 500, height: 420)
    private static let cornerRadius: CGFloat = 16
    private static let padding: CGFloat = 20
    private static let inputHeight: CGFloat = 100
    private static let resultHeight: CGFloat = 100
    
    // MARK: Colors
    private static let inputBgColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
    private static let borderColor = NSColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1)
    private static let accentColor = NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1)
    private static let textColor = NSColor.white
    private static let secondaryTextColor = NSColor(white: 0.6, alpha: 1)
    
    // MARK: - Init
    
    override init() {
        panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        containerView = NSVisualEffectView()
        containerView.material = .hudWindow
        containerView.blendingMode = .behindWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = Self.cornerRadius
        containerView.layer?.masksToBounds = true
        
        super.init()
        
        setupPanel()
        setupUI()
    }
    
    // MARK: - Panel Setup
    
    private func setupPanel() {
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.isMovableByWindowBackground = true
        
        containerView.frame = NSRect(origin: .zero, size: Self.windowSize)
        panel.contentView = containerView
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        let padding = Self.padding
        let contentWidth = Self.windowSize.width - padding * 2
        var yOffset = Self.windowSize.height - padding
        
        // Title bar with close button
        yOffset -= 24
        setupTitleBar(at: yOffset, width: contentWidth, padding: padding)
        
        // Input section
        yOffset -= 12
        yOffset -= Self.inputHeight
        setupInputSection(at: yOffset, width: contentWidth, padding: padding)
        
        // Prompt field
        yOffset -= 16
        yOffset -= 28
        setupPromptField(at: yOffset, width: contentWidth, padding: padding)
        
        // Generate button
        yOffset -= 12
        yOffset -= 32
        setupGenerateButton(at: yOffset, width: contentWidth, padding: padding)
        
        // Status / Loading
        yOffset -= 8
        yOffset -= 20
        setupStatusArea(at: yOffset, width: contentWidth, padding: padding)
        
        // Result section
        yOffset -= 8
        yOffset -= Self.resultHeight
        setupResultSection(at: yOffset, width: contentWidth, padding: padding)
        
        // Action buttons
        yOffset -= 12
        setupActionButtons(at: yOffset, width: contentWidth, padding: padding)
        
        updateUIForState()
    }
    
    private func setupTitleBar(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        // Title
        titleLabel = NSTextField(labelWithString: "tone studio")
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = Self.textColor
        titleLabel.frame = NSRect(x: padding, y: y, width: width - 30, height: 24)
        containerView.addSubview(titleLabel)
        
        // Close button
        closeButton = NSButton(frame: NSRect(x: Self.windowSize.width - padding - 20, y: y + 2, width: 20, height: 20))
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.contentTintColor = Self.secondaryTextColor
        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked)
        containerView.addSubview(closeButton)
    }
    
    private func setupInputSection(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        // Input container
        let inputContainer = NSView(frame: NSRect(x: padding, y: y, width: width, height: Self.inputHeight))
        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = Self.inputBgColor.cgColor
        inputContainer.layer?.cornerRadius = 10
        inputContainer.layer?.borderWidth = 1
        inputContainer.layer?.borderColor = Self.borderColor.cgColor
        containerView.addSubview(inputContainer)
        
        // Scroll view for text
        inputScrollView = NSScrollView(frame: NSRect(x: 8, y: 8, width: width - 16, height: Self.inputHeight - 16))
        inputScrollView.hasVerticalScroller = true
        inputScrollView.hasHorizontalScroller = false
        inputScrollView.autohidesScrollers = true
        inputScrollView.borderType = .noBorder
        inputScrollView.drawsBackground = false
        
        // Text view
        inputTextView = NSTextView(frame: inputScrollView.bounds)
        inputTextView.isEditable = true
        inputTextView.isSelectable = true
        inputTextView.isRichText = false
        inputTextView.font = .systemFont(ofSize: 13)
        inputTextView.textColor = Self.textColor
        inputTextView.backgroundColor = .clear
        inputTextView.drawsBackground = false
        inputTextView.isVerticallyResizable = true
        inputTextView.isHorizontallyResizable = false
        inputTextView.textContainer?.widthTracksTextView = true
        inputTextView.textContainer?.containerSize = NSSize(width: width - 32, height: .greatestFiniteMagnitude)
        inputTextView.delegate = self
        
        // Placeholder
        inputTextView.string = ""
        
        inputScrollView.documentView = inputTextView
        inputContainer.addSubview(inputScrollView)
    }
    
    private func setupPromptField(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        // Label
        promptLabel = NSTextField(labelWithString: "prompt")
        promptLabel.font = .systemFont(ofSize: 11, weight: .medium)
        promptLabel.textColor = Self.secondaryTextColor
        promptLabel.frame = NSRect(x: padding, y: y + 30, width: 60, height: 16)
        containerView.addSubview(promptLabel)
        
        // Field
        promptField = NSTextField(frame: NSRect(x: padding, y: y, width: width, height: 28))
        promptField.placeholderString = "e.g., make it more friendly, simplify this, fix grammar..."
        promptField.font = .systemFont(ofSize: 12)
        promptField.textColor = Self.textColor
        promptField.backgroundColor = Self.inputBgColor
        promptField.isBordered = false
        promptField.focusRingType = .none
        promptField.wantsLayer = true
        promptField.layer?.cornerRadius = 6
        promptField.layer?.borderWidth = 1
        promptField.layer?.borderColor = Self.borderColor.cgColor
        containerView.addSubview(promptField)
    }
    
    private func setupGenerateButton(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        generateButton = NSButton(frame: NSRect(x: padding + (width - 120) / 2, y: y, width: 120, height: 32))
        generateButton.title = "generate"
        generateButton.bezelStyle = .rounded
        generateButton.font = .systemFont(ofSize: 12, weight: .medium)
        generateButton.wantsLayer = true
        generateButton.layer?.cornerRadius = 8
        generateButton.contentTintColor = .white
        generateButton.target = self
        generateButton.action = #selector(generateButtonClicked)
        
        // Style the button
        if let cell = generateButton.cell as? NSButtonCell {
            cell.backgroundColor = Self.accentColor
        }
        
        containerView.addSubview(generateButton)
    }
    
    private func setupStatusArea(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        // Loading indicator
        loadingIndicator = NSProgressIndicator(frame: NSRect(x: padding + (width - 20) / 2, y: y, width: 20, height: 20))
        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .small
        loadingIndicator.isHidden = true
        containerView.addSubview(loadingIndicator)
        
        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = Self.secondaryTextColor
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: padding, y: y, width: width, height: 20)
        statusLabel.isHidden = true
        containerView.addSubview(statusLabel)
    }
    
    private func setupResultSection(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        // Result container
        resultContainer = NSView(frame: NSRect(x: padding, y: y, width: width, height: Self.resultHeight))
        resultContainer.wantsLayer = true
        resultContainer.layer?.backgroundColor = Self.inputBgColor.cgColor
        resultContainer.layer?.cornerRadius = 10
        resultContainer.layer?.borderWidth = 1
        resultContainer.layer?.borderColor = Self.borderColor.cgColor
        resultContainer.isHidden = true
        containerView.addSubview(resultContainer)
        
        // Scroll view for result
        resultScrollView = NSScrollView(frame: NSRect(x: 8, y: 8, width: width - 16, height: Self.resultHeight - 16))
        resultScrollView.hasVerticalScroller = true
        resultScrollView.hasHorizontalScroller = false
        resultScrollView.autohidesScrollers = true
        resultScrollView.borderType = .noBorder
        resultScrollView.drawsBackground = false
        
        // Result text view
        resultTextView = NSTextView(frame: resultScrollView.bounds)
        resultTextView.isEditable = false
        resultTextView.isSelectable = true
        resultTextView.isRichText = false
        resultTextView.font = .systemFont(ofSize: 13)
        resultTextView.textColor = Self.textColor
        resultTextView.backgroundColor = .clear
        resultTextView.drawsBackground = false
        resultTextView.isVerticallyResizable = true
        resultTextView.isHorizontallyResizable = false
        resultTextView.textContainer?.widthTracksTextView = true
        resultTextView.textContainer?.containerSize = NSSize(width: width - 32, height: .greatestFiniteMagnitude)
        
        resultScrollView.documentView = resultTextView
        resultContainer.addSubview(resultScrollView)
    }
    
    private func setupActionButtons(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        // Copy button
        copyButton = NSButton(frame: .zero)
        copyButton.title = "copy"
        copyButton.bezelStyle = .rounded
        copyButton.font = .systemFont(ofSize: 11)
        copyButton.target = self
        copyButton.action = #selector(copyButtonClicked)
        copyButton.setFrameSize(NSSize(width: 80, height: 24))
        
        // Replace button
        replaceButton = NSButton(frame: .zero)
        replaceButton.title = "replace"
        replaceButton.bezelStyle = .rounded
        replaceButton.font = .systemFont(ofSize: 11)
        replaceButton.target = self
        replaceButton.action = #selector(replaceButtonClicked)
        replaceButton.setFrameSize(NSSize(width: 80, height: 24))
        
        // Stack view
        actionButtonsStack = NSStackView(views: [copyButton, replaceButton])
        actionButtonsStack.orientation = .horizontal
        actionButtonsStack.spacing = 12
        actionButtonsStack.frame = NSRect(x: padding + (width - 172) / 2, y: y, width: 172, height: 24)
        actionButtonsStack.isHidden = true
        containerView.addSubview(actionButtonsStack)
    }
    
    // MARK: - Show / Hide
    
    var isVisible: Bool {
        panel.isVisible
    }
    
    func show() {
        // Center on screen
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - Self.windowSize.width / 2
        let y = screenFrame.midY - Self.windowSize.height / 2 + 100 // Slightly above center
        
        panel.setFrame(NSRect(x: x, y: y, size: Self.windowSize), display: false)
        
        // Reset state
        currentState = .idle
        updateUIForState()
        
        // Show with animation
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }
        
        // Focus input
        panel.makeFirstResponder(inputTextView)
        
        addEventMonitors()
        Logger.editor.info("Editor window shown")
    }
    
    func showWithText(_ text: String) {
        show()
        inputTextView.string = text
    }
    
    func hide() {
        removeEventMonitors()
        
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
        
        onClose?()
        Logger.editor.info("Editor window hidden")
    }
    
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    // MARK: - State Updates
    
    func updateState(_ state: EditorState) {
        currentState = state
        updateUIForState()
    }
    
    private func updateUIForState() {
        switch currentState {
        case .idle:
            loadingIndicator.stopAnimation(nil)
            loadingIndicator.isHidden = true
            statusLabel.isHidden = true
            resultContainer.isHidden = true
            actionButtonsStack.isHidden = true
            generateButton.isEnabled = true
            
        case .loading:
            loadingIndicator.isHidden = false
            loadingIndicator.startAnimation(nil)
            statusLabel.stringValue = "generating..."
            statusLabel.textColor = Self.secondaryTextColor
            statusLabel.isHidden = false
            resultContainer.isHidden = true
            actionButtonsStack.isHidden = true
            generateButton.isEnabled = false
            
        case .result(let text):
            resultText = text
            loadingIndicator.stopAnimation(nil)
            loadingIndicator.isHidden = true
            statusLabel.isHidden = true
            resultTextView.string = text
            resultContainer.isHidden = false
            actionButtonsStack.isHidden = false
            generateButton.isEnabled = true
            
        case .error(let message):
            loadingIndicator.stopAnimation(nil)
            loadingIndicator.isHidden = true
            statusLabel.stringValue = message
            statusLabel.textColor = NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1)
            statusLabel.isHidden = false
            resultContainer.isHidden = true
            actionButtonsStack.isHidden = true
            generateButton.isEnabled = true
        }
    }
    
    // MARK: - Actions
    
    @objc private func generateButtonClicked() {
        let text = inputTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = promptField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else {
            updateState(.error("please enter some text"))
            return
        }
        
        onGenerate?(text, prompt)
    }
    
    @objc private func copyButtonClicked() {
        guard !resultText.isEmpty else { return }
        onCopy?(resultText)
        
        // Visual feedback
        let originalTitle = copyButton.title
        copyButton.title = "copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.copyButton.title = originalTitle
        }
    }
    
    @objc private func replaceButtonClicked() {
        guard !resultText.isEmpty else { return }
        onReplace?(resultText)
        hide()
    }
    
    @objc private func closeButtonClicked() {
        hide()
    }
    
    // MARK: - Event Monitors
    
    private func addEventMonitors() {
        // Local key monitor for Escape and Cmd+Enter
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            
            // Escape to close
            if event.keyCode == 53 {
                self.hide()
                return nil
            }
            
            // Cmd+Enter to generate
            if event.keyCode == 36 && event.modifierFlags.contains(.command) {
                self.generateButtonClicked()
                return nil
            }
            
            return event
        }
        
        // Global click monitor to detect clicks outside
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.isVisible else { return }
            
            let clickLocation = event.locationInWindow
            let windowFrame = self.panel.frame
            
            // Convert to screen coordinates
            let screenPoint = NSEvent.mouseLocation
            
            if !windowFrame.contains(screenPoint) {
                self.hide()
            }
        }
    }
    
    private func removeEventMonitors() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}

// MARK: - NSTextViewDelegate

extension EditorWindow: NSTextViewDelegate {
    nonisolated func textDidChange(_ notification: Notification) {
        // Could add character count or other feedback here
    }
}
