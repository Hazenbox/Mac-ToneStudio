import Cocoa
import OSLog

// MARK: - Tooltip States

enum TooltipState: Equatable {
    case miniIcon
    case noSelection
    case optionsMenu
    case chatWindow
    case chatLoading
    case error(String)
    
    static func == (lhs: TooltipState, rhs: TooltipState) -> Bool {
        switch (lhs, rhs) {
        case (.miniIcon, .miniIcon),
             (.noSelection, .noSelection),
             (.optionsMenu, .optionsMenu),
             (.chatWindow, .chatWindow),
             (.chatLoading, .chatLoading):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Chat Message Model

struct ChatMessage {
    enum Role {
        case user
        case assistant
        case action
    }
    let role: Role
    let content: String
}

// MARK: - Speech Bubble Tail View

final class BubbleTailView: NSView {
    var fillColor: NSColor = NSColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1)

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath()
        let w = bounds.width
        let h = bounds.height
        path.move(to: CGPoint(x: w / 2 - 7, y: h))
        path.line(to: CGPoint(x: w / 2 + 7, y: h))
        path.line(to: CGPoint(x: w / 2, y: 0))
        path.close()
        fillColor.setFill()
        path.fill()
    }
}

// MARK: - Dark Bubble Container View

final class BubbleContainerView: NSView {
    static let tailHeight: CGFloat = 8
    static let cornerRadius: CGFloat = 22

    private(set) var bubbleLayer: CALayer!
    private(set) var tailLayer: CAShapeLayer!

    var bubbleColor: NSColor = NSColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1) {
        didSet { updateColors() }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        setupLayers()
    }

    private func setupLayers() {
        guard let layer = layer else { return }
        let th = BubbleContainerView.tailHeight
        let cr = BubbleContainerView.cornerRadius

        let bubbleRect = CGRect(x: 0, y: th, width: bounds.width, height: bounds.height - th)

        let bLayer = CALayer()
        bLayer.frame = bubbleRect
        bLayer.backgroundColor = bubbleColor.cgColor
        bLayer.cornerRadius = cr
        bLayer.masksToBounds = true
        layer.addSublayer(bLayer)
        bubbleLayer = bLayer

        let tailW: CGFloat = 14
        let tailMidX = bounds.width / 2
        let tLayer = CAShapeLayer()
        tLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: th)
        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: tailMidX - tailW / 2, y: th))
        tailPath.addLine(to: CGPoint(x: tailMidX + tailW / 2, y: th))
        tailPath.addLine(to: CGPoint(x: tailMidX, y: 0))
        tailPath.closeSubpath()
        tLayer.path = tailPath
        tLayer.fillColor = bubbleColor.cgColor
        layer.addSublayer(tLayer)
        tailLayer = tLayer
    }

    private func updateColors() {
        bubbleLayer?.backgroundColor = bubbleColor.cgColor
        tailLayer?.fillColor = bubbleColor.cgColor
    }
}

// MARK: - TooltipWindow

@MainActor
final class TooltipWindow: NSObject, NSTextFieldDelegate {

    // MARK: - Callbacks
    var onRephrase: (() -> Void)?
    var onReplace: ((String) -> Void)?
    var onCopy: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onRetry: (() -> Void)?
    var onCustomPrompt: ((String) -> Void)?
    var onFeedback: ((String, String) -> Void)?
    var onRegenerate: (() -> Void)?

    // MARK: - Panel
    private let panel: NSPanel
    private let containerView: NSView
    private var currentState: TooltipState = .optionsMenu

    // MARK: - Conversation State
    private var selectedText: String = ""
    private var lastAction: String = ""
    private var conversationMessages: [ChatMessage] = []
    private var lastResponse: String = ""
    private var isLoadingInline: Bool = false

    // MARK: - UI References
    private var inputField: NSTextField?
    private var chatScrollView: NSScrollView?
    private var chatContentView: NSView?
    private var inlineSpinner: NSProgressIndicator?

    // MARK: - Event monitors
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?
    
    // MARK: - Auto-hide timer
    private var autoHideTimer: Timer?

    // MARK: - Sizing (Figma specs)
    private static let miniIconSize = AppConstants.miniIconSize
    private static let noSelectionSize = NSSize(width: 160, height: 36)
    private static let tailHeight: CGFloat = BubbleContainerView.tailHeight
    private static let bubbleCorner: CGFloat = BubbleContainerView.cornerRadius
    
    private static let optionsMenuSize = NSSize(width: 335, height: 220)
    private static let chatWindowWidth: CGFloat = 335
    private static let chatWindowMinHeight: CGFloat = 428
    private static let chatWindowMaxHeight: CGFloat = 500
    private static let errorWidth: CGFloat = 300
    private static let cardCornerRadius: CGFloat = 15
    private static let innerCornerRadius: CGFloat = 11
    private static let pillCornerRadius: CGFloat = 21

