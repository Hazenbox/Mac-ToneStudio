import Cocoa
import OSLog

// MARK: - Tooltip States

enum TooltipState: Equatable {
    case miniIcon
    case noSelection
    case optionsMenu
    case chatWindow
    case chatLoading
    case floatingFAB
    case compliancePanel
    case error(String)
    
    static func == (lhs: TooltipState, rhs: TooltipState) -> Bool {
        switch (lhs, rhs) {
        case (.miniIcon, .miniIcon),
             (.noSelection, .noSelection),
             (.optionsMenu, .optionsMenu),
             (.chatWindow, .chatWindow),
             (.chatLoading, .chatLoading),
             (.floatingFAB, .floatingFAB),
             (.compliancePanel, .compliancePanel):
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
    var trustScore: TrustScore?
    var validationResult: ValidationResult?
    var evidence: GenerationEvidence?
    
    init(role: Role, content: String, trustScore: TrustScore? = nil, 
         validationResult: ValidationResult? = nil, evidence: GenerationEvidence? = nil) {
        self.role = role
        self.content = content
        self.trustScore = trustScore
        self.validationResult = validationResult
        self.evidence = evidence
    }
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

// MARK: - KeyablePanel (allows text input in floating panel)

final class KeyablePanel: NSPanel {
    var allowsKeyStatus: Bool = false
    
    override var canBecomeKey: Bool {
        return allowsKeyStatus
    }
    
    override var becomesKeyOnlyIfNeeded: Bool {
        get { return true }
        set { }
    }
}

// MARK: - Typing Indicator (animated bouncing dots)

final class TypingIndicatorView: NSView {
    private var dotLayers: [CALayer] = []
    private let dotCount = 3
    private let dotSize: CGFloat = 6
    private let dotSpacing: CGFloat = 4
    private let dotColor: NSColor
    
    init(color: NSColor = .white) {
        self.dotColor = color
        super.init(frame: .zero)
        setupDots()
    }
    
    required init?(coder: NSCoder) {
        self.dotColor = .white
        super.init(coder: coder)
        setupDots()
    }
    
    private func setupDots() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        for i in 0..<dotCount {
            let dot = CALayer()
            dot.backgroundColor = dotColor.cgColor
            dot.cornerRadius = dotSize / 2
            dot.frame = CGRect(
                x: CGFloat(i) * (dotSize + dotSpacing),
                y: 0,
                width: dotSize,
                height: dotSize
            )
            layer?.addSublayer(dot)
            dotLayers.append(dot)
        }
        
        let totalWidth = CGFloat(dotCount) * dotSize + CGFloat(dotCount - 1) * dotSpacing
        frame = NSRect(x: 0, y: 0, width: totalWidth, height: dotSize)
    }
    
    func startAnimating() {
        for (index, dot) in dotLayers.enumerated() {
            let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
            animation.values = [0, -4, 0]
            animation.keyTimes = [0, 0.4, 1]
            animation.duration = 0.6
            animation.repeatCount = .infinity
            animation.beginTime = CACurrentMediaTime() + Double(index) * 0.15
            animation.timingFunctions = [
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut)
            ]
            dot.add(animation, forKey: "bounce")
            
            let opacityAnimation = CAKeyframeAnimation(keyPath: "opacity")
            opacityAnimation.values = [0.4, 1.0, 0.4]
            opacityAnimation.keyTimes = [0, 0.4, 1]
            opacityAnimation.duration = 0.6
            opacityAnimation.repeatCount = .infinity
            opacityAnimation.beginTime = CACurrentMediaTime() + Double(index) * 0.15
            dot.add(opacityAnimation, forKey: "pulse")
        }
    }
    
    func stopAnimating() {
        for dot in dotLayers {
            dot.removeAllAnimations()
        }
    }
}

// MARK: - HoverButton (button with hover background)

final class HoverButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private var hoverBackgroundLayer: CALayer?
    private let hoverColor: NSColor
    private let cornerRadius: CGFloat
    
    init(hoverColor: NSColor = NSColor.white.withAlphaComponent(0.1), cornerRadius: CGFloat = 4) {
        self.hoverColor = hoverColor
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        setupHoverLayer()
    }
    
    required init?(coder: NSCoder) {
        self.hoverColor = NSColor.white.withAlphaComponent(0.1)
        self.cornerRadius = 4
        super.init(coder: coder)
        setupHoverLayer()
    }
    
    private func setupHoverLayer() {
        wantsLayer = true
        
        let bgLayer = CALayer()
        bgLayer.backgroundColor = NSColor.clear.cgColor
        bgLayer.cornerRadius = cornerRadius
        layer?.insertSublayer(bgLayer, at: 0)
        hoverBackgroundLayer = bgLayer
    }
    
    override func layout() {
        super.layout()
        hoverBackgroundLayer?.frame = bounds
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            hoverBackgroundLayer?.backgroundColor = hoverColor.cgColor
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            hoverBackgroundLayer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}

// MARK: - Draggable FAB View

final class DraggableFABView: NSView {
    var onDragStart: (() -> Void)?
    var onDrag: ((NSPoint) -> Void)?
    var onDragEnd: (() -> Void)?
    var onClick: (() -> Void)?
    
    private var isDragging = false
    private let dragThreshold: CGFloat = 5
    private var mouseDownLocation: NSPoint?
    private var initialWindowOrigin: NSPoint?
    
    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = NSEvent.mouseLocation
        initialWindowOrigin = window?.frame.origin
        isDragging = false
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let startLoc = mouseDownLocation, let initialOrigin = initialWindowOrigin else { return }
        let currentLoc = NSEvent.mouseLocation
        let distance = hypot(currentLoc.x - startLoc.x, currentLoc.y - startLoc.y)
        
        if distance > dragThreshold {
            if !isDragging {
                isDragging = true
                onDragStart?()
            }
            // Calculate new window position based on drag delta
            let deltaX = currentLoc.x - startLoc.x
            let deltaY = currentLoc.y - startLoc.y
            let newOrigin = NSPoint(x: initialOrigin.x + deltaX, y: initialOrigin.y + deltaY)
            onDrag?(newOrigin)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if isDragging {
            onDragEnd?()
        } else {
            onClick?()
        }
        isDragging = false
        mouseDownLocation = nil
        initialWindowOrigin = nil
    }
}

// MARK: - Hoverable Option View

final class HoverableOptionView: NSView {
    var isEnabled: Bool = true
    var normalColor: NSColor = NSColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1)
    var hoverColor: NSColor = NSColor.white.withAlphaComponent(0.08)
    
