import Cocoa
import OSLog

// MARK: - Editor Window

@MainActor
final class EditorWindow: NSObject, NSWindowDelegate {
    
    // MARK: Callbacks
    var onGenerate: ((String) -> Void)?
    var onCopy: ((String) -> Void)?
    var onReplace: ((String) -> Void)?
    var onClose: (() -> Void)?
    var onTryAgain: (() -> Void)?
    var onLike: ((String) -> Void)?
    var onDislike: ((String) -> Void)?
    
    // MARK: State
    enum EditorState {
        case idle
        case loading
        case result(String)
        case error(String)
    }
    
    private var currentState: EditorState = .idle
    private var resultText: String = ""
    
    // MARK: Window & Views
    private let window: NSWindow
    private let containerView: NSView
    
    private var inputTextView: NSTextView!
    private var inputScrollView: NSScrollView!
    private var generateButton: NSButton!
    private var resultTextView: NSTextView!
    private var resultScrollView: NSScrollView!
    private var copyButton: NSButton!
    private var replaceButton: NSButton!
    private var tryAgainButton: NSButton!
    private var likeButton: NSButton!
    private var dislikeButton: NSButton!
    private var feedbackSubmitted: Bool = false
    private var statusLabel: NSTextField!
    private var resultContainer: NSView!
    private var actionButtonsStack: NSStackView!
    
    // MARK: Event monitors
    private var localKeyMonitor: Any?
    
    // MARK: Sizing
    private static let windowSize = NSSize(width: 500, height: 380)
    private static let minSize = NSSize(width: 400, height: 320)
    private static let maxSize = NSSize(width: 800, height: 700)
    private static let padding: CGFloat = 20
    private static let inputHeight: CGFloat = 140
    private static let resultHeight: CGFloat = 120
    
    // MARK: Colors
    private static let inputBgColor = NSColor.controlBackgroundColor
    private static let accentColor = NSColor.controlAccentColor
    private static let textColor = NSColor.labelColor
    private static let secondaryTextColor = NSColor.secondaryLabelColor
    
    // MARK: - Init
    
    override init() {
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        containerView = NSView()
        containerView.wantsLayer = true
        
        super.init()
        
        setupWindow()
        setupUI()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize(_:)),
            name: NSWindow.didResizeNotification,
            object: window
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Window Setup
    
    private func setupWindow() {
        window.title = "Tone Studio"
        window.isOpaque = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.hasShadow = true
        window.collectionBehavior = [.managed, .fullScreenAuxiliary]
        window.minSize = Self.minSize
        window.maxSize = Self.maxSize
        window.delegate = self
        
        containerView.frame = NSRect(origin: .zero, size: Self.windowSize)
        containerView.autoresizingMask = [.width, .height]
        window.contentView = containerView
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        let padding = Self.padding
        let contentWidth = Self.windowSize.width - padding * 2
        var yOffset = Self.windowSize.height - padding
        
        // Input section
        yOffset -= Self.inputHeight
        setupInputSection(at: yOffset, width: contentWidth, padding: padding)
        
        // Generate button
        yOffset -= 16
        yOffset -= 32
        setupGenerateButton(at: yOffset, width: contentWidth, padding: padding)
        
        // Status label (for errors only)
        yOffset -= 8
        yOffset -= 20
        setupStatusLabel(at: yOffset, width: contentWidth, padding: padding)
        
        // Result section
        yOffset -= 8
        yOffset -= Self.resultHeight
        setupResultSection(at: yOffset, width: contentWidth, padding: padding)
        
        // Action buttons
        yOffset -= 12
        setupActionButtons(at: yOffset, width: contentWidth, padding: padding)
        
        updateUIForState()
    }
    