    // MARK: - Colors (Figma specs)
    private static let darkBubbleBG  = NSColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1)
    private static let cardBG        = NSColor(red: 0.145, green: 0.145, blue: 0.149, alpha: 1) // #252526
    private static let innerPanelBG  = NSColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1)   // #1c1c1c
    private static let cardBorder    = NSColor.clear
    private static let primaryText   = NSColor.white
    private static let secondaryText = NSColor.white.withAlphaComponent(0.4)
    private static let titleText     = NSColor.white.withAlphaComponent(0.8)
    private static let inputBG       = NSColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1)   // #1c1c1c
    private static let buttonBG      = NSColor.white.withAlphaComponent(0.06)                  // rgba(255,255,255,0.06)
    private static let actionPillBG  = NSColor.white.withAlphaComponent(0.06)                  // rgba(255,255,255,0.06)

    // MARK: - Positioning Constants
    private static let horizontalGap: CGFloat = 4
    private static let screenEdgePadding: CGFloat = 8

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow

        containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = containerView
        
        super.init()
    }

    // MARK: - Public Methods

    func setSelectedText(_ text: String) {
        selectedText = text
    }
    
    func getSelectedText() -> String {
        return selectedText
    }
    
    func getLastResponse() -> String {
        return lastResponse
    }
    
    func appendMessage(_ message: ChatMessage) {
        conversationMessages.append(message)
        if message.role == .assistant {
            lastResponse = message.content
        }
    }
    
    func clearConversation() {
        conversationMessages.removeAll()
        lastResponse = ""
        lastAction = ""
        isLoadingInline = false
    }
    
    func showInlineLoading() {
        isLoadingInline = true
        rebuildChatContent()
    }
    
    func hideInlineLoading() {
        isLoadingInline = false
    }
    
    func setLastAction(_ action: String) {
        lastAction = action
    }

    // MARK: - Show / Hide

    func show(near cursorRect: CGRect) {
        showInternal(near: cursorRect, state: .optionsMenu, size: Self.optionsMenuSize)
    }
    
    func showMiniIcon(for selection: SelectionResult) {
        let size = NSSize(width: Self.miniIconSize, height: Self.miniIconSize)
        showAtSelectionStart(selection: selection, state: .miniIcon, size: size)
        startAutoHideTimer(delay: AppConstants.miniIconAutoHideDelay)
    }
    
    func showMiniIcon(near cursorRect: CGRect) {
        let size = NSSize(width: Self.miniIconSize, height: Self.miniIconSize)
        showInternal(near: cursorRect, state: .miniIcon, size: size, offsetRight: true)
        startAutoHideTimer(delay: AppConstants.miniIconAutoHideDelay)
    }
    
    func showNoSelection(near cursorRect: CGRect) {
        showInternal(near: cursorRect, state: .noSelection, size: Self.noSelectionSize)
        startAutoHideTimer(delay: AppConstants.noSelectionAutoHideDelay)
    }
    
    func showOptionsMenu(for selection: SelectionResult) {
        showAtSelectionStart(selection: selection, state: .optionsMenu, size: Self.optionsMenuSize)
    }

    private func showAtSelectionStart(selection: SelectionResult, state: TooltipState, size: NSSize) {
        cancelAutoHideTimer()
        
        guard selection.hasPreciseBounds else {
            let isDoubleClick = selection.isDoubleClickSelection
            let anchorPoint = isDoubleClick ? selection.selectionStartPoint : selection.visualLeftEdgePoint
            
            let screen = NSScreen.screens.first { $0.frame.contains(anchorPoint) } ?? NSScreen.main!
            let visibleFrame = screen.visibleFrame
            
            var origin: CGPoint
            
            if isDoubleClick {
                origin = CGPoint(
                    x: anchorPoint.x + Self.horizontalGap + 10,
                    y: anchorPoint.y - size.height / 2
                )
                if origin.x + size.width > visibleFrame.maxX - Self.screenEdgePadding {
                    origin.x = anchorPoint.x - size.width - Self.horizontalGap - 10
                }
            } else {
                origin = CGPoint(
                    x: anchorPoint.x - size.width - Self.horizontalGap,
                    y: anchorPoint.y - size.height / 2
                )
                if origin.x < visibleFrame.minX + Self.screenEdgePadding {
                    origin.x = anchorPoint.x + Self.horizontalGap
                }
            }
            
            origin = handleVerticalOverflow(origin: origin, size: size, visibleFrame: visibleFrame)
            origin.x = max(visibleFrame.minX + Self.screenEdgePadding,
                           min(origin.x, visibleFrame.maxX - size.width - Self.screenEdgePadding))
            
            panel.setFrame(NSRect(origin: origin, size: size), display: false)
            buildUIForState(state, size: size)
            
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                panel.animator().alphaValue = 1
            }
            
            addEventMonitors()
            return
        }
        
        let anchorPoint = selection.tooltipAnchorPoint
        let lineHeight = selection.lineHeight
        let selectionBounds = selection.firstLineBounds
        
        let screen = NSScreen.screens.first { $0.frame.contains(anchorPoint) } ?? NSScreen.main!
        let visibleFrame = screen.visibleFrame
        
        var origin = calculateLeftEdgePosition(
            anchorPoint: anchorPoint,
            lineHeight: lineHeight,
            tooltipSize: size,
            visibleFrame: visibleFrame
        )
        
        if origin.x < visibleFrame.minX + Self.screenEdgePadding {
            origin = calculateRightEdgePosition(
                selectionBounds: selectionBounds,
                lineHeight: lineHeight,
                tooltipSize: size,
                visibleFrame: visibleFrame
            )
        }
        
        origin = handleVerticalOverflow(origin: origin, size: size, visibleFrame: visibleFrame)
        origin.x = max(visibleFrame.minX + Self.screenEdgePadding,
                       min(origin.x, visibleFrame.maxX - size.width - Self.screenEdgePadding))
        
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        buildUIForState(state, size: size)
        
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }
        
        addEventMonitors()
    }
    
    private func buildUIForState(_ state: TooltipState, size: NSSize) {
        switch state {
        case .miniIcon:
            buildMiniIconUI(size: size)
        case .optionsMenu:
            buildOptionsMenuUI(size: size)
        case .chatWindow, .chatLoading:
            buildChatWindowUI(size: size)
        default:
            break
        }
    }
    
    private func calculateLeftEdgePosition(
        anchorPoint: CGPoint,
        lineHeight: CGFloat,
        tooltipSize: NSSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        return CGPoint(
            x: anchorPoint.x - tooltipSize.width - Self.horizontalGap,
            y: anchorPoint.y - tooltipSize.height / 2
        )
    }
    
    private func calculateRightEdgePosition(
        selectionBounds: CGRect,
        lineHeight: CGFloat,
        tooltipSize: NSSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        return CGPoint(
            x: selectionBounds.maxX + Self.horizontalGap,
            y: selectionBounds.midY - tooltipSize.height / 2
        )
    }
    
    private func handleVerticalOverflow(origin: CGPoint, size: NSSize, visibleFrame: CGRect) -> CGPoint {
        var adjustedOrigin = origin
        
        if adjustedOrigin.y + size.height > visibleFrame.maxY - Self.screenEdgePadding {
            adjustedOrigin.y = visibleFrame.maxY - size.height - Self.screenEdgePadding
        }
        
        if adjustedOrigin.y < visibleFrame.minY + Self.screenEdgePadding {
            adjustedOrigin.y = visibleFrame.minY + Self.screenEdgePadding
        }
        
        return adjustedOrigin
    }
    
    private func showInternal(near cursorRect: CGRect, state: TooltipState, size: NSSize, offsetRight: Bool = false) {
        cancelAutoHideTimer()
        
        let cursorPoint = NSPoint(x: cursorRect.midX, y: cursorRect.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(cursorPoint) } ?? NSScreen.main!
        let visibleFrame = screen.visibleFrame

        var origin: CGPoint
        if offsetRight {
            origin = CGPoint(
                x: cursorPoint.x + 20,
                y: cursorPoint.y - size.height / 2
            )
        } else {
            origin = CGPoint(
                x: cursorPoint.x - size.width / 2,
                y: cursorPoint.y + 16
            )
        }

        origin.x = max(visibleFrame.minX + Self.screenEdgePadding,
                       min(origin.x, visibleFrame.maxX - size.width - Self.screenEdgePadding))
        origin = handleVerticalOverflow(origin: origin, size: size, visibleFrame: visibleFrame)

        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        buildUIForState(state, size: size)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }

        addEventMonitors()
    }
    
    private func startAutoHideTimer(delay: TimeInterval) {
        cancelAutoHideTimer()
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }
    
    private func cancelAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }

    func hide() {
        cancelAutoHideTimer()
        removeEventMonitors()
        clearConversation()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { [weak self] in
                self?.panel.orderOut(nil)
            }
        }
    }

    var isVisible: Bool { panel.isVisible }
    var windowFrame: NSRect { panel.frame }

    var isInteracting: Bool {
        switch currentState {
        case .chatWindow, .chatLoading, .error, .optionsMenu:
            return true
        case .miniIcon, .noSelection:
            return false
        }
    }
    
    var isMiniIcon: Bool {
        if case .miniIcon = currentState { return true }
        return false
    }

    // MARK: - Public state updater

    func updateUI(_ state: TooltipState) {
        cancelAutoHideTimer()
        currentState = state
        
        switch state {
        case .miniIcon:
            panel.isMovableByWindowBackground = false
            let size = NSSize(width: Self.miniIconSize, height: Self.miniIconSize)
            buildMiniIconUI(size: size)
            resizeAndReanchor(to: size)
            startAutoHideTimer(delay: AppConstants.miniIconAutoHideDelay)
            
        case .noSelection:
            panel.isMovableByWindowBackground = false
            buildNoSelectionUI(size: Self.noSelectionSize)
            resizeAndReanchor(to: Self.noSelectionSize)
            startAutoHideTimer(delay: AppConstants.noSelectionAutoHideDelay)
            
        case .optionsMenu:
            panel.isMovableByWindowBackground = false
            buildOptionsMenuUI(size: Self.optionsMenuSize)
            resizeAndReanchor(to: Self.optionsMenuSize)
            
        case .chatWindow:
            panel.isMovableByWindowBackground = true
            let height = calculateChatWindowHeight()
            let size = NSSize(width: Self.chatWindowWidth, height: height)
            buildChatWindowUI(size: size)
            resizeAndReanchor(to: size)
            
        case .chatLoading:
            panel.isMovableByWindowBackground = true
            isLoadingInline = true
            let height = calculateChatWindowHeight()
            let size = NSSize(width: Self.chatWindowWidth, height: height)
            buildChatWindowUI(size: size)
            resizeAndReanchor(to: size)
            
        case .error(let message):
            panel.isMovableByWindowBackground = true
            let height: CGFloat = 100
            buildErrorUI(message: message)
            resizeAndReanchor(to: NSSize(width: Self.errorWidth, height: height))
        }
    }
    
    private func calculateChatWindowHeight() -> CGFloat {
        var contentHeight: CGFloat = 120
        
        if !selectedText.isEmpty {
            contentHeight += estimateTextHeight(selectedText, width: Self.chatWindowWidth - 80, fontSize: 13) + 20
        }
        
        if !lastAction.isEmpty {
            contentHeight += 40
        }
        
        for message in conversationMessages {
            if message.role == .assistant {
                contentHeight += estimateTextHeight(message.content, width: Self.chatWindowWidth - 80, fontSize: 13) + 50
            }
        }
        
        if isLoadingInline {
            contentHeight += 40
        }
        
        contentHeight += 60
        
        return min(max(contentHeight, Self.chatWindowMinHeight), Self.chatWindowMaxHeight)
    }
    
    private func estimateTextHeight(_ text: String, width: CGFloat, fontSize: CGFloat) -> CGFloat {
        let attr = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: fontSize)])
        let rect = attr.boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return ceil(rect.height)
    }

    // MARK: - Mini Icon State
    
    private func buildMiniIconUI(size: NSSize) {
        currentState = .miniIcon
        clearContainer()
        
        let iconSize = size.width
        
        let bgLayer = CALayer()
        bgLayer.frame = CGRect(origin: .zero, size: size)
        bgLayer.backgroundColor = Self.darkBubbleBG.cgColor
        bgLayer.cornerRadius = iconSize / 2
        bgLayer.shadowColor = NSColor.black.cgColor
        bgLayer.shadowOpacity = 0.3
        bgLayer.shadowOffset = CGSize(width: 0, height: -2)
        bgLayer.shadowRadius = 4
        containerView.layer?.addSublayer(bgLayer)
        
        let avatarSize = iconSize - 8
        let avatar = makeAvatarImageView(size: avatarSize)
        avatar.frame = NSRect(
            x: (iconSize - avatarSize) / 2,
            y: (iconSize - avatarSize) / 2,
            width: avatarSize,
            height: avatarSize
        )
        containerView.addSubview(avatar)
        
        let clickArea = ClickThroughButton(frame: NSRect(origin: .zero, size: size))
        clickArea.target = self
        clickArea.action = #selector(miniIconTapped)
        clickArea.isBordered = false
        clickArea.bezelStyle = .shadowlessSquare
        containerView.addSubview(clickArea)
    }
    
    // MARK: - No Selection State
    
    private func buildNoSelectionUI(size: NSSize) {
        currentState = .noSelection
        clearContainer()
        
        let bgLayer = CALayer()
        bgLayer.frame = CGRect(origin: .zero, size: size)
        bgLayer.backgroundColor = Self.darkBubbleBG.cgColor
        bgLayer.cornerRadius = size.height / 2
        bgLayer.shadowColor = NSColor.black.cgColor
        bgLayer.shadowOpacity = 0.3
        bgLayer.shadowOffset = CGSize(width: 0, height: -2)
        bgLayer.shadowRadius = 4
        containerView.layer?.addSublayer(bgLayer)
        
        let label = makeLabel("select text first", size: 12, weight: .medium, color: Self.secondaryText)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: (size.height - 14) / 2, width: size.width, height: 14)
        containerView.addSubview(label)
    }

    // MARK: - Options Menu State (Figma: node 123-522)

    private func buildOptionsMenuUI(size: NSSize) {
        currentState = .optionsMenu
        clearContainer()
        
        let width = size.width
        let height = size.height
        
        // Card background - #252526, corner radius 15
        let cardLayer = CALayer()
        cardLayer.frame = CGRect(origin: .zero, size: size)
        cardLayer.backgroundColor = Self.cardBG.cgColor
        cardLayer.cornerRadius = Self.cardCornerRadius
        containerView.layer?.addSublayer(cardLayer)
        
        // Header: y=9 from top (in Figma coords, so height - 9 - elementHeight in AppKit)
        let headerY = height - 9 - 16
        
        // Product logo: 16x16 at x:9
        let avatar = makeAvatarImageView(size: 16)
        avatar.frame = NSRect(x: 9, y: headerY, width: 16, height: 16)
        containerView.addSubview(avatar)
        
        // Title "Tone Studio": x:31, font-size:12, medium weight, 80% opacity
        let titleLabel = makeLabel("Tone Studio", size: 12, weight: .medium, color: Self.titleText)
        titleLabel.frame = NSRect(x: 31, y: headerY, width: 200, height: 16)
        containerView.addSubview(titleLabel)
        
        // Close button (X): 16x16 at x:305 (width - 16 - 14 = 305 for 335 width)
        let closeBtn = makeCloseButton()
        closeBtn.frame = NSRect(x: width - 16 - 14, y: headerY, width: 16, height: 16)
        containerView.addSubview(closeBtn)
        
        // Dark inner panel: inset 33px from top, 7px from sides, 85px from bottom
        // In AppKit: y = 85, height = totalHeight - 33 - 85 = 220 - 33 - 85 = 102
        let innerPanelY: CGFloat = 85
        let innerPanelH: CGFloat = height - 33 - 85
        let innerPanel = NSView(frame: NSRect(x: 7, y: innerPanelY, width: width - 14, height: innerPanelH))
        innerPanel.wantsLayer = true
        innerPanel.layer?.backgroundColor = Self.innerPanelBG.cgColor
        innerPanel.layer?.cornerRadius = Self.innerCornerRadius
        containerView.addSubview(innerPanel)
        
        // Inside the inner panel:
        // Selected text row at y:9 inside panel (from top of panel)
        let selectedRowY = innerPanelH - 9 - 16  // 16 is row height approx
        
        // Document icon
        let docIcon = NSImageView(frame: NSRect(x: 10, y: selectedRowY - 4, width: 16, height: 16))
        let docConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        docIcon.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)?.withSymbolConfiguration(docConfig)
        docIcon.contentTintColor = Self.primaryText
        innerPanel.addSubview(docIcon)
        
        // Selected text label
        let truncatedText = selectedText.count > 30 ? String(selectedText.prefix(30)) + "..." : selectedText
        let selectedLabel = makeLabel("Selected text: \(truncatedText)", size: 12, weight: .regular, color: Self.primaryText)
        selectedLabel.frame = NSRect(x: 30, y: selectedRowY - 4, width: innerPanel.frame.width - 40, height: 16)
        innerPanel.addSubview(selectedLabel)
        
        // "Ask anything about selected text" at y:46 inside (from top)
        let placeholderY = innerPanelH - 46 - 14
        let inputPlaceholder = makeLabel("Ask anything about selected text", size: 12, weight: .regular, color: Self.primaryText)
        inputPlaceholder.frame = NSRect(x: 10, y: placeholderY, width: innerPanel.frame.width - 20, height: 14)
        innerPanel.addSubview(inputPlaceholder)
        
        // Click area for the inner panel to transition to chat
        let inputClickArea = ClickThroughButton(frame: innerPanel.bounds)
        inputClickArea.target = self
        inputClickArea.action = #selector(inputPlaceholderTapped)
        inputClickArea.isBordered = false
        inputClickArea.bezelStyle = .shadowlessSquare
        innerPanel.addSubview(inputClickArea)
        
        // Action buttons at bottom
        // "Rephrase with Jio Voice and Tone" at y:150 from top -> AppKit y = height - 150 - buttonH
        let buttonH: CGFloat = 35  // padding 9 top/bottom + ~17 text
        let buttonWidth: CGFloat = 321
        let buttonX: CGFloat = 7
        
        // Rephrase button: y=150 from top in Figma
        let rephraseY = height - 150 - buttonH
        let rephraseBtn = makeOptionButton(
            title: "Rephrase with Jio Voice and Tone",
            frame: NSRect(x: buttonX, y: rephraseY, width: buttonWidth, height: buttonH),
            action: #selector(rephraseOptionTapped)
        )
        containerView.addSubview(rephraseBtn)
        
        // Validate button: y=185 from top in Figma
        let validateY = height - 185 - buttonH
        let validateBtn = makeOptionButton(
            title: "Validate current compliance",
            frame: NSRect(x: buttonX, y: validateY, width: buttonWidth, height: buttonH),
            action: #selector(validateOptionTapped)
        )
        containerView.addSubview(validateBtn)
    }
    
    private func makeOptionButton(title: String, frame: NSRect, action: Selector) -> NSView {
        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = Self.buttonBG.cgColor
        container.layer?.cornerRadius = Self.innerCornerRadius
        
        let label = makeLabel(title, size: 12, weight: .regular, color: Self.primaryText)
        label.frame = NSRect(x: 12, y: (frame.height - 14) / 2, width: frame.width - 24, height: 14)
        container.addSubview(label)
        
        let clickArea = ClickThroughButton(frame: NSRect(origin: .zero, size: frame.size))
        clickArea.target = self
        clickArea.action = action
        clickArea.isBordered = false
        clickArea.bezelStyle = .shadowlessSquare
        container.addSubview(clickArea)
        
        return container
    }
    
    private func makeCloseButton() -> NSButton {
        let btn = NSButton(frame: .zero)
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        btn.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")?
            .withSymbolConfiguration(config)
        btn.isBordered = false
        btn.bezelStyle = .shadowlessSquare
        btn.target = self
        btn.action = #selector(cancelTapped)
        btn.contentTintColor = Self.primaryText
        btn.imageScaling = .scaleProportionallyDown
        return btn
    }

    // MARK: - Chat Window State

    private func buildChatWindowUI(size: NSSize) {
        currentState = isLoadingInline ? .chatLoading : .chatWindow
        clearContainer()
        
        let width = size.width
        let height = size.height
        
        // Card background - #252526, corner radius 15
        let cardLayer = CALayer()
        cardLayer.frame = CGRect(origin: .zero, size: size)
        cardLayer.backgroundColor = Self.cardBG.cgColor
        cardLayer.cornerRadius = Self.cardCornerRadius
        containerView.layer?.addSublayer(cardLayer)
        
        // Header: same as options menu - y=9 from top
        let headerY = height - 9 - 16
        
        // Product logo: 16x16 at x:9
        let avatar = makeAvatarImageView(size: 16)
        avatar.frame = NSRect(x: 9, y: headerY, width: 16, height: 16)
        containerView.addSubview(avatar)
        
        // Title "Tone Studio": x:31, font-size:12, medium weight, 80% opacity
        let titleLabel = makeLabel("Tone Studio", size: 12, weight: .medium, color: Self.titleText)
        titleLabel.frame = NSRect(x: 31, y: headerY, width: 200, height: 16)
        containerView.addSubview(titleLabel)
        
        // Close button (X): 16x16 at top-right
        let closeBtn = makeCloseButton()
        closeBtn.frame = NSRect(x: width - 16 - 14, y: headerY, width: 16, height: 16)
        containerView.addSubview(closeBtn)
        
        // Input area at bottom: inset 7px from sides, height ~44px
        // In Figma: inset [384px from top, 7px sides, 7px bottom] for 428px height
        // So input panel y = 7, height = 428 - 384 - 7 = 37
        let inputPanelH: CGFloat = 44
        let inputPanelY: CGFloat = 7
        
        let inputBG = NSView(frame: NSRect(x: 7, y: inputPanelY, width: width - 14, height: inputPanelH))
        inputBG.wantsLayer = true
        inputBG.layer?.backgroundColor = Self.innerPanelBG.cgColor
        inputBG.layer?.cornerRadius = Self.innerCornerRadius
        containerView.addSubview(inputBG)
        
        let textField = NSTextField(frame: NSRect(x: 10, y: (inputPanelH - 16) / 2, width: inputBG.frame.width - 20, height: 16))
        textField.placeholderString = "Ask anything about selected text"
        textField.placeholderAttributedString = NSAttributedString(
            string: "Ask anything about selected text",
            attributes: [
                .foregroundColor: Self.secondaryText,
                .font: NSFont.systemFont(ofSize: 12)
            ]
        )
        textField.isBordered = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.textColor = Self.primaryText
        textField.font = .systemFont(ofSize: 12)
        textField.focusRingType = .none
        textField.delegate = self
        textField.isEnabled = !isLoadingInline
        inputBG.addSubview(textField)
        inputField = textField
        
        // Content area between header and input
        let contentTopY: CGFloat = inputPanelY + inputPanelH + 7  // 7px gap
        let contentBottomY: CGFloat = height - 33  // 33px from top for header area
        let contentH = contentBottomY - contentTopY
        
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: contentTopY, width: width, height: contentH))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: contentH))
        contentView.wantsLayer = true
        
        buildChatContentInView(contentView, width: width, availableHeight: contentH)
        
        scrollView.documentView = contentView
        containerView.addSubview(scrollView)
        chatScrollView = scrollView
        chatContentView = contentView
        
        DispatchQueue.main.async { [weak self] in
            self?.scrollToBottom()
        }
    }
    
    private func buildChatContentInView(_ contentView: NSView, width: CGFloat, availableHeight: CGFloat) {
        let padding: CGFloat = 15
        var yOffset: CGFloat = 10
        var totalHeight: CGFloat = 10
        
        // Selected text at y:53 from top in Figma (relative to chat window)
        if !selectedText.isEmpty {
            let textHeight = estimateTextHeight(selectedText, width: width - padding * 2, fontSize: 12)
            let messageH = max(textHeight + 8, 20)
            
            let messageLabel = NSTextField(wrappingLabelWithString: selectedText)
            messageLabel.font = .systemFont(ofSize: 12)
            messageLabel.textColor = Self.primaryText
            messageLabel.isBezeled = false
            messageLabel.drawsBackground = false
            messageLabel.isEditable = false
            messageLabel.isSelectable = true
            messageLabel.frame = NSRect(x: padding, y: yOffset, width: width - padding * 2, height: textHeight)
            contentView.addSubview(messageLabel)
            
            yOffset += messageH + 12
            totalHeight += messageH + 12
        }
        
        // Action pill - RIGHT ALIGNED as per Figma
        if !lastAction.isEmpty {
            let pillWidth = estimatePillWidth(lastAction)
            let pillH: CGFloat = 30
            let pillX = width - padding - pillWidth  // Right-aligned
            
            let pillBG = NSView(frame: NSRect(x: pillX, y: yOffset, width: pillWidth, height: pillH))
            pillBG.wantsLayer = true
            pillBG.layer?.backgroundColor = Self.actionPillBG.cgColor
            pillBG.layer?.cornerRadius = Self.pillCornerRadius
            contentView.addSubview(pillBG)
            
            let pillLabel = makeLabel(lastAction, size: 12, weight: .regular, color: Self.primaryText)
            pillLabel.frame = NSRect(x: 12, y: (pillH - 14) / 2, width: pillWidth - 24, height: 14)
            pillBG.addSubview(pillLabel)
            
            yOffset += pillH + 16
            totalHeight += pillH + 16
        }
        
        // Conversation messages
        for message in conversationMessages {
            if message.role == .assistant {
                let textHeight = estimateTextHeight(message.content, width: width - padding * 2, fontSize: 12)
                let messageH = textHeight + 50
                
                // AI response text with line-height 1.2
                let responseLabel = NSTextField(wrappingLabelWithString: message.content)
                responseLabel.font = .systemFont(ofSize: 12)
                responseLabel.textColor = Self.primaryText
                responseLabel.isBezeled = false
                responseLabel.drawsBackground = false
                responseLabel.isEditable = false
                responseLabel.isSelectable = true
                responseLabel.frame = NSRect(x: padding, y: yOffset, width: width - padding * 2, height: textHeight)
                contentView.addSubview(responseLabel)
                
                yOffset += textHeight + 8
                
                // Action icons row - compact spacing
                let actionsY = yOffset
                var btnX: CGFloat = padding
                let btnSize: CGFloat = 18
                let btnSpacing: CGFloat = 6
                
                let copyBtn = makeSmallIconButton(symbolName: "doc.on.doc", action: #selector(copyTapped))
                copyBtn.frame = NSRect(x: btnX, y: actionsY, width: btnSize, height: btnSize)
                contentView.addSubview(copyBtn)
                btnX += btnSize + btnSpacing
                
                let refreshBtn = makeSmallIconButton(symbolName: "arrow.clockwise", action: #selector(regenerateTapped))
                refreshBtn.frame = NSRect(x: btnX, y: actionsY, width: btnSize, height: btnSize)
                contentView.addSubview(refreshBtn)
                btnX += btnSize + btnSpacing
                
                let likeBtn = makeSmallIconButton(symbolName: "hand.thumbsup", action: #selector(likeTapped))
                likeBtn.frame = NSRect(x: btnX, y: actionsY, width: btnSize, height: btnSize)
                contentView.addSubview(likeBtn)
                btnX += btnSize + btnSpacing
                
                let dislikeBtn = makeSmallIconButton(symbolName: "hand.thumbsdown", action: #selector(dislikeTapped))
                dislikeBtn.frame = NSRect(x: btnX, y: actionsY, width: btnSize, height: btnSize)
                contentView.addSubview(dislikeBtn)
                
                yOffset += btnSize + 16
                totalHeight += messageH
                
            } else if message.role == .user && message.content != selectedText {
                let textHeight = estimateTextHeight(message.content, width: width - padding * 2, fontSize: 12)
                let messageH = max(textHeight + 8, 20)
                
                let userLabel = NSTextField(wrappingLabelWithString: message.content)
                userLabel.font = .systemFont(ofSize: 12)
                userLabel.textColor = Self.primaryText
                userLabel.isBezeled = false
                userLabel.drawsBackground = false
                userLabel.isEditable = false
                userLabel.isSelectable = true
                userLabel.frame = NSRect(x: padding, y: yOffset, width: width - padding * 2, height: textHeight)
                contentView.addSubview(userLabel)
                
                yOffset += messageH + 12
                totalHeight += messageH + 12
            }
        }
        
        // Loading indicator
        if isLoadingInline {
            let spinnerSize: CGFloat = 16
            let spinner = NSProgressIndicator(frame: NSRect(x: padding, y: yOffset, width: spinnerSize, height: spinnerSize))
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.isIndeterminate = true
            spinner.appearance = NSAppearance(named: .vibrantDark)
            spinner.startAnimation(nil)
            contentView.addSubview(spinner)
            inlineSpinner = spinner
            
            let loadingLabel = makeLabel("Generating...", size: 12, weight: .regular, color: Self.secondaryText)
            loadingLabel.frame = NSRect(x: padding + spinnerSize + 8, y: yOffset, width: 100, height: 16)
            contentView.addSubview(loadingLabel)
            
            yOffset += spinnerSize + 16
            totalHeight += spinnerSize + 16
        }
        
        totalHeight += 10
        contentView.frame = NSRect(x: 0, y: 0, width: width, height: max(totalHeight, availableHeight))
    }
    
    private func rebuildChatContent() {
        guard let scrollView = chatScrollView, let contentView = chatContentView else { return }
        
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let width = scrollView.frame.width
        let availableHeight = scrollView.frame.height
        buildChatContentInView(contentView, width: width, availableHeight: availableHeight)
        
        scrollToBottom()
    }
    
    private func scrollToBottom() {
        guard let scrollView = chatScrollView, let contentView = chatContentView else { return }
        let newScrollPoint = NSPoint(x: 0, y: max(0, contentView.frame.height - scrollView.contentSize.height))
        scrollView.contentView.scroll(to: newScrollPoint)
    }
    
    private func estimatePillWidth(_ text: String) -> CGFloat {
        let attr = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium)])
        let rect = attr.boundingRect(with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: 20), options: [.usesLineFragmentOrigin])
        return ceil(rect.width) + 28
    }

    // MARK: - Error State

    private func buildErrorUI(message: String) {
        currentState = .error(message)
        clearContainer()
        let width = Self.errorWidth
        let height: CGFloat = 100

        let cardLayer = CALayer()
        cardLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
        cardLayer.backgroundColor = Self.cardBG.cgColor
        cardLayer.cornerRadius = 14
        cardLayer.borderColor = NSColor.systemRed.withAlphaComponent(0.4).cgColor
        cardLayer.borderWidth = 1
        containerView.layer?.addSublayer(cardLayer)

        let padding: CGFloat = 14
        let errorIcon = makeLabel("Error", size: 14, weight: .semibold, color: NSColor.systemRed)
        errorIcon.frame = NSRect(x: padding, y: height - 36, width: 60, height: 18)
        containerView.addSubview(errorIcon)

        let msgLabel = makeLabel(message, size: 12, weight: .regular, color: NSColor(white: 0.75, alpha: 1))
        msgLabel.frame = NSRect(x: padding, y: height - 60, width: width - padding * 2, height: 36)
        msgLabel.maximumNumberOfLines = 2
        containerView.addSubview(msgLabel)

        let retryBtn  = makeTextButton("Retry",  action: #selector(retryTapped))
        let cancelBtn = makeTextButton("Dismiss", action: #selector(cancelTapped))
        retryBtn.frame  = NSRect(x: padding, y: 10, width: 70, height: 26)
        cancelBtn.frame = NSRect(x: padding + 76, y: 10, width: 70, height: 26)
        containerView.addSubview(retryBtn)
        containerView.addSubview(cancelBtn)
    }

    // MARK: - Helpers

    private func clearContainer() {
        containerView.subviews.forEach { $0.removeFromSuperview() }
        containerView.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        inputField = nil
        chatScrollView = nil
        chatContentView = nil
        inlineSpinner = nil
    }

    private func resizeAndReanchor(to size: NSSize) {
        var frame = panel.frame
        let topLeft = CGPoint(x: frame.minX, y: frame.maxY)
        frame.size = size
        frame.origin = CGPoint(x: topLeft.x, y: topLeft.y - size.height)
        
        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) }) ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            if frame.minX < visibleFrame.minX + Self.screenEdgePadding {
                frame.origin.x = visibleFrame.minX + Self.screenEdgePadding
            }
            if frame.maxX > visibleFrame.maxX - Self.screenEdgePadding {
                frame.origin.x = visibleFrame.maxX - size.width - Self.screenEdgePadding
            }
            if frame.minY < visibleFrame.minY + Self.screenEdgePadding {
                frame.origin.y = visibleFrame.minY + Self.screenEdgePadding
            }
            if frame.maxY > visibleFrame.maxY - Self.screenEdgePadding {
                frame.origin.y = visibleFrame.maxY - size.height - Self.screenEdgePadding
            }
        }
        
        panel.setFrame(frame, display: true)
    }

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

    private func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.isBezeled = false
        field.drawsBackground = false
        field.isEditable = false
        field.isSelectable = false
        field.lineBreakMode = .byTruncatingTail
        return field
    }

    private func makeIconButton(symbolName: String, action: Selector) -> NSButton {
        let btn = NSButton(frame: .zero)
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        btn.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        btn.isBordered = false
        btn.bezelStyle = .shadowlessSquare
        btn.target = self
        btn.action = action
        btn.contentTintColor = NSColor(white: 0.7, alpha: 1)
        btn.imageScaling = .scaleProportionallyDown
        return btn
    }
    
    private func makeSmallIconButton(symbolName: String, action: Selector) -> NSButton {
        let btn = NSButton(frame: .zero)
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        btn.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        btn.isBordered = false
        btn.bezelStyle = .shadowlessSquare
        btn.target = self
        btn.action = action
        btn.contentTintColor = NSColor(white: 0.5, alpha: 1)
        btn.imageScaling = .scaleProportionallyDown
        return btn
    }

    private func makeTextButton(_ title: String, action: Selector) -> NSButton {
        let btn = NSButton(title: title, target: self, action: action)
        btn.bezelStyle = .roundRect
        btn.controlSize = .small
        btn.font = .systemFont(ofSize: 12)
        btn.appearance = NSAppearance(named: .vibrantDark)
        return btn
    }

    // MARK: - Event monitors

    private func addEventMonitors() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.panel.isVisible else { return }
            switch self.currentState {
            case .chatWindow, .chatLoading, .error:
                break
            case .miniIcon, .noSelection:
                let mouseLoc = NSEvent.mouseLocation
                if !self.panel.frame.contains(mouseLoc) {
                    self.hide()
                }
            case .optionsMenu:
                let mouseLoc = NSEvent.mouseLocation
                if !self.panel.frame.contains(mouseLoc) {
                    self.hide()
                    self.onCancel?()
                }
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.hide()
                self?.onCancel?()
                return nil
            }
            return event
        }
    }

    private func removeEventMonitors() {
        if let m = globalClickMonitor { NSEvent.removeMonitor(m); globalClickMonitor = nil }
        if let m = localKeyMonitor    { NSEvent.removeMonitor(m); localKeyMonitor = nil }
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            submitInput()
            return true
        }
        return false
    }
    
    private func submitInput() {
        guard let field = inputField else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        field.stringValue = ""
        field.isEnabled = false
        
        onCustomPrompt?(text)
    }
    
    func enableInput() {
        inputField?.isEnabled = true
    }

    // MARK: - Button actions

    @objc private func miniIconTapped() {
        cancelAutoHideTimer()
        updateUI(.optionsMenu)
    }
    
    @objc private func rephraseOptionTapped() {
        lastAction = "Rephrase with Jio Voice and Tone"
        onRephrase?()
    }
    
    @objc private func validateOptionTapped() {
        let alert = NSAlert()
        alert.messageText = "Coming Soon"
        alert.informativeText = "Compliance validation will be available in a future update."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func inputPlaceholderTapped() {
        updateUI(.chatWindow)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.inputField?.becomeFirstResponder()
        }
    }
    
    @objc private func copyTapped() {
        onCopy?(lastResponse)
    }
    
    @objc private func cancelTapped() {
        hide()
        onCancel?()
    }
    
    @objc private func retryTapped() {
        onRetry?()
    }
    
    @objc private func regenerateTapped() {
        onRegenerate?()
    }
    
    @objc private func likeTapped() {
        onFeedback?("thumbs_up", lastResponse)
    }
    
    @objc private func dislikeTapped() {
        onFeedback?("thumbs_down", lastResponse)
    }
}

// MARK: - Invisible click-through button overlay

private final class ClickThroughButton: NSButton {
    override func draw(_ dirtyRect: NSRect) { /* transparent */ }
}