    private var trackingArea: NSTrackingArea?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.allowsImplicitAnimation = true
            layer?.backgroundColor = hoverColor.cgColor
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.allowsImplicitAnimation = true
            layer?.backgroundColor = normalColor.cgColor
        }
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
    var onClearSelectedText: (() -> Void)?

    // MARK: - Panel
    private let panel: KeyablePanel
    private let containerView: NSView
    private var currentState: TooltipState = .optionsMenu

    // MARK: - Conversation State
    private var selectedText: String = ""
    private var lastAction: String = ""
    private var conversationMessages: [ChatMessage] = []
    private var lastResponse: String = ""
    private var isLoadingInline: Bool = false
    private var currentValidationResult: ValidationResult?
    private var currentTrustScore: TrustScore?

    // MARK: - UI References
    private var inputField: NSTextField?
    private var quickActionsInputField: NSTextField?
    private var chatScrollView: NSScrollView?
    private var chatContentView: NSView?
    private var inlineSpinner: NSProgressIndicator?
    private var fabCloseButton: NSButton?
    private var fabTrackingArea: NSTrackingArea?
    private var isFabHovered: Bool = false
    private var lastChatWindowFrame: NSRect?
    private var draggableFABView: DraggableFABView?
    private var validationBadgeView: NSView?

    // MARK: - Event monitors
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?
    
    // MARK: - Auto-hide timer
    private var autoHideTimer: Timer?
    private var lastShowTime: Date = .distantPast
    private static let minVisibleDuration: TimeInterval = 1.0

    // MARK: - Sizing (Figma specs)
    private static let miniIconSize = AppConstants.miniIconSize
    private static let noSelectionSize = NSSize(width: 160, height: 36)
    private static let tailHeight: CGFloat = BubbleContainerView.tailHeight
    private static let bubbleCorner: CGFloat = BubbleContainerView.cornerRadius
    
    private static let optionsMenuSize = NSSize(width: 335, height: 330)
    private static let chatWindowWidth: CGFloat = 420
    private static let chatWindowMinHeight: CGFloat = 480
    private static let chatWindowMaxHeight: CGFloat = 600
    private static let compliancePanelSize = NSSize(width: 360, height: 400)
    private static let errorWidth: CGFloat = 300
    private static let cardCornerRadius: CGFloat = 16
    private static let innerCornerRadius: CGFloat = 11
    private static let pillCornerRadius: CGFloat = 21
    private static let fabSize: CGFloat = 48
    private static let userBubbleMaxWidthRatio: CGFloat = 0.8
    private static let selectedTextContainerH: CGFloat = 42
    
    // User bubble styling constants
    private static let userBubblePaddingH: CGFloat = 16
    private static let userBubblePaddingV: CGFloat = 10
    private static let userBubbleMinWidth: CGFloat = 72
    private static let userBubbleMinTextWidth: CGFloat = 48
    
    // Typography constants
    private static let messageFontSize: CGFloat = 14
    private static let titleFontSize: CGFloat = 15
    private static let inputFontSize: CGFloat = 14
    
    // Spacing constants
    private static let contentPadding: CGFloat = 12
    private static let messageSpacing: CGFloat = 16

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
        panel = KeyablePanel(
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
    
    func getConversationHistory(limit: Int = 10) -> [[String: String]] {
        conversationMessages
            .filter { $0.role == .user || $0.role == .assistant }
            .suffix(limit)
            .map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.content] }
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
    
    func showCentered(withText text: String? = nil) {
        cancelAutoHideTimer()
        clearConversation()
        
        if let text = text, !text.isEmpty {
            setSelectedText(text)
        } else {
            setSelectedText("")
        }
        
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let width = Self.chatWindowWidth
        let height: CGFloat = Self.chatWindowMaxHeight
        let x = visibleFrame.midX - width / 2
        let y = visibleFrame.midY - height / 2 + 40
        
        let frame = NSRect(x: x, y: y, width: width, height: height)
        
        clearContainer()
        buildChatWindowUI(size: frame.size)
        currentState = .chatWindow
        panel.isMovableByWindowBackground = true
        
        panel.setFrame(frame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        lastShowTime = Date()
        addEventMonitors()
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            panel.animator().alphaValue = 1
        }
        
        focusInputField()
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
            lastShowTime = Date()
            // Apple-style spring animation for show
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
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
        lastShowTime = Date()
        // Apple-style spring animation for show
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
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
        case .floatingFAB:
            buildFloatingFABUI(size: size)
        case .compliancePanel:
            buildCompliancePanelUI(size: size)
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
        lastShowTime = Date()
        // Apple-style spring animation for show
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
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

    func hide(force: Bool = false) {
        // Prevent hiding too quickly after showing (unless forced)
        if !force && Date().timeIntervalSince(lastShowTime) < Self.minVisibleDuration {
            return
        }
        
        cancelAutoHideTimer()
        removeEventMonitors()
        clearConversation()
        // Apple-style ease-out animation for hide
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.6, 1.0)
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
        case .chatWindow, .chatLoading, .error, .optionsMenu, .compliancePanel:
            return true
        case .miniIcon, .noSelection, .floatingFAB:
            return false
        }
    }
    
    var isMiniIcon: Bool {
        if case .miniIcon = currentState { return true }
        return false
    }
    
    var isFAB: Bool {
        if case .floatingFAB = currentState { return true }
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
            panel.isMovableByWindowBackground = true
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
            
        case .floatingFAB:
            panel.isMovableByWindowBackground = false
            let size = NSSize(width: Self.fabSize, height: Self.fabSize)
            buildFloatingFABUI(size: size)
            // Animate the shrinking transition
            animateResizeAndReanchor(to: size)
            
        case .compliancePanel:
            panel.isMovableByWindowBackground = true
            buildCompliancePanelUI(size: Self.compliancePanelSize)
            resizeAndReanchor(to: Self.compliancePanelSize)
        }
    }
    
    private func animateResizeAndReanchor(to size: NSSize) {
        var frame = panel.frame
        // Animate to center of current position for FAB
        let currentCenter = CGPoint(x: frame.midX, y: frame.midY)
        frame.size = size
        frame.origin = CGPoint(x: currentCenter.x - size.width / 2, y: currentCenter.y - size.height / 2)
        
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
        
        // iOS-style spring animation (quick and snappy)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(frame, display: true)
        }
    }
    
    private func calculateChatWindowHeight() -> CGFloat {
        var contentHeight: CGFloat = 140  // Base height for header + input area
        
        if !selectedText.isEmpty {
            contentHeight += estimateTextHeight(selectedText, width: Self.chatWindowWidth - Self.contentPadding * 4, fontSize: Self.messageFontSize) + 24
        }
        
        if !lastAction.isEmpty {
            contentHeight += 48
        }
        
        for message in conversationMessages {
            if message.role == .assistant {
                contentHeight += estimateTextHeight(message.content, width: Self.chatWindowWidth - Self.contentPadding * 4, fontSize: Self.messageFontSize) + 56
            } else if message.role == .user {
                contentHeight += 48  // Approximate user bubble height
            }
        }
        
        if isLoadingInline {
            contentHeight += 44
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
        panel.allowsKeyStatus = false
        clearContainer()
        
        let iconSize = size.width
        
        // Logo only - no background
        let avatar = makeAvatarImageView(size: iconSize)
        avatar.frame = NSRect(x: 0, y: 0, width: iconSize, height: iconSize)
        containerView.addSubview(avatar)
        
        let clickArea = ClickThroughButton(frame: NSRect(origin: .zero, size: size))
        clickArea.target = self
        clickArea.action = #selector(miniIconTapped)
        clickArea.isBordered = false
        clickArea.bezelStyle = .shadowlessSquare
        containerView.addSubview(clickArea)
    }
    
    // MARK: - Floating FAB State
    
    private func buildFloatingFABUI(size: NSSize) {
        currentState = .floatingFAB
        panel.allowsKeyStatus = false
        clearContainer()
        
        let iconSize = size.width
        
        // Logo only - no background
        let avatar = makeAvatarImageView(size: iconSize)
        avatar.frame = NSRect(x: 0, y: 0, width: iconSize, height: iconSize)
        containerView.addSubview(avatar)
        
        // Close button (hidden by default, shown on hover)
        let closeBtn = NSButton(frame: NSRect(origin: .zero, size: size))
        closeBtn.isBordered = false
        closeBtn.bezelStyle = .shadowlessSquare
        closeBtn.wantsLayer = true
        closeBtn.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        closeBtn.layer?.cornerRadius = iconSize / 2
        let closeConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        closeBtn.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")?
            .withSymbolConfiguration(closeConfig)
        closeBtn.contentTintColor = .white
        closeBtn.target = self
        closeBtn.action = #selector(fabCloseTapped)
        closeBtn.alphaValue = 0  // Hidden by default
        containerView.addSubview(closeBtn)
        fabCloseButton = closeBtn
        
        // Draggable area - allows click to restore chat OR drag to reposition
        let dragView = DraggableFABView(frame: NSRect(origin: .zero, size: size))
        dragView.onClick = { [weak self] in
            guard let self, !self.isFabHovered else { return }
            self.restoreChatFromFAB()
        }
        dragView.onDrag = { [weak self] newOrigin in
            self?.panel.setFrameOrigin(newOrigin)
        }
        containerView.addSubview(dragView)
        draggableFABView = dragView
        
        // Add tracking area for hover detection (shows close button)
        setupFABTrackingArea()
    }
    
    private func setupFABTrackingArea() {
        // Remove existing tracking area if any
        if let existingArea = fabTrackingArea {
            containerView.removeTrackingArea(existingArea)
        }
        
        let trackingArea = NSTrackingArea(
            rect: containerView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        containerView.addTrackingArea(trackingArea)
        fabTrackingArea = trackingArea
    }
    
    // MARK: - No Selection State
    
    private func buildNoSelectionUI(size: NSSize) {
        currentState = .noSelection
        panel.allowsKeyStatus = false
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
        panel.allowsKeyStatus = true  // Allow key for input field
        clearContainer()
        
        let width = size.width
        let height = size.height
        let padding: CGFloat = 7
        
        // Card background - #252526, corner radius 15
        let cardLayer = CALayer()
        cardLayer.frame = CGRect(origin: .zero, size: size)
        cardLayer.backgroundColor = Self.cardBG.cgColor
        cardLayer.cornerRadius = Self.cardCornerRadius
        containerView.layer?.addSublayer(cardLayer)
        
        // Header with consistent height and vertical centering
        let headerHeight: CGFloat = 44
        let headerY = height - headerHeight
        let logoSize: CGFloat = 28
        let titleText = "Tone Studio"
        let titleWidth: CGFloat = 90
        let logoTitleSpacing: CGFloat = 8
        
        // Product logo - left aligned, vertically centered
        let logoY = headerY + (headerHeight - logoSize) / 2
        let avatar = makeAvatarImageView(size: logoSize)
        avatar.frame = NSRect(x: padding + 2, y: logoY, width: logoSize, height: logoSize)
        containerView.addSubview(avatar)
        
        // Title "Tone Studio" - vertically centered
        let titleLabel = makeLabel(titleText, size: 14, weight: .medium, color: Self.titleText)
        titleLabel.frame = NSRect(x: padding + 2 + logoSize + logoTitleSpacing, y: headerY + (headerHeight - 18) / 2, width: titleWidth, height: 18)
        containerView.addSubview(titleLabel)
        
        // Close button (X) - right aligned, vertically centered
        let closeBtn = makeCloseButton()
        closeBtn.frame = NSRect(x: width - 16 - 14, y: headerY + (headerHeight - 16) / 2, width: 16, height: 16)
        containerView.addSubview(closeBtn)
        
        // === IMPROVED LAYOUT ===
        // Action button at bottom
        let buttonH: CGFloat = 42
        let buttonWidth: CGFloat = width - padding * 2
        
        let hasText = !selectedText.isEmpty
        
        // Rephrase button at bottom
        let rephraseY: CGFloat = padding + 4
        let rephraseBtn = makeOptionButton(
            title: "Rephrase with Jio Voice and Tone",
            frame: NSRect(x: padding, y: rephraseY, width: buttonWidth, height: buttonH),
            action: #selector(rephraseOptionTapped),
            enabled: hasText
        )
        containerView.addSubview(rephraseBtn)
        
        // Input panel above button - increased height for better spacing
        let inputPanelY = rephraseY + buttonH + 12
        let inputPanelH: CGFloat = height - inputPanelY - 33 - 8  // Leave room for header
        let inputPanel = NSView(frame: NSRect(x: padding, y: inputPanelY, width: buttonWidth, height: inputPanelH))
        inputPanel.wantsLayer = true
        inputPanel.layer?.backgroundColor = Self.innerPanelBG.cgColor
        inputPanel.layer?.cornerRadius = Self.innerCornerRadius
        containerView.addSubview(inputPanel)
        
        let textFieldH: CGFloat = 24
        var textFieldY: CGFloat
        
        if hasText {
            // Selected text container at TOP of input panel
            let selectedRowH: CGFloat = 32
            let selectedRowY = inputPanelH - 10 - selectedRowH
            let selectedRowContainer = NSView(frame: NSRect(x: 10, y: selectedRowY, width: buttonWidth - 20, height: selectedRowH))
            selectedRowContainer.wantsLayer = true
            selectedRowContainer.layer?.backgroundColor = Self.buttonBG.cgColor
            selectedRowContainer.layer?.cornerRadius = 8
            inputPanel.addSubview(selectedRowContainer)
            
            let docIcon = NSImageView(frame: NSRect(x: 8, y: (selectedRowH - 16) / 2, width: 16, height: 16))
            let docConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            docIcon.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)?.withSymbolConfiguration(docConfig)
            docIcon.contentTintColor = Self.primaryText
            selectedRowContainer.addSubview(docIcon)
            
            let truncatedText = selectedText.count > 25 ? String(selectedText.prefix(25)) + "..." : selectedText
            let selectedLabel = makeLabel("Selected text: \(truncatedText)", size: 12, weight: .regular, color: Self.primaryText)
            selectedLabel.frame = NSRect(x: 28, y: (selectedRowH - 16) / 2, width: buttonWidth - 68, height: 16)
            selectedRowContainer.addSubview(selectedLabel)
            
            let clearSelectedBtn = NSButton(frame: NSRect(
                x: buttonWidth - 20 - 8 - 16,
                y: (selectedRowH - 16) / 2,
                width: 16,
                height: 16
            ))
            let closeConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            clearSelectedBtn.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Clear selected text")?
                .withSymbolConfiguration(closeConfig)
            clearSelectedBtn.isBordered = false
            clearSelectedBtn.bezelStyle = .inline
            clearSelectedBtn.contentTintColor = Self.secondaryText
            clearSelectedBtn.target = self
            clearSelectedBtn.action = #selector(clearSelectedTextTapped)
            selectedRowContainer.addSubview(clearSelectedBtn)
            
            textFieldY = selectedRowY - 10 - textFieldH
        } else {
            textFieldY = inputPanelH - 10 - textFieldH
        }
        
        let textField = NSTextField(frame: NSRect(
            x: 10,
            y: textFieldY,
            width: buttonWidth - 20,
            height: textFieldH
        ))
        let optionsPlaceholder = hasText ? "Ask anything about selected text" : "Ask me anything..."
        textField.placeholderString = optionsPlaceholder
        textField.placeholderAttributedString = NSAttributedString(
            string: optionsPlaceholder,
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
        inputPanel.addSubview(textField)
        quickActionsInputField = textField
        
        // 3. Send button at bottom-right corner with 10px padding
        let sendBtnSize: CGFloat = 28
        let sendBtn = NSButton(frame: NSRect(
            x: buttonWidth - 10 - sendBtnSize,
            y: 10,
            width: sendBtnSize,
            height: sendBtnSize
        ))
        let sendConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        sendBtn.image = NSImage(systemSymbolName: "arrow.up.circle.fill", accessibilityDescription: "Send")?
            .withSymbolConfiguration(sendConfig)
        sendBtn.isBordered = false
        sendBtn.bezelStyle = .shadowlessSquare
        sendBtn.contentTintColor = NSColor.systemBlue
        sendBtn.target = self
        sendBtn.action = #selector(quickActionsSendTapped)
        inputPanel.addSubview(sendBtn)
        
        // Focus the input field after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.panel.allowsKeyStatus = true
            self.panel.makeFirstResponder(textField)
        }
    }
    
    private func makeOptionButton(title: String, frame: NSRect, action: Selector, enabled: Bool = true) -> HoverableOptionView {
        let container = HoverableOptionView(frame: frame)
        container.normalColor = Self.buttonBG
        container.hoverColor = enabled ? NSColor.white.withAlphaComponent(0.08) : Self.buttonBG
        container.isEnabled = enabled
        container.layer?.backgroundColor = Self.buttonBG.cgColor
        container.layer?.cornerRadius = Self.innerCornerRadius
        
        let labelColor = enabled ? Self.primaryText : Self.secondaryText
        let label = makeLabel(title, size: 13, weight: .regular, color: labelColor)
        label.frame = NSRect(x: 14, y: (frame.height - 16) / 2, width: frame.width - 100, height: 16)
        container.addSubview(label)
        
        if enabled {
            let clickArea = ClickThroughButton(frame: NSRect(origin: .zero, size: frame.size))
            clickArea.target = self
            clickArea.action = action
            clickArea.isBordered = false
            clickArea.bezelStyle = .shadowlessSquare
            container.addSubview(clickArea)
        }
        
        return container
    }
    
    private func makeCloseButton() -> NSButton {
        let btn = HoverButton(hoverColor: NSColor.gray.withAlphaComponent(0.2), cornerRadius: 10)
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
        panel.allowsKeyStatus = true
        clearContainer()
        
        let width = size.width
        let height = size.height
        
        // Card background
        let cardLayer = CALayer()
        cardLayer.frame = CGRect(origin: .zero, size: size)
        cardLayer.backgroundColor = Self.cardBG.cgColor
        cardLayer.cornerRadius = Self.cardCornerRadius
        containerView.layer?.addSublayer(cardLayer)
        
        // Header with consistent height and vertical centering
        let headerHeight: CGFloat = 44
        let headerY = height - headerHeight
        let logoSize: CGFloat = 28
        let titleText = "Tone Studio"
        let titleWidth: CGFloat = 100
        let logoTitleSpacing: CGFloat = 10
        
        // Product logo - left aligned, vertically centered
        let logoY = headerY + (headerHeight - logoSize) / 2
        let avatar = makeAvatarImageView(size: logoSize)
        avatar.frame = NSRect(x: Self.contentPadding, y: logoY, width: logoSize, height: logoSize)
        containerView.addSubview(avatar)
        
        // Title with larger font - vertically centered
        let titleLabel = makeLabel(titleText, size: Self.titleFontSize, weight: .medium, color: Self.titleText)
        titleLabel.frame = NSRect(x: Self.contentPadding + logoSize + logoTitleSpacing, y: headerY + (headerHeight - 20) / 2, width: titleWidth, height: 20)
        containerView.addSubview(titleLabel)
        
        // Close button - right aligned, vertically centered
        let closeBtn = makeCloseButton()
        closeBtn.frame = NSRect(x: width - 16 - Self.contentPadding, y: headerY + (headerHeight - 16) / 2, width: 16, height: 16)
        containerView.addSubview(closeBtn)
        
        // Input area at bottom with more padding
        let inputPanelH: CGFloat = 80
        let inputPanelY: CGFloat = Self.contentPadding
        let sendBtnSize: CGFloat = 32
        
        let inputBG = NSView(frame: NSRect(x: Self.contentPadding, y: inputPanelY, width: width - Self.contentPadding * 2, height: inputPanelH))
        inputBG.wantsLayer = true
        inputBG.layer?.backgroundColor = Self.innerPanelBG.cgColor
        inputBG.layer?.cornerRadius = Self.innerCornerRadius
        containerView.addSubview(inputBG)
        
        // Send button
        let sendBtn = NSButton(frame: NSRect(
            x: width - Self.contentPadding - 10 - sendBtnSize,
            y: inputPanelY + 10,
            width: sendBtnSize,
            height: sendBtnSize
        ))
        let sendConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        sendBtn.image = NSImage(systemSymbolName: "arrow.up.circle.fill", accessibilityDescription: "Send")?
            .withSymbolConfiguration(sendConfig)
        sendBtn.isBordered = false
        sendBtn.bezelStyle = .shadowlessSquare
        sendBtn.contentTintColor = isLoadingInline ? Self.secondaryText : NSColor.systemBlue
        sendBtn.target = self
        sendBtn.action = #selector(sendButtonTapped)
        sendBtn.isEnabled = !isLoadingInline
        containerView.addSubview(sendBtn)
        
        // Text field with larger font
        let textFieldH: CGFloat = 60
        let textField = NSTextField(frame: NSRect(
            x: Self.contentPadding + 12,
            y: inputPanelY + 10,
            width: width - Self.contentPadding * 2 - 24 - sendBtnSize - 8,
            height: textFieldH
        ))
        let chatPlaceholder = selectedText.isEmpty ? "Ask me anything..." : "Ask anything about selected text"
        textField.placeholderString = chatPlaceholder
        textField.placeholderAttributedString = NSAttributedString(
            string: chatPlaceholder,
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.5),
                .font: NSFont.systemFont(ofSize: Self.inputFontSize)
            ]
        )
        textField.isBordered = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.textColor = Self.primaryText
        textField.font = .systemFont(ofSize: Self.inputFontSize)
        textField.focusRingType = .none
        textField.delegate = self
        textField.isEnabled = !isLoadingInline
        containerView.addSubview(textField)
        inputField = textField
        
        // Content area between header and input
        let contentTopY: CGFloat = inputPanelY + inputPanelH + Self.contentPadding
        let contentBottomY: CGFloat = height - 44  // Header area
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.scrollToBottom()
            // Focus input field when chat window is shown
            if let field = self.inputField, field.isEnabled {
                self.panel.allowsKeyStatus = true
                self.panel.makeFirstResponder(field)
            }
        }
    }
    
    private func buildChatContentInView(_ contentView: NSView, width: CGFloat, availableHeight: CGFloat) {
        let padding: CGFloat = 7
        let btnSize: CGFloat = 18
        let btnSpacing: CGFloat = 6
        
        // STEP 1: Calculate total content height first (top-down visual order)
        var totalHeight: CGFloat = 8  // Top padding
        
        // Selected text container height
        let selectedTextH: CGFloat = selectedText.isEmpty ? 0 : Self.selectedTextContainerH + 12
        totalHeight += selectedTextH
        
        // Action pill height (first user action like "Rephrase with Jio Voice and Tone")
        let actionPillH: CGFloat = lastAction.isEmpty ? 0 : 36 + 12
        totalHeight += actionPillH
        
        // Calculate heights for all conversation messages
        var messageHeights: [(role: ChatMessage.Role, content: String, height: CGFloat, textHeight: CGFloat, bubbleW: CGFloat)] = []
        
        for message in conversationMessages {
            if message.role == .assistant {
                let availableWidth = width - padding * 2
                let textHeight = estimateTextHeight(message.content, width: availableWidth, fontSize: Self.messageFontSize)
                let messageH = textHeight + 8 + btnSize + Self.messageSpacing  // text + gap + actions + bottom spacing
                messageHeights.append((role: .assistant, content: message.content, height: messageH, textHeight: textHeight, bubbleW: 0))
                totalHeight += messageH
            } else if message.role == .user {
                // User messages as right-aligned pill bubbles
                let maxBubbleWidth = (width - padding * 2) * Self.userBubbleMaxWidthRatio
                let naturalWidth = estimateTextWidth(message.content, fontSize: Self.messageFontSize)
                let textWidth = max(min(naturalWidth, maxBubbleWidth - Self.userBubblePaddingH * 2), Self.userBubbleMinTextWidth)
                let textHeight = estimateTextHeight(message.content, width: textWidth, fontSize: Self.messageFontSize)
                let bubbleW = max(textWidth + Self.userBubblePaddingH * 2, Self.userBubbleMinWidth)
                let bubbleH = textHeight + Self.userBubblePaddingV * 2
                messageHeights.append((role: .user, content: message.content, height: bubbleH + Self.messageSpacing, textHeight: textHeight, bubbleW: bubbleW))
                totalHeight += bubbleH + Self.messageSpacing
            }
        }
        
        // Loading indicator height
        let loadingH: CGFloat = isLoadingInline ? 24 + 12 : 0
        totalHeight += loadingH
        
        totalHeight += 10  // Bottom padding
        
        // Ensure minimum height
        let contentHeight = max(totalHeight, availableHeight)
        contentView.frame = NSRect(x: 0, y: 0, width: width, height: contentHeight)
        
        // STEP 2: Position elements from TOP (high y) to BOTTOM (low y)
        // In AppKit, y=0 is at the bottom, so we start from contentHeight and work downward
        var yPos: CGFloat = contentHeight - 8  // Start from top with padding
        
        // Empty state welcome message
        if conversationMessages.isEmpty && selectedText.isEmpty && lastAction.isEmpty && !isLoadingInline {
            let welcomeLabel = makeLabel(
                "Ask me anything, questions, content help, or select text to get started",
                size: 13, weight: .regular, color: Self.secondaryText
            )
            welcomeLabel.alignment = .center
            welcomeLabel.maximumNumberOfLines = 2
            welcomeLabel.frame = NSRect(x: padding, y: (contentHeight - 40) / 2, width: width - padding * 2, height: 40)
            contentView.addSubview(welcomeLabel)
            return
        }
        
        // Selected text in dark container at TOP
        if !selectedText.isEmpty {
            let containerH = Self.selectedTextContainerH
            let containerW = width - padding * 2
            yPos -= containerH
            
            let selectedContainer = NSView(frame: NSRect(x: padding, y: yPos, width: containerW, height: containerH))
            selectedContainer.wantsLayer = true
            selectedContainer.layer?.backgroundColor = Self.innerPanelBG.cgColor
            selectedContainer.layer?.cornerRadius = Self.innerCornerRadius
            contentView.addSubview(selectedContainer)
            
            // Document icon inside container
            let docIcon = NSImageView(frame: NSRect(x: 10, y: (containerH - 16) / 2, width: 16, height: 16))
            let docConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            docIcon.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)?.withSymbolConfiguration(docConfig)
            docIcon.contentTintColor = Self.primaryText
            selectedContainer.addSubview(docIcon)
            
            // Selected text label (truncated, reduced width for close button)
            let truncatedText = selectedText.count > 30 ? String(selectedText.prefix(30)) + "..." : selectedText
            let selectedLabel = makeLabel("Selected text: \(truncatedText)", size: 12, weight: .regular, color: Self.primaryText)
            selectedLabel.frame = NSRect(x: 30, y: (containerH - 14) / 2, width: containerW - 60, height: 14)
            selectedContainer.addSubview(selectedLabel)
            
            // Close button to discard selected text
            let closeBtnChat = NSButton(frame: NSRect(
                x: containerW - 10 - 16,
                y: (containerH - 16) / 2,
                width: 16,
                height: 16
            ))
            let closeChatConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            closeBtnChat.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Clear selected text")?
                .withSymbolConfiguration(closeChatConfig)
            closeBtnChat.isBordered = false
            closeBtnChat.bezelStyle = .inline
            closeBtnChat.contentTintColor = Self.secondaryText
            closeBtnChat.target = self
            closeBtnChat.action = #selector(clearSelectedTextTapped)
            selectedContainer.addSubview(closeBtnChat)
            
            yPos -= 12  // Gap below selected text
        }
        
        // Action pill (first user action) - RIGHT ALIGNED
        if !lastAction.isEmpty {
            let pillWidth = estimatePillWidth(lastAction)
            let pillH: CGFloat = 40  // Increased height for better proportions
            let pillX = width - padding - pillWidth  // Right-aligned
            yPos -= pillH
            
            let pillBG = NSView(frame: NSRect(x: pillX, y: yPos, width: pillWidth, height: pillH))
            pillBG.wantsLayer = true
            pillBG.layer?.backgroundColor = Self.actionPillBG.cgColor
            pillBG.layer?.cornerRadius = pillH / 2  // Perfect pill shape (half height)
            contentView.addSubview(pillBG)
            
            let pillLabel = makeLabel(lastAction, size: Self.messageFontSize, weight: .regular, color: Self.primaryText)
            pillLabel.frame = NSRect(x: Self.userBubblePaddingH, y: (pillH - 16) / 2, width: pillWidth - Self.userBubblePaddingH * 2, height: 16)
            pillBG.addSubview(pillLabel)
            
            yPos -= Self.messageSpacing  // Gap below action pill
        }
        
        // Conversation messages in chronological order (oldest first, newest at bottom)
        for (index, msgData) in messageHeights.enumerated() {
            let message = conversationMessages[index]
            
            if msgData.role == .assistant {
                let availableWidth = width - padding * 2
                let textHeight = msgData.textHeight
                
                // Position from top of this message block
                yPos -= textHeight
                
                // AI response text (no avatar)
                let responseLabel = NSTextField(wrappingLabelWithString: message.content)
                responseLabel.font = .systemFont(ofSize: Self.messageFontSize)
                responseLabel.textColor = Self.primaryText
                responseLabel.isBezeled = false
                responseLabel.drawsBackground = false
                responseLabel.isEditable = false
                responseLabel.isSelectable = true
                responseLabel.frame = NSRect(x: padding, y: yPos, width: availableWidth, height: textHeight)
                contentView.addSubview(responseLabel)
                
                yPos -= 8  // Gap between text and action buttons
                
                // Action icons row BELOW the text
                yPos -= btnSize
                var btnX: CGFloat = padding
                
                let copyBtn = makeSmallIconButton(symbolName: "doc.on.doc", action: #selector(copyTapped))
                copyBtn.frame = NSRect(x: btnX, y: yPos, width: btnSize, height: btnSize)
                contentView.addSubview(copyBtn)
                btnX += btnSize + btnSpacing
                
                let refreshBtn = makeSmallIconButton(symbolName: "arrow.clockwise", action: #selector(regenerateTapped))
                refreshBtn.frame = NSRect(x: btnX, y: yPos, width: btnSize, height: btnSize)
                contentView.addSubview(refreshBtn)
                btnX += btnSize + btnSpacing
                
                let likeBtn = makeSmallIconButton(symbolName: "hand.thumbsup", action: #selector(likeTapped))
                likeBtn.frame = NSRect(x: btnX, y: yPos, width: btnSize, height: btnSize)
                contentView.addSubview(likeBtn)
                btnX += btnSize + btnSpacing
                
                let dislikeBtn = makeSmallIconButton(symbolName: "hand.thumbsdown", action: #selector(dislikeTapped))
                dislikeBtn.frame = NSRect(x: btnX, y: yPos, width: btnSize, height: btnSize)
                contentView.addSubview(dislikeBtn)
                
                yPos -= Self.messageSpacing  // Bottom spacing for this message block
                
            } else if msgData.role == .user {
                // User messages as right-aligned pill bubbles
                let textHeight = msgData.textHeight
                let bubbleW = msgData.bubbleW
                let bubbleH = textHeight + Self.userBubblePaddingV * 2
                let bubbleX = width - padding - bubbleW  // Right-aligned
                
                yPos -= bubbleH
                
                // Bubble background - pill for single line, rounded for multi-line
                let bubbleBG = NSView(frame: NSRect(x: bubbleX, y: yPos, width: bubbleW, height: bubbleH))
                bubbleBG.wantsLayer = true
                bubbleBG.layer?.backgroundColor = Self.actionPillBG.cgColor
                // Use pill shape (half height radius) for single-line text, rounded corners for multi-line
                let isSingleLine = textHeight <= 22  // Approximate single line at 14pt font
                bubbleBG.layer?.cornerRadius = isSingleLine ? bubbleH / 2 : 16
                contentView.addSubview(bubbleBG)
                
                // User message text inside bubble - centered vertically
                let labelWidth = bubbleW - Self.userBubblePaddingH * 2
                let userLabel = NSTextField(wrappingLabelWithString: message.content)
                userLabel.font = .systemFont(ofSize: Self.messageFontSize)
                userLabel.textColor = Self.primaryText
                userLabel.isBezeled = false
                userLabel.drawsBackground = false
                userLabel.isEditable = false
                userLabel.isSelectable = true
                userLabel.lineBreakMode = .byWordWrapping
                userLabel.cell?.wraps = true
                userLabel.cell?.isScrollable = false
                // Center text vertically within bubble
                let textY = (bubbleH - textHeight) / 2
                userLabel.frame = NSRect(x: Self.userBubblePaddingH, y: textY, width: labelWidth, height: textHeight)
                bubbleBG.addSubview(userLabel)
                
                yPos -= Self.messageSpacing  // Gap below user bubble
            }
        }
        
        // Loading indicator at the bottom (newest position)
        if isLoadingInline {
            let indicatorH: CGFloat = 24
            yPos -= indicatorH
            
            // Animated typing dots (no avatar)
            let typingIndicator = TypingIndicatorView(color: Self.secondaryText)
            typingIndicator.frame = NSRect(x: padding, y: yPos + 9, width: typingIndicator.frame.width, height: typingIndicator.frame.height)
            typingIndicator.startAnimating()
            contentView.addSubview(typingIndicator)
        }
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
        guard let scrollView = chatScrollView else { return }
        // Scroll to y=0 to show the bottom content (newest messages)
        // Since we build from top (high y) to bottom (low y), y=0 shows the most recent
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
    }
    
    private func estimatePillWidth(_ text: String) -> CGFloat {
        let attr = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: Self.messageFontSize, weight: .medium)])
        let rect = attr.boundingRect(with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: 24), options: [.usesLineFragmentOrigin])
        return ceil(rect.width) + Self.userBubblePaddingH * 2 + 8  // Padding for pill shape
    }
    
    private func estimateTextWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        let attr = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: fontSize)])
        let rect = attr.boundingRect(with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin])
        return ceil(rect.width)
    }

    // MARK: - Compliance Panel State
    
    private func buildCompliancePanelUI(size: NSSize) {
        currentState = .compliancePanel
        panel.allowsKeyStatus = false
        clearContainer()
        
        let width = size.width
        let height = size.height
        let padding: CGFloat = 16
        
        // Card background
        let cardLayer = CALayer()
        cardLayer.frame = CGRect(origin: .zero, size: size)
        cardLayer.backgroundColor = Self.cardBG.cgColor
        cardLayer.cornerRadius = Self.cardCornerRadius
        containerView.layer?.addSublayer(cardLayer)
        
        // Header
        let logoSize: CGFloat = 28
        let headerY = height - 12 - logoSize
        
        let avatar = makeAvatarImageView(size: logoSize)
        avatar.frame = NSRect(x: padding, y: headerY, width: logoSize, height: logoSize)
        containerView.addSubview(avatar)
        
        let titleLabel = makeLabel("compliance check", size: 14, weight: .medium, color: Self.titleText)
        titleLabel.frame = NSRect(x: padding + logoSize + 10, y: headerY + (logoSize - 16) / 2, width: 200, height: 16)
        containerView.addSubview(titleLabel)
        
        let closeBtn = makeCloseButton()
        closeBtn.frame = NSRect(x: width - 16 - padding, y: headerY + (logoSize - 16) / 2, width: 16, height: 16)
        containerView.addSubview(closeBtn)
        
        // Get validation result
        guard let result = currentValidationResult else {
            let noDataLabel = makeLabel("no validation data", size: 13, weight: .regular, color: Self.secondaryText)
            noDataLabel.frame = NSRect(x: padding, y: height / 2, width: width - padding * 2, height: 20)
            noDataLabel.alignment = .center
            containerView.addSubview(noDataLabel)
            return
        }
        
        // Score section
        let scoreY = headerY - 100
        let scoreSize: CGFloat = 60
        let scoreX = (width - scoreSize) / 2
        
        // Score circle
        let scoreCircle = NSView(frame: NSRect(x: scoreX, y: scoreY + 30, width: scoreSize, height: scoreSize))
        scoreCircle.wantsLayer = true
        scoreCircle.layer?.cornerRadius = scoreSize / 2
        scoreCircle.layer?.backgroundColor = colorForScore(result.score).cgColor
        containerView.addSubview(scoreCircle)
        
        let scoreLabel = makeLabel("\(result.score)", size: 22, weight: .bold, color: .white)
        scoreLabel.alignment = .center
        scoreLabel.frame = NSRect(x: 0, y: (scoreSize - 26) / 2, width: scoreSize, height: 26)
        scoreCircle.addSubview(scoreLabel)
        
        // Status text
        let statusText = result.passed ? "passed" : "needs attention"
        let statusColor = result.passed ? NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1) : NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1)
        let statusLabel = makeLabel(statusText, size: 13, weight: .medium, color: statusColor)
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: padding, y: scoreY + 6, width: width - padding * 2, height: 18)
        containerView.addSubview(statusLabel)
        
        // Violations section
        let violationsY = scoreY - 16
        let violationsSectionHeight: CGFloat = 160
        
        if !result.violations.isEmpty {
            let violationsContainer = NSScrollView(frame: NSRect(x: padding, y: violationsY - violationsSectionHeight, width: width - padding * 2, height: violationsSectionHeight))
            violationsContainer.hasVerticalScroller = true
            violationsContainer.hasHorizontalScroller = false
            violationsContainer.borderType = .noBorder
            violationsContainer.backgroundColor = .clear
            violationsContainer.drawsBackground = false
            violationsContainer.autohidesScrollers = true
            
            let rowHeight: CGFloat = 44
            let contentHeight = CGFloat(result.violations.count) * rowHeight
            let documentView = NSView(frame: NSRect(x: 0, y: 0, width: width - padding * 2, height: max(contentHeight, violationsSectionHeight)))
            documentView.wantsLayer = true
            
            for (index, violation) in result.violations.enumerated() {
                let rowY = documentView.bounds.height - CGFloat(index + 1) * rowHeight
                buildViolationRow(in: documentView, at: rowY, violation: violation, width: width - padding * 2)
            }
            
            violationsContainer.documentView = documentView
            containerView.addSubview(violationsContainer)
        } else {
            let noIssuesLabel = makeLabel("no issues found", size: 13, weight: .regular, color: Self.secondaryText)
            noIssuesLabel.alignment = .center
            noIssuesLabel.frame = NSRect(x: padding, y: violationsY - 60, width: width - padding * 2, height: 20)
            containerView.addSubview(noIssuesLabel)
        }
        
        // Summary row at bottom
        let summaryY: CGFloat = 56
        let summaryHeight: CGFloat = 36
        
        let summaryBG = NSView(frame: NSRect(x: padding, y: summaryY, width: width - padding * 2, height: summaryHeight))
        summaryBG.wantsLayer = true
        summaryBG.layer?.backgroundColor = Self.innerPanelBG.cgColor
        summaryBG.layer?.cornerRadius = 8
        containerView.addSubview(summaryBG)
        
        let statWidth = (width - padding * 2) / 3
        buildSummaryStatCompact(in: summaryBG, at: 0, value: result.errorCount, label: "errors", color: result.errorCount > 0 ? NSColor.systemRed : Self.secondaryText, width: statWidth)
        buildSummaryStatCompact(in: summaryBG, at: statWidth, value: result.warningCount, label: "warnings", color: result.warningCount > 0 ? NSColor.systemOrange : Self.secondaryText, width: statWidth)
        buildSummaryStatCompact(in: summaryBG, at: statWidth * 2, value: result.autoFixableCount, label: "fixable", color: result.autoFixableCount > 0 ? NSColor.systemGreen : Self.secondaryText, width: statWidth)
    }
    
    private func buildViolationRow(in parent: NSView, at y: CGFloat, violation: Violation, width: CGFloat) {
        let rowHeight: CGFloat = 40
        let iconSize: CGFloat = 16
        
        let iconColor: NSColor
        let iconName: String
        
        switch violation.severity {
        case .error:
            iconColor = NSColor.systemRed
            iconName = "xmark.circle.fill"
        case .warning:
            iconColor = NSColor.systemOrange
            iconName = "exclamationmark.triangle.fill"
        case .info:
            iconColor = NSColor.systemBlue
            iconName = "info.circle.fill"
        }
        
        let icon = NSImageView(frame: NSRect(x: 0, y: y + (rowHeight - iconSize) / 2, width: iconSize, height: iconSize))
        icon.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        icon.contentTintColor = iconColor
        parent.addSubview(icon)
        
        let textLabel = makeLabel("\"\(violation.text)\"", size: 12, weight: .medium, color: Self.primaryText)
        textLabel.frame = NSRect(x: iconSize + 8, y: y + rowHeight / 2, width: width - iconSize - 8, height: 16)
        textLabel.lineBreakMode = .byTruncatingTail
        parent.addSubview(textLabel)
        
        let suggestionLabel = makeLabel(violation.suggestion, size: 10, weight: .regular, color: Self.secondaryText)
        suggestionLabel.frame = NSRect(x: iconSize + 8, y: y + 4, width: width - iconSize - 8, height: 14)
        suggestionLabel.lineBreakMode = .byTruncatingTail
        parent.addSubview(suggestionLabel)
    }
    
    private func buildSummaryStatCompact(in parent: NSView, at x: CGFloat, value: Int, label: String, color: NSColor, width: CGFloat) {
        let valueLabel = makeLabel("\(value)", size: 14, weight: .bold, color: color)
        valueLabel.alignment = .center
        valueLabel.frame = NSRect(x: x, y: 16, width: width, height: 18)
        parent.addSubview(valueLabel)
        
        let labelText = makeLabel(label, size: 10, weight: .regular, color: Self.secondaryText)
        labelText.alignment = .center
        labelText.frame = NSRect(x: x, y: 4, width: width, height: 12)
        parent.addSubview(labelText)
    }
    
    private func colorForScore(_ score: Int) -> NSColor {
        if score >= 90 { return NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1) }  // Green
        if score >= 70 { return NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1) }    // Yellow
        return NSColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1)                        // Red
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
        let backBtn   = makeTextButton("Back",   action: #selector(backToChatTapped))
        let cancelBtn = makeTextButton("Dismiss", action: #selector(cancelTapped))
        retryBtn.frame  = NSRect(x: padding, y: 10, width: 60, height: 26)
        backBtn.frame   = NSRect(x: padding + 66, y: 10, width: 55, height: 26)
        cancelBtn.frame = NSRect(x: padding + 127, y: 10, width: 70, height: 26)
        containerView.addSubview(retryBtn)
        containerView.addSubview(backBtn)
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
        
        // Apple-style spring animation for smooth transitions
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func makeAvatarImageView(size: CGFloat) -> NSImageView {
        let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        imageView.image = NSImage(named: "ProductIndicator")
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
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
    
    private func makeSmallIconButton(symbolName: String, action: Selector) -> HoverButton {
        let btn = HoverButton(hoverColor: NSColor.white.withAlphaComponent(0.1), cornerRadius: 4)
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        btn.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        btn.isBordered = false
        btn.bezelStyle = .shadowlessSquare
        btn.target = self
        btn.action = action
        btn.contentTintColor = NSColor(white: 0.5, alpha: 1)
        btn.imageScaling = .scaleProportionallyDown
        btn.toolTip = symbolName == "doc.on.doc" ? "Copy" :
                      symbolName == "arrow.clockwise" ? "Regenerate" :
                      symbolName == "hand.thumbsup" ? "Good response" :
                      symbolName == "hand.thumbsdown" ? "Bad response" : nil
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
            case .chatWindow, .chatLoading, .error, .floatingFAB, .optionsMenu, .compliancePanel:
                // Don't dismiss on outside click for these states
                break
            case .miniIcon, .noSelection:
                let mouseLoc = NSEvent.mouseLocation
                if !self.panel.frame.contains(mouseLoc) {
                    self.hide()
                }
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // Escape key
                self.hide()
                self.onCancel?()
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
            // Check which input field triggered this
            if control == quickActionsInputField {
                submitQuickActionsInput()
            } else {
                submitInput()
            }
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
        lastAction = "Validate current compliance"
        Task { [weak self] in
            guard let self = self else { return }
            
            let result = await ValidationService.shared.validate(self.selectedText)
            self.currentValidationResult = result
            
            await MainActor.run {
                self.updateUI(.compliancePanel)
            }
        }
    }
    
    private func showValidationReport(_ result: ValidationResult) {
        let message = ChatMessage(
            role: .action,
            content: lastAction
        )
        conversationMessages.append(message)
        
        var reportContent = ""
        
        if result.passed {
            reportContent = "✓ Content passes compliance check with score \(result.score)/100\n\n"
        } else {
            reportContent = "⚠ Content needs attention. Score: \(result.score)/100\n\n"
        }
        
        if result.errorCount > 0 {
            reportContent += "**\(result.errorCount) errors** (must fix)\n"
        }
        if result.warningCount > 0 {
            reportContent += "**\(result.warningCount) warnings** (should fix)\n"
        }
        if result.infoCount > 0 {
            reportContent += "**\(result.infoCount) suggestions**\n"
        }
        
        if !result.violations.isEmpty {
            reportContent += "\n**Issues found:**\n"
            for (index, violation) in result.violations.prefix(5).enumerated() {
                let icon = violation.severity == .error ? "❌" : (violation.severity == .warning ? "⚠️" : "ℹ️")
                reportContent += "\(index + 1). \(icon) \(violation.category): \"\(violation.text)\"\n"
                if !violation.suggestion.isEmpty {
                    reportContent += "   → \(violation.suggestion)\n"
                }
            }
            if result.violations.count > 5 {
                reportContent += "   ... and \(result.violations.count - 5) more issues\n"
            }
        }
        
        if result.autoFixableCount > 0 {
            reportContent += "\n💡 **\(result.autoFixableCount) issues can be auto-fixed**"
        }
        
        let responseMessage = ChatMessage(
            role: .assistant,
            content: reportContent,
            validationResult: result
        )
        conversationMessages.append(responseMessage)
        lastResponse = reportContent
        
        updateUI(.chatWindow)
    }
    
    private func runPreValidation() async {
        guard !selectedText.isEmpty else { return }
        let (errors, warnings) = await ValidationService.shared.validateQuick(selectedText)
        let totalIssues = errors + warnings
        
        await MainActor.run { [weak self] in
            guard let self = self, let badgeView = self.validationBadgeView else { return }
            
            if totalIssues > 0 {
                badgeView.isHidden = false
                badgeView.layer?.backgroundColor = errors > 0 ? NSColor.systemRed.cgColor : NSColor.systemOrange.cgColor
                
                badgeView.subviews.forEach { $0.removeFromSuperview() }
                
                let countLabel = self.makeLabel("\(totalIssues)", size: 11, weight: .semibold, color: .white)
                countLabel.alignment = .center
                countLabel.frame = NSRect(x: 0, y: 2, width: 40, height: 16)
                badgeView.addSubview(countLabel)
            } else {
                badgeView.isHidden = true
            }
        }
    }
    
    @objc private func inputPlaceholderTapped() {
        updateUI(.chatWindow)
        focusInputField()
    }
    
    @objc private func sendButtonTapped() {
        submitInput()
    }
    
    @objc private func quickActionsSendTapped() {
        submitQuickActionsInput()
    }
    
    @objc private func clearSelectedTextTapped() {
        selectedText = ""
        onClearSelectedText?()
        updateUI(currentState)
    }
    
    private func submitQuickActionsInput() {
        guard let field = quickActionsInputField else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if text.isEmpty {
            // Empty input = just transition to chat with focus on input
            updateUI(.chatWindow)
            focusInputField()
        } else {
            // User typed something - submit as custom prompt
            field.stringValue = ""
            lastAction = text
            onCustomPrompt?(text)
        }
    }
    
    private func focusInputField() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, let field = self.inputField else { return }
            self.panel.allowsKeyStatus = true
            self.panel.makeFirstResponder(field)
        }
    }
    
    @objc private func copyTapped() {
        onCopy?(lastResponse)
    }
    
    @objc private func cancelTapped() {
        hide()
        onCancel?()
    }
    
    @objc private func fabTapped() {
        // Restore chat window from FAB
        if !isFabHovered {
            restoreChatFromFAB()
        }
    }
    
    @objc private func fabCloseTapped() {
        // Fully close and clear conversation
        hide()
        onCancel?()
    }
    
    private func restoreChatFromFAB() {
        // Restore chat window anchored to current FAB position with iOS-style spring animation
        let height = calculateChatWindowHeight()
        let size = NSSize(width: Self.chatWindowWidth, height: height)
        
        // ALWAYS use current FAB position as anchor (not old chat window position)
        // This ensures the chat opens near where the FAB currently is after dragging
        let fabFrame = panel.frame
        var targetFrame = NSRect(
            x: fabFrame.minX,
            y: fabFrame.maxY - size.height,  // Align top of chat with top of FAB
            width: size.width,
            height: size.height
        )
        
        // Ensure on screen
        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(targetFrame) }) ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            if targetFrame.minX < visibleFrame.minX + Self.screenEdgePadding {
                targetFrame.origin.x = visibleFrame.minX + Self.screenEdgePadding
            }
            if targetFrame.maxX > visibleFrame.maxX - Self.screenEdgePadding {
                targetFrame.origin.x = visibleFrame.maxX - size.width - Self.screenEdgePadding
            }
            if targetFrame.minY < visibleFrame.minY + Self.screenEdgePadding {
                targetFrame.origin.y = visibleFrame.minY + Self.screenEdgePadding
            }
            if targetFrame.maxY > visibleFrame.maxY - Self.screenEdgePadding {
                targetFrame.origin.y = visibleFrame.maxY - size.height - Self.screenEdgePadding
            }
        }
        
        clearContainer()
        buildChatWindowUI(size: size)
        currentState = .chatWindow
        panel.isMovableByWindowBackground = true
        
        // iOS-style spring animation (quick expand)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(targetFrame, display: true)
        }
    }
    
    // MARK: - FAB Hover Tracking
    
    func mouseEntered(with event: NSEvent) {
        guard currentState == .floatingFAB else { return }
        isFabHovered = true
        showFABCloseButton()
    }
    
    func mouseExited(with event: NSEvent) {
        guard currentState == .floatingFAB else { return }
        isFabHovered = false
        hideFABCloseButton()
    }
    
    private func showFABCloseButton() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            fabCloseButton?.animator().alphaValue = 1
        }
    }
    
    private func hideFABCloseButton() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            fabCloseButton?.animator().alphaValue = 0
        }
    }
    
    @objc private func retryTapped() {
        onRetry?()
    }
    
    @objc private func backToChatTapped() {
        let height = calculateChatWindowHeight()
        let size = NSSize(width: Self.chatWindowWidth, height: height)
        buildChatWindowUI(size: size)
        currentState = .chatWindow
        resizeAndReanchor(to: size)
        enableInput()
        focusInputField()
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
