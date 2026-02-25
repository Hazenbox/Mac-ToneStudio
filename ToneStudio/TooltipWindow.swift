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
    case error(String)
    
    static func == (lhs: TooltipState, rhs: TooltipState) -> Bool {
        switch (lhs, rhs) {
        case (.miniIcon, .miniIcon),
             (.noSelection, .noSelection),
             (.optionsMenu, .optionsMenu),
             (.chatWindow, .chatWindow),
             (.chatLoading, .chatLoading),
             (.floatingFAB, .floatingFAB):
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

// MARK: - KeyablePanel (allows text input in floating panel)

final class KeyablePanel: NSPanel {
    var allowsKeyStatus: Bool = false
    
    override var canBecomeKey: Bool {
        return allowsKeyStatus
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
    private let panel: KeyablePanel
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
    private var fabCloseButton: NSButton?
    private var fabTrackingArea: NSTrackingArea?
    private var isFabHovered: Bool = false
    private var lastChatWindowFrame: NSRect?

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
    private static let fabSize: CGFloat = 40
    private static let userBubbleMaxWidthRatio: CGFloat = 0.8
    private static let selectedTextContainerH: CGFloat = 42

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
            styleMask: [.borderless],
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
        case .floatingFAB:
            buildFloatingFABUI(size: size)
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
        case .chatWindow, .chatLoading, .error, .optionsMenu, .floatingFAB:
            return true
        case .miniIcon, .noSelection:
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
            
        case .floatingFAB:
            panel.isMovableByWindowBackground = false
            let size = NSSize(width: Self.fabSize, height: Self.fabSize)
            buildFloatingFABUI(size: size)
            // Animate the shrinking transition
            animateResizeAndReanchor(to: size)
        }
    }
    
    private func animateResizeAndReanchor(to size: NSSize) {
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
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
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
        panel.allowsKeyStatus = false
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
    
    // MARK: - Floating FAB State
    
    private func buildFloatingFABUI(size: NSSize) {
        currentState = .floatingFAB
        panel.allowsKeyStatus = false
        clearContainer()
        
        let iconSize = size.width
        
        // Circular background
        let bgLayer = CALayer()
        bgLayer.frame = CGRect(origin: .zero, size: size)
        bgLayer.backgroundColor = Self.cardBG.cgColor
        bgLayer.cornerRadius = iconSize / 2
        bgLayer.shadowColor = NSColor.black.cgColor
        bgLayer.shadowOpacity = 0.4
        bgLayer.shadowOffset = CGSize(width: 0, height: -2)
        bgLayer.shadowRadius = 6
        containerView.layer?.addSublayer(bgLayer)
        
        // Jio logo avatar
        let avatarSize = iconSize - 12
        let avatar = makeAvatarImageView(size: avatarSize)
        avatar.frame = NSRect(
            x: (iconSize - avatarSize) / 2,
            y: (iconSize - avatarSize) / 2,
            width: avatarSize,
            height: avatarSize
        )
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
        
        // Main click area for restoring chat
        let clickArea = ClickThroughButton(frame: NSRect(origin: .zero, size: size))
        clickArea.target = self
        clickArea.action = #selector(fabTapped)
        clickArea.isBordered = false
        clickArea.bezelStyle = .shadowlessSquare
        containerView.addSubview(clickArea)
        
        // Add tracking area for hover detection
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
        panel.allowsKeyStatus = false
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
        panel.allowsKeyStatus = true
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
        let inputPanelH: CGFloat = 44
        let inputPanelY: CGFloat = 7
        let sendBtnSize: CGFloat = 28
        
        let inputBG = NSView(frame: NSRect(x: 7, y: inputPanelY, width: width - 14, height: inputPanelH))
        inputBG.wantsLayer = true
        inputBG.layer?.backgroundColor = Self.innerPanelBG.cgColor
        inputBG.layer?.cornerRadius = Self.innerCornerRadius
        containerView.addSubview(inputBG)
        
        // Send button on the right side of input area
        let sendBtn = NSButton(frame: NSRect(
            x: width - 7 - 8 - sendBtnSize,
            y: inputPanelY + (inputPanelH - sendBtnSize) / 2,
            width: sendBtnSize,
            height: sendBtnSize
        ))
        let sendConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        sendBtn.image = NSImage(systemSymbolName: "arrow.up.circle.fill", accessibilityDescription: "Send")?
            .withSymbolConfiguration(sendConfig)
        sendBtn.isBordered = false
        sendBtn.bezelStyle = .shadowlessSquare
        sendBtn.contentTintColor = isLoadingInline ? Self.secondaryText : NSColor.systemBlue
        sendBtn.target = self
        sendBtn.action = #selector(sendButtonTapped)
        sendBtn.isEnabled = !isLoadingInline
        containerView.addSubview(sendBtn)
        
        // Add text field directly to containerView for proper focus handling
        let textFieldH: CGFloat = 22
        let textField = NSTextField(frame: NSRect(
            x: 7 + 10,
            y: inputPanelY + (inputPanelH - textFieldH) / 2,
            width: width - 14 - 20 - sendBtnSize - 4,
            height: textFieldH
        ))
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
        containerView.addSubview(textField)
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.scrollToBottom()
            // Focus input field when chat window is shown
            if let field = self?.inputField, field.isEnabled {
                self?.panel.makeKeyAndOrderFront(nil)
                self?.panel.makeFirstResponder(field)
            }
        }
    }
    
    private func buildChatContentInView(_ contentView: NSView, width: CGFloat, availableHeight: CGFloat) {
        let padding: CGFloat = 7
        var yOffset: CGFloat = 8
        var totalHeight: CGFloat = 8
        
        // Selected text in dark container (matching quick actions style)
        if !selectedText.isEmpty {
            let containerH = Self.selectedTextContainerH
            let containerW = width - padding * 2
            
            let selectedContainer = NSView(frame: NSRect(x: padding, y: yOffset, width: containerW, height: containerH))
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
            
            // Selected text label (truncated)
            let truncatedText = selectedText.count > 35 ? String(selectedText.prefix(35)) + "..." : selectedText
            let selectedLabel = makeLabel("Selected text: \(truncatedText)", size: 12, weight: .regular, color: Self.primaryText)
            selectedLabel.frame = NSRect(x: 30, y: (containerH - 14) / 2, width: containerW - 40, height: 14)
            selectedContainer.addSubview(selectedLabel)
            
            yOffset += containerH + 12
            totalHeight += containerH + 12
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
            
            yOffset += pillH + 12
            totalHeight += pillH + 12
        }
        
        // Conversation messages
        let avatarSize: CGFloat = 16
        let avatarPadding: CGFloat = 8
        let contentIndent = padding + avatarSize + avatarPadding
        
        for message in conversationMessages {
            if message.role == .assistant {
                let availableWidth = width - contentIndent - padding
                let textHeight = estimateTextHeight(message.content, width: availableWidth, fontSize: 12)
                let messageH = textHeight + 50
                
                // AI avatar
                let aiAvatar = makeAvatarImageView(size: avatarSize)
                aiAvatar.frame = NSRect(x: padding, y: yOffset + textHeight - avatarSize, width: avatarSize, height: avatarSize)
                contentView.addSubview(aiAvatar)
                
                // AI response text with line-height 1.2
                let responseLabel = NSTextField(wrappingLabelWithString: message.content)
                responseLabel.font = .systemFont(ofSize: 12)
                responseLabel.textColor = Self.primaryText
                responseLabel.isBezeled = false
                responseLabel.drawsBackground = false
                responseLabel.isEditable = false
                responseLabel.isSelectable = true
                responseLabel.frame = NSRect(x: contentIndent, y: yOffset, width: availableWidth, height: textHeight)
                contentView.addSubview(responseLabel)
                
                yOffset += textHeight + 8
                
                // Action icons row - aligned with content (after avatar)
                let actionsY = yOffset
                var btnX: CGFloat = contentIndent
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
                // User messages as right-aligned pill bubbles
                let maxBubbleWidth = (width - padding * 2) * Self.userBubbleMaxWidthRatio
                let textWidth = min(estimateTextWidth(message.content, fontSize: 12), maxBubbleWidth - 24)
                let textHeight = estimateTextHeight(message.content, width: textWidth, fontSize: 12)
                
                let bubblePaddingH: CGFloat = 12
                let bubblePaddingV: CGFloat = 9
                let bubbleW = textWidth + bubblePaddingH * 2
                let bubbleH = textHeight + bubblePaddingV * 2
                let bubbleX = width - padding - bubbleW  // Right-aligned
                
                // Pill bubble background
                let bubbleBG = NSView(frame: NSRect(x: bubbleX, y: yOffset, width: bubbleW, height: bubbleH))
                bubbleBG.wantsLayer = true
                bubbleBG.layer?.backgroundColor = Self.actionPillBG.cgColor
                bubbleBG.layer?.cornerRadius = Self.pillCornerRadius
                contentView.addSubview(bubbleBG)
                
                // User message text inside bubble
                let userLabel = NSTextField(wrappingLabelWithString: message.content)
                userLabel.font = .systemFont(ofSize: 12)
                userLabel.textColor = Self.primaryText
                userLabel.isBezeled = false
                userLabel.drawsBackground = false
                userLabel.isEditable = false
                userLabel.isSelectable = true
                userLabel.frame = NSRect(x: bubblePaddingH, y: bubblePaddingV, width: textWidth, height: textHeight)
                bubbleBG.addSubview(userLabel)
                
                yOffset += bubbleH + 12
                totalHeight += bubbleH + 12
            }
        }
        
        // Loading indicator with animated typing dots
        if isLoadingInline {
            let indicatorH: CGFloat = 24
            
            // Add small Jio avatar for AI response indicator
            let aiAvatar = makeAvatarImageView(size: 16)
            aiAvatar.frame = NSRect(x: padding, y: yOffset + 4, width: 16, height: 16)
            contentView.addSubview(aiAvatar)
            
            // Animated typing dots
            let typingIndicator = TypingIndicatorView(color: Self.secondaryText)
            typingIndicator.frame = NSRect(x: padding + 24, y: yOffset + 9, width: typingIndicator.frame.width, height: typingIndicator.frame.height)
            typingIndicator.startAnimating()
            contentView.addSubview(typingIndicator)
            
            yOffset += indicatorH + 12
            totalHeight += indicatorH + 12
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
    
    private func estimateTextWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        let attr = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: fontSize)])
        let rect = attr.boundingRect(with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin])
        return ceil(rect.width)
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
            case .chatWindow, .chatLoading, .error, .floatingFAB:
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
            guard let self else { return event }
            if event.keyCode == 53 { // Escape key
                if self.currentState == .chatWindow || self.currentState == .chatLoading {
                    // Minimize to FAB
                    self.lastChatWindowFrame = self.panel.frame
                    self.updateUI(.floatingFAB)
                } else if self.currentState == .floatingFAB {
                    // Close FAB completely
                    self.hide()
                    self.onCancel?()
                } else {
                    self.hide()
                    self.onCancel?()
                }
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
        focusInputField()
    }
    
    @objc private func sendButtonTapped() {
        submitInput()
    }
    
    private func focusInputField() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, let field = self.inputField else { return }
            self.panel.allowsKeyStatus = true
            self.panel.makeKeyAndOrderFront(nil)
            self.panel.makeFirstResponder(field)
        }
    }
    
    @objc private func copyTapped() {
        onCopy?(lastResponse)
    }
    
    @objc private func cancelTapped() {
        // Minimize to FAB instead of hiding if we have conversation
        if currentState == .chatWindow || currentState == .chatLoading {
            lastChatWindowFrame = panel.frame
            updateUI(.floatingFAB)
        } else {
            hide()
            onCancel?()
        }
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
        // Restore to previous chat window position with animation
        if let lastFrame = lastChatWindowFrame {
            let height = calculateChatWindowHeight()
            let size = NSSize(width: Self.chatWindowWidth, height: height)
            clearContainer()
            buildChatWindowUI(size: size)
            currentState = .chatWindow
            panel.isMovableByWindowBackground = true
            
            var targetFrame = lastFrame
            targetFrame.size = size
            
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            updateUI(.chatWindow)
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
