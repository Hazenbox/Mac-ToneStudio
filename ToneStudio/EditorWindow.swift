import Cocoa
import OSLog
import SwiftUI

// MARK: - Editor Window

@MainActor
final class EditorWindow: NSObject, NSWindowDelegate {
    
    // MARK: Callbacks
    var onGenerate: ((String) -> Void)?
    var onCopy: ((String) -> Void)?
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
    
    private var inputContainer: NSView!
    private var inputTextView: NSTextView!
    private var inputScrollView: NSScrollView!
    private var generateButton: NSButton!
    private var resultMarkdownView: MarkdownHostingView!
    private var resultScrollView: NSScrollView!
    private var copyButton: NSButton!
    private var tryAgainButton: NSButton!
    private var likeButton: NSButton!
    private var dislikeButton: NSButton!
    private var feedbackSubmitted: Bool = false
    private var errorLabel: NSTextField!
    private var resultContainer: NSView!
    private var actionButtonsStack: NSStackView!
    
    // MARK: Event monitors
    private var localKeyMonitor: Any?
    
    // MARK: Sizing
    private static let windowSize = NSSize(width: 480, height: 340)
    private static let minSize = NSSize(width: 400, height: 300)
    private static let maxSize = NSSize(width: 800, height: 700)
    private static let padding: CGFloat = 16
    private static let inputHeight: CGFloat = 120
    private static let resultHeight: CGFloat = 100
    
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
        var yOffset = Self.windowSize.height - padding - 8  // Extra top padding
        
        // Input section with inline generate button
        yOffset -= Self.inputHeight
        setupInputSection(at: yOffset, width: contentWidth, padding: padding)
        
        // Error label (below input, only shown on error)
        yOffset -= 4
        yOffset -= 16
        setupErrorLabel(at: yOffset, width: contentWidth, padding: padding)
        
        // Result section
        yOffset -= 8
        yOffset -= Self.resultHeight
        setupResultSection(at: yOffset, width: contentWidth, padding: padding)
        
        // Action buttons (bottom-left of result)
        yOffset -= 6
        setupActionButtons(at: yOffset, width: contentWidth, padding: padding)
        
