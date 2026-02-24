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
    
    // MARK: Panel & Views
    private let panel: KeyablePanel
    private let containerView: NSVisualEffectView
    
    private var avatarImageView: NSImageView!
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
    private var closeButton: NSButton!
    private var feedbackSubmitted: Bool = false
    private var titleLabel: NSTextField!
    private var loadingIndicator: NSProgressIndicator!
    private var statusLabel: NSTextField!
    private var resultContainer: NSView!
    private var actionButtonsStack: NSStackView!
    
    // MARK: Event monitors
    private var localKeyMonitor: Any?
    private var globalClickMonitor: Any?
    
    // MARK: Sizing
    private static let windowSize = NSSize(width: 500, height: 340)
    private static let minSize = NSSize(width: 400, height: 300)
    private static let maxSize = NSSize(width: 800, height: 600)
    private static let cornerRadius: CGFloat = 16
    private static let padding: CGFloat = 20
    private static let inputHeight: CGFloat = 120
    private static let resultHeight: CGFloat = 100
    
    // MARK: Colors
    private static let inputBgColor = NSColor.textBackgroundColor.withAlphaComponent(0.3)
    private static let accentColor = NSColor.controlAccentColor
    private static let textColor = NSColor.labelColor
    private static let secondaryTextColor = NSColor.secondaryLabelColor
    
    // MARK: - Init
    
    override init() {
        panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize(_:)),
            name: NSWindow.didResizeNotification,
            object: panel
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
        panel.minSize = Self.minSize
        panel.maxSize = Self.maxSize
        
        containerView.frame = NSRect(origin: .zero, size: Self.windowSize)
        containerView.autoresizingMask = [.width, .height]
        panel.contentView = containerView
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        let padding = Self.padding
        let contentWidth = Self.windowSize.width - padding * 2
        var yOffset = Self.windowSize.height - padding
        
        // Title bar with avatar and close button
        yOffset -= 28
        setupTitleBar(at: yOffset, width: contentWidth, padding: padding)
        
        // Input section
        yOffset -= 16
        yOffset -= Self.inputHeight
        setupInputSection(at: yOffset, width: contentWidth, padding: padding)
        
        // Generate button
        yOffset -= 16
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
        // Avatar
        let avatarSize: CGFloat = 24
        avatarImageView = makeAvatarImageView(size: avatarSize)
        avatarImageView.frame = NSRect(x: padding, y: y + 2, width: avatarSize, height: avatarSize)
        containerView.addSubview(avatarImageView)
        
        // Title (beside avatar)
        titleLabel = NSTextField(labelWithString: "Tone Studio")
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = Self.textColor
        titleLabel.frame = NSRect(x: padding + avatarSize + 10, y: y + 4, width: width - avatarSize - 40, height: 20)
        containerView.addSubview(titleLabel)
        
        // Close button (right side)
        closeButton = NSButton(frame: NSRect(x: Self.windowSize.width - padding - 20, y: y + 4, width: 20, height: 20))
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.contentTintColor = Self.secondaryTextColor
        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked)
        containerView.addSubview(closeButton)
    }
    
    private func setupInputSection(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        // Input container - no border, subtle background
        let inputContainer = NSView(frame: NSRect(x: padding, y: y, width: width, height: Self.inputHeight))
        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = Self.inputBgColor.cgColor
        inputContainer.layer?.cornerRadius = 10
        inputContainer.identifier = NSUserInterfaceItemIdentifier("inputContainer")
        containerView.addSubview(inputContainer)
        
        // Scroll view for text
        inputScrollView = NSScrollView(frame: NSRect(x: 10, y: 10, width: width - 20, height: Self.inputHeight - 20))
        inputScrollView.hasVerticalScroller = true
        inputScrollView.hasHorizontalScroller = false
        inputScrollView.autohidesScrollers = true
        inputScrollView.borderType = .noBorder
        inputScrollView.drawsBackground = false
        inputScrollView.autoresizingMask = [.width, .height]
        
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
        inputTextView.textContainer?.containerSize = NSSize(width: width - 36, height: .greatestFiniteMagnitude)
        inputTextView.delegate = self
        inputTextView.insertionPointColor = Self.accentColor
        
        inputScrollView.documentView = inputTextView
        inputContainer.addSubview(inputScrollView)
    }
    
    private func setupGenerateButton(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        generateButton = NSButton(frame: NSRect(x: padding + (width - 100) / 2, y: y, width: 100, height: 28))
        generateButton.title = "generate"
        generateButton.bezelStyle = .rounded
        generateButton.font = .systemFont(ofSize: 12, weight: .medium)
        generateButton.target = self
        generateButton.action = #selector(generateButtonClicked)
        generateButton.keyEquivalent = "\r"
        generateButton.keyEquivalentModifierMask = .command
        
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
        // Result container - no border, subtle background
        resultContainer = NSView(frame: NSRect(x: padding, y: y, width: width, height: Self.resultHeight))
        resultContainer.wantsLayer = true
        resultContainer.layer?.backgroundColor = Self.inputBgColor.cgColor
        resultContainer.layer?.cornerRadius = 10
        resultContainer.isHidden = true
        resultContainer.identifier = NSUserInterfaceItemIdentifier("resultContainer")
        containerView.addSubview(resultContainer)
        
        // Scroll view for result
        resultScrollView = NSScrollView(frame: NSRect(x: 10, y: 10, width: width - 20, height: Self.resultHeight - 20))
        resultScrollView.hasVerticalScroller = true
        resultScrollView.hasHorizontalScroller = false
        resultScrollView.autohidesScrollers = true
        resultScrollView.borderType = .noBorder
        resultScrollView.drawsBackground = false
        resultScrollView.autoresizingMask = [.width, .height]
        
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
        resultTextView.textContainer?.containerSize = NSSize(width: width - 36, height: .greatestFiniteMagnitude)
        
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
    
    // MARK: - Avatar Helper
    
    private func makeAvatarImageView(size: CGFloat) -> NSImageView {
        let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        imageView.image = NSImage(named: "ai_avatar")
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = size / 2
        imageView.layer?.masksToBounds = true
        return imageView
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
        
        panel.setFrame(NSRect(x: x, y: y, width: Self.windowSize.width, height: Self.windowSize.height), display: false)
        
        // Reset state
        currentState = .idle
        inputTextView.string = ""
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
            
            // Reset feedback state
            feedbackSubmitted = false
            likeButton.isEnabled = true
            dislikeButton.isEnabled = true
            likeButton.contentTintColor = Self.secondaryTextColor
            dislikeButton.contentTintColor = Self.secondaryTextColor
            
        case .error(let message):
            loadingIndicator.stopAnimation(nil)
            loadingIndicator.isHidden = true
            statusLabel.stringValue = message
            statusLabel.textColor = NSColor.systemRed
            statusLabel.isHidden = false
            resultContainer.isHidden = true
            actionButtonsStack.isHidden = true
            generateButton.isEnabled = true
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
    
    @objc private func closeButtonClicked() {
        hide()
    }
    
    // MARK: - Window Resize
    
    @objc private func windowDidResize(_ notification: Notification) {
        let newSize = panel.frame.size
        let padding = Self.padding
        let contentWidth = newSize.width - padding * 2
        
        // Update close button position
        closeButton.frame.origin.x = newSize.width - padding - 20
        
        // Update title label width
        let avatarSize: CGFloat = 24
        titleLabel.frame.size.width = contentWidth - avatarSize - 40
        
        // Update input container
        if let inputContainer = containerView.subviews.first(where: { $0.identifier?.rawValue == "inputContainer" }) {
            inputContainer.frame.size.width = contentWidth
            inputScrollView.frame.size.width = contentWidth - 20
            inputTextView.textContainer?.containerSize.width = contentWidth - 36
        }
        
        // Update generate button position
        generateButton.frame.origin.x = padding + (contentWidth - 100) / 2
        
        // Update status area
        loadingIndicator.frame.origin.x = padding + (contentWidth - 20) / 2
        statusLabel.frame.size.width = contentWidth
        
        // Update result container
        resultContainer.frame.size.width = contentWidth
        resultScrollView.frame.size.width = contentWidth - 20
        resultTextView.textContainer?.containerSize.width = contentWidth - 36
        
        // Update action buttons position
        let stackWidth: CGFloat = 280
        actionButtonsStack.frame.origin.x = padding + (contentWidth - stackWidth) / 2
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
            
            // Convert to screen coordinates
            let screenPoint = NSEvent.mouseLocation
            
            if !self.panel.frame.contains(screenPoint) {
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