    private func setupInputSection(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        // Input container with visible background
        let inputContainer = NSView(frame: NSRect(x: padding, y: y, width: width, height: Self.inputHeight))
        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = Self.inputBgColor.cgColor
        inputContainer.layer?.cornerRadius = 8
        inputContainer.layer?.borderWidth = 1
        inputContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        inputContainer.identifier = NSUserInterfaceItemIdentifier("inputContainer")
        containerView.addSubview(inputContainer)
        
        // Scroll view for text
        inputScrollView = NSScrollView(frame: NSRect(x: 8, y: 8, width: width - 16, height: Self.inputHeight - 16))
        inputScrollView.hasVerticalScroller = true
        inputScrollView.hasHorizontalScroller = false
        inputScrollView.autohidesScrollers = false
        inputScrollView.scrollerStyle = .overlay
        inputScrollView.borderType = .noBorder
        inputScrollView.drawsBackground = false
        inputScrollView.autoresizingMask = [.width, .height]
        
        // Text view with proper scrolling setup
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(containerSize: NSSize(width: width - 32, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        
        inputTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: width - 16, height: Self.inputHeight - 16), textContainer: textContainer)
        inputTextView.isEditable = true
        inputTextView.isSelectable = true
        inputTextView.isRichText = false
        inputTextView.font = .systemFont(ofSize: 14)
        inputTextView.textColor = Self.textColor
        inputTextView.backgroundColor = .clear
        inputTextView.drawsBackground = false
        inputTextView.isVerticallyResizable = true
        inputTextView.isHorizontallyResizable = false
        inputTextView.autoresizingMask = [.width]
        inputTextView.minSize = NSSize(width: 0, height: Self.inputHeight - 16)
        inputTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        inputTextView.delegate = self
        inputTextView.insertionPointColor = Self.accentColor
        inputTextView.allowsUndo = true
        
        inputScrollView.documentView = inputTextView
        inputContainer.addSubview(inputScrollView)
    }
    
    private func setupGenerateButton(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        generateButton = NSButton(frame: NSRect(x: padding + (width - 120) / 2, y: y, width: 120, height: 32))
        generateButton.title = "generate"
        generateButton.bezelStyle = .rounded
        generateButton.font = .systemFont(ofSize: 13, weight: .medium)
        generateButton.target = self
        generateButton.action = #selector(generateButtonClicked)
        generateButton.keyEquivalent = "\r"
        generateButton.keyEquivalentModifierMask = .command
        
        containerView.addSubview(generateButton)
    }
    