        updateUIForState()
    }
    
    private func setupInputSection(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        // Input container - clean, no border
        inputContainer = NSView(frame: NSRect(x: padding, y: y, width: width, height: Self.inputHeight))
        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = Self.inputBgColor.cgColor
        inputContainer.layer?.cornerRadius = 12
        inputContainer.identifier = NSUserInterfaceItemIdentifier("inputContainer")
        containerView.addSubview(inputContainer)
        
        // Generate button - inline at bottom-right of input container
        generateButton = NSButton(frame: NSRect(x: width - 96, y: 8, width: 88, height: 28))
        generateButton.title = "generate"
        generateButton.bezelStyle = .rounded
        generateButton.font = .systemFont(ofSize: 12, weight: .medium)
        generateButton.target = self
        generateButton.action = #selector(generateButtonClicked)
        generateButton.keyEquivalent = "\r"
        generateButton.keyEquivalentModifierMask = .command
        inputContainer.addSubview(generateButton)
        
        // Scroll view for text - above the button
        let scrollHeight = Self.inputHeight - 44  // Leave room for button
        inputScrollView = NSScrollView(frame: NSRect(x: 12, y: 40, width: width - 24, height: scrollHeight))
        inputScrollView.hasVerticalScroller = true
        inputScrollView.hasHorizontalScroller = false
        inputScrollView.autohidesScrollers = true
        inputScrollView.scrollerStyle = .overlay
        inputScrollView.borderType = .noBorder
        inputScrollView.drawsBackground = false
        
        // Text view
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(containerSize: NSSize(width: width - 48, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        
        inputTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: width - 24, height: scrollHeight), textContainer: textContainer)
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
        inputTextView.minSize = NSSize(width: 0, height: scrollHeight)
        inputTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        inputTextView.delegate = self
        inputTextView.insertionPointColor = Self.accentColor
        inputTextView.allowsUndo = true
        
        inputScrollView.documentView = inputTextView
        inputContainer.addSubview(inputScrollView)
    }
    
    private func setupErrorLabel(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        errorLabel = NSTextField(labelWithString: "")
        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.textColor = NSColor.systemRed
        errorLabel.alignment = .left
        errorLabel.frame = NSRect(x: padding, y: y, width: width, height: 16)
        errorLabel.isHidden = true
        containerView.addSubview(errorLabel)
    }
    
    private func setupResultSection(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        // Result container - clean, no border
        resultContainer = NSView(frame: NSRect(x: padding, y: y, width: width, height: Self.resultHeight))
        resultContainer.wantsLayer = true
        resultContainer.layer?.backgroundColor = Self.inputBgColor.cgColor
        resultContainer.layer?.cornerRadius = 12
        resultContainer.isHidden = true
        resultContainer.identifier = NSUserInterfaceItemIdentifier("resultContainer")
        containerView.addSubview(resultContainer)
        
        // Scroll view for result
        resultScrollView = NSScrollView(frame: NSRect(x: 12, y: 12, width: width - 24, height: Self.resultHeight - 24))
        resultScrollView.hasVerticalScroller = true
        resultScrollView.hasHorizontalScroller = false
        resultScrollView.autohidesScrollers = true
        resultScrollView.scrollerStyle = .overlay
        resultScrollView.borderType = .noBorder
        resultScrollView.drawsBackground = false
        
        // Result markdown view with flipped coordinate container
        let flippedContainer = FlippedView(frame: NSRect(x: 0, y: 0, width: width - 24, height: Self.resultHeight - 24))
        
        resultMarkdownView = MarkdownHostingView()
        resultMarkdownView.frame = NSRect(x: 0, y: 0, width: width - 48, height: Self.resultHeight - 24)
        resultMarkdownView.autoresizingMask = [.width]
        flippedContainer.addSubview(resultMarkdownView)
        
        resultScrollView.documentView = flippedContainer
        resultContainer.addSubview(resultScrollView)
    }
    
    private final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }
    
    private func setupActionButtons(at y: CGFloat, width: CGFloat, padding: CGFloat) {
        // Icon-only buttons
        copyButton = makeIconButton(symbolName: "doc.on.doc", tooltip: "copy")
        copyButton.target = self
        copyButton.action = #selector(copyButtonClicked)
        
        tryAgainButton = makeIconButton(symbolName: "arrow.clockwise", tooltip: "regenerate")
        tryAgainButton.target = self
        tryAgainButton.action = #selector(tryAgainButtonClicked)
        
        likeButton = makeIconButton(symbolName: "hand.thumbsup", tooltip: "helpful")
        likeButton.target = self
        likeButton.action = #selector(likeButtonClicked)
        
        dislikeButton = makeIconButton(symbolName: "hand.thumbsdown", tooltip: "not helpful")
        dislikeButton.target = self
        dislikeButton.action = #selector(dislikeButtonClicked)
        
        // Left-aligned action bar (like ChatGPT)
        actionButtonsStack = NSStackView(views: [copyButton, tryAgainButton, likeButton, dislikeButton])
        actionButtonsStack.orientation = .horizontal
        actionButtonsStack.spacing = 4
        actionButtonsStack.alignment = .centerY
        let stackWidth: CGFloat = 120
        actionButtonsStack.frame = NSRect(x: padding, y: y, width: stackWidth, height: 24)
        actionButtonsStack.isHidden = true
        containerView.addSubview(actionButtonsStack)
    }
    
    private func makeIconButton(symbolName: String, tooltip: String) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 26, height: 22))
        button.bezelStyle = .inline
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip)
        button.contentTintColor = Self.secondaryTextColor
        button.toolTip = tooltip
        button.setFrameSize(NSSize(width: 26, height: 22))
        return button
    }
    
    // MARK: - Show / Hide
    
    var isVisible: Bool {
        window.isVisible
    }
    
    func show() {
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
        NSApp.activate(ignoringOtherApps: false)
        
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
            errorLabel.isHidden = true
            resultContainer.isHidden = true
            actionButtonsStack.isHidden = true
            
        case .loading:
            generateButton.title = "..."
            generateButton.isEnabled = false
            errorLabel.isHidden = true
            resultContainer.isHidden = true
            actionButtonsStack.isHidden = true
            
        case .result(let text):
            resultText = text
            generateButton.title = "generate"
            generateButton.isEnabled = true
            errorLabel.isHidden = true
            
            // Update markdown view with result
            let availableWidth = resultScrollView.frame.width - 24
            resultMarkdownView.configure(content: text, maxWidth: availableWidth)
            
            // Update scroll view document size based on markdown content height
            let contentHeight = max(resultMarkdownView.calculatedHeight, Self.resultHeight - 24)
            resultMarkdownView.frame.size.height = contentHeight
            if let flippedContainer = resultScrollView.documentView {
                flippedContainer.frame.size.height = contentHeight
            }
            
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
            errorLabel.stringValue = message
            errorLabel.isHidden = false
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
        
        copyButton.contentTintColor = Self.accentColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.copyButton.contentTintColor = Self.secondaryTextColor
        }
    }
    
    @objc private func tryAgainButtonClicked() {
        onTryAgain?()
    }
    
    @objc private func likeButtonClicked() {
        guard !resultText.isEmpty, !feedbackSubmitted else { return }
        feedbackSubmitted = true
        
        likeButton.contentTintColor = NSColor.systemGreen
        dislikeButton.isEnabled = false
        dislikeButton.contentTintColor = Self.secondaryTextColor.withAlphaComponent(0.3)
        
        onLike?(resultText)
    }
    
    @objc private func dislikeButtonClicked() {
        guard !resultText.isEmpty, !feedbackSubmitted else { return }
        feedbackSubmitted = true
        
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
        inputContainer.frame.size.width = contentWidth
        inputScrollView.frame.size.width = contentWidth - 24
        inputTextView.textContainer?.containerSize.width = contentWidth - 48
        generateButton.frame.origin.x = contentWidth - 96
        
        // Update error label
        errorLabel.frame.size.width = contentWidth
        
        // Update result container
        resultContainer.frame.size.width = contentWidth
        resultScrollView.frame.size.width = contentWidth - 24
        resultMarkdownView.frame.size.width = contentWidth - 48
    }
    
    // MARK: - Event Monitors
    
    private func addEventMonitors() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window.isKeyWindow else { return event }
            
            if event.keyCode == 53 {
                self.hide()
                return nil
            }
            
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
    }
}