    private func setupStatusLabel(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = Self.secondaryTextColor
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: padding, y: y, width: width, height: 20)
        statusLabel.isHidden = true
        containerView.addSubview(statusLabel)
    }
    
    private func setupResultSection(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        // Result container with visible background
        resultContainer = NSView(frame: NSRect(x: padding, y: y, width: width, height: Self.resultHeight))
        resultContainer.wantsLayer = true
        resultContainer.layer?.backgroundColor = Self.inputBgColor.cgColor
        resultContainer.layer?.cornerRadius = 8
        resultContainer.layer?.borderWidth = 1
        resultContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        resultContainer.isHidden = true
        resultContainer.identifier = NSUserInterfaceItemIdentifier("resultContainer")
        containerView.addSubview(resultContainer)
        
        // Scroll view for result
        resultScrollView = NSScrollView(frame: NSRect(x: 8, y: 8, width: width - 16, height: Self.resultHeight - 16))
        resultScrollView.hasVerticalScroller = true
        resultScrollView.hasHorizontalScroller = false
        resultScrollView.autohidesScrollers = false
        resultScrollView.scrollerStyle = .overlay
        resultScrollView.borderType = .noBorder
        resultScrollView.drawsBackground = false
        resultScrollView.autoresizingMask = [.width, .height]
        
        // Result text view with proper scrolling setup
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(containerSize: NSSize(width: width - 32, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        
        resultTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: width - 16, height: Self.resultHeight - 16), textContainer: textContainer)
        resultTextView.isEditable = false
        resultTextView.isSelectable = true
        resultTextView.isRichText = false
        resultTextView.font = .systemFont(ofSize: 14)
        resultTextView.textColor = Self.textColor
        resultTextView.backgroundColor = .clear
        resultTextView.drawsBackground = false
        resultTextView.isVerticallyResizable = true
        resultTextView.isHorizontallyResizable = false
        resultTextView.autoresizingMask = [.width]
        resultTextView.minSize = NSSize(width: 0, height: Self.resultHeight - 16)
        resultTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        resultScrollView.documentView = resultTextView
        resultContainer.addSubview(resultScrollView)
    }
    
    private func setupActionButtons(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        // Copy button with icon
        copyButton = makeIconButton(symbolName: "doc.on.doc", tooltip: "copy")
        copyButton.target = self
        copyButton.action = #selector(copyButtonClicked)
        
        // Try again button with icon
        tryAgainButton = makeIconButton(symbolName: "arrow.clockwise", tooltip: "try again")
        tryAgainButton.target = self
        tryAgainButton.action = #selector(tryAgainButtonClicked)
        
        // Replace button
        replaceButton = NSButton(frame: .zero)
        replaceButton.title = "replace"
        replaceButton.bezelStyle = .rounded
        replaceButton.font = .systemFont(ofSize: 11)
        replaceButton.target = self
        replaceButton.action = #selector(replaceButtonClicked)
        replaceButton.setFrameSize(NSSize(width: 70, height: 24))
        
        // Separator
        let separator = NSBox(frame: NSRect(x: 0, y: 0, width: 1, height: 20))
        separator.boxType = .separator
        
        // Like button with icon
        likeButton = makeIconButton(symbolName: "hand.thumbsup", tooltip: "helpful")
        likeButton.target = self
        likeButton.action = #selector(likeButtonClicked)
        
        // Dislike button with icon
        dislikeButton = makeIconButton(symbolName: "hand.thumbsdown", tooltip: "not helpful")
        dislikeButton.target = self
        dislikeButton.action = #selector(dislikeButtonClicked)
        
        // Stack view: [copy] [try again] [replace] | [like] [dislike]
        actionButtonsStack = NSStackView(views: [copyButton, tryAgainButton, replaceButton, separator, likeButton, dislikeButton])
        actionButtonsStack.orientation = .horizontal
        actionButtonsStack.spacing = 8
        actionButtonsStack.alignment = .centerY
        let stackWidth: CGFloat = 280
        actionButtonsStack.frame = NSRect(x: padding + (width - stackWidth) / 2, y: y, width: stackWidth, height: 24)
        actionButtonsStack.isHidden = true
        containerView.addSubview(actionButtonsStack)
    }
    
    private func makeIconButton(symbolName: String, tooltip: String) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 28, height: 24))
        button.bezelStyle = .inline
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip)
        button.contentTintColor = Self.secondaryTextColor
        button.toolTip = tooltip
        button.setFrameSize(NSSize(width: 28, height: 24))
        return button
    }
    
    // MARK: - Show / Hide
    
    var isVisible: Bool {
        window.isVisible
    }
    
    func show() {
        // Center on screen
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - Self.windowSize.width / 2
        let y = screenFrame.midY - Self.windowSize.height / 2 + 50
        
        window.setFrame(NSRect(x: x, y: y, width: Self.windowSize.width, height: Self.windowSize.height), display: false)
        
        // Reset state
        currentState = .idle
        inputTextView.string = ""
        updateUIForState()
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Focus input
        window.makeFirstResponder(inputTextView)
        
        addEventMonitors()
        Logger.editor.info("Editor window shown")
    }
    
    func showWithText(_ text: String) {
        show()
        inputTextView.string = text
    }
    
    func hide() {
        removeEventMonitors()
        window.orderOut(nil)
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
    
    // MARK: - NSWindowDelegate
    
    nonisolated func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            removeEventMonitors()
            onClose?()
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
            generateButton.title = "generate"
            generateButton.isEnabled = true
            statusLabel.isHidden = true
            resultContainer.isHidden = true
            actionButtonsStack.isHidden = true
            
        case .loading:
            generateButton.title = "generating..."
            generateButton.isEnabled = false
            statusLabel.isHidden = true
            resultContainer.isHidden = true
            actionButtonsStack.isHidden = true
            
        case .result(let text):
            resultText = text
            generateButton.title = "generate"
            generateButton.isEnabled = true
            statusLabel.isHidden = true
            resultTextView.string = text
            resultContainer.isHidden = false
            actionButtonsStack.isHidden = false
            
            // Reset feedback state
            feedbackSubmitted = false
            likeButton.isEnabled = true
            dislikeButton.isEnabled = true
            likeButton.contentTintColor = Self.secondaryTextColor
            dislikeButton.contentTintColor = Self.secondaryTextColor
            
        case .error(let message):
            generateButton.title = "generate"
            generateButton.isEnabled = true
            statusLabel.stringValue = message
            statusLabel.textColor = NSColor.systemRed
            statusLabel.isHidden = false
            resultContainer.isHidden = true
            actionButtonsStack.isHidden = true
        }
    }
    
    // MARK: - Actions
    
    @objc private func generateButtonClicked() {
        let text = inputTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else {
            updateState(.error("please enter some text"))
            return
        }
        
        onGenerate?(text)
    }
    
    @objc private func copyButtonClicked() {
        guard !resultText.isEmpty else { return }
        onCopy?(resultText)
        
        // Visual feedback - briefly change icon color
        copyButton.contentTintColor = Self.accentColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.copyButton.contentTintColor = Self.secondaryTextColor
        }
    }
    
    @objc private func tryAgainButtonClicked() {
        onTryAgain?()
    }
    
    @objc private func replaceButtonClicked() {
        guard !resultText.isEmpty else { return }
        onReplace?(resultText)
        hide()
    }
    
    @objc private func likeButtonClicked() {
        guard !resultText.isEmpty, !feedbackSubmitted else { return }
        feedbackSubmitted = true
        
        // Visual feedback
        likeButton.contentTintColor = NSColor.systemGreen
        dislikeButton.isEnabled = false
        dislikeButton.contentTintColor = Self.secondaryTextColor.withAlphaComponent(0.3)
        
        onLike?(resultText)
    }
    
    @objc private func dislikeButtonClicked() {
        guard !resultText.isEmpty, !feedbackSubmitted else { return }
        feedbackSubmitted = true
        
        // Visual feedback
        dislikeButton.contentTintColor = NSColor.systemRed
        likeButton.isEnabled = false
        likeButton.contentTintColor = Self.secondaryTextColor.withAlphaComponent(0.3)
        
        onDislike?(resultText)
    }
    
    // MARK: - Window Resize
    
    @objc func windowDidResize(_ notification: Notification) {
        let newSize = window.frame.size
        let padding = Self.padding
        let contentWidth = newSize.width - padding * 2
        
        // Update input container
        if let inputContainer = containerView.subviews.first(where: { $0.identifier?.rawValue == "inputContainer" }) {
            inputContainer.frame.size.width = contentWidth
            inputScrollView.frame.size.width = contentWidth - 16
            inputTextView.textContainer?.containerSize.width = contentWidth - 32
        }
        
        // Update generate button position
        generateButton.frame.origin.x = padding + (contentWidth - 120) / 2
        
        // Update status label
        statusLabel.frame.size.width = contentWidth
        
        // Update result container
        resultContainer.frame.size.width = contentWidth
        resultScrollView.frame.size.width = contentWidth - 16
        resultTextView.textContainer?.containerSize.width = contentWidth - 32
        
        // Update action buttons position
        let stackWidth: CGFloat = 280
        actionButtonsStack.frame.origin.x = padding + (contentWidth - stackWidth) / 2
    }
    
    // MARK: - Event Monitors
    
    private func addEventMonitors() {
        // Local key monitor for Escape and Cmd+Enter
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window.isKeyWindow else { return event }
            
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
    }
    
    private func removeEventMonitors() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
}

// MARK: - NSTextViewDelegate

extension EditorWindow: NSTextViewDelegate {
    nonisolated func textDidChange(_ notification: Notification) {
        // Could add character count or other feedback here
    }
}
