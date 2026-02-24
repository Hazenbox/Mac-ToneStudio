import Cocoa
import OSLog

// MARK: - Tooltip States

enum TooltipState {
    case miniIcon
    case noSelection
    case collapsed
    case loading
    case result(String)
    case error(String)
}

// MARK: - Speech Bubble Tail View

/// Draws a downward pointing speech bubble tail (like an upside-down triangle)
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
        // Triangle pointing downward from center of bubble bottom
        path.move(to: CGPoint(x: w / 2 - 7, y: h))
        path.line(to: CGPoint(x: w / 2 + 7, y: h))
        path.line(to: CGPoint(x: w / 2, y: 0))
        path.close()
        fillColor.setFill()
        path.fill()
    }
}

// MARK: - Dark Bubble Container View

/// Rounded dark pill container with a downward speech tail
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

        // Bubble rect sits above the tail
        let bubbleRect = CGRect(x: 0, y: th, width: bounds.width, height: bounds.height - th)

        // Bubble body
        let bLayer = CALayer()
        bLayer.frame = bubbleRect
        bLayer.backgroundColor = bubbleColor.cgColor
        bLayer.cornerRadius = cr
        bLayer.masksToBounds = true
        layer.addSublayer(bLayer)
        bubbleLayer = bLayer

        // Tail triangle (centered at bottom of bubble)
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
final class TooltipWindow {

    var onRephrase: (() -> Void)?
    var onReplace: ((String) -> Void)?
    var onCopy: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onRetry: (() -> Void)?

    // MARK: Panel
    private let panel: NSPanel
    private let containerView: NSView       // transparent root
    private var currentState: TooltipState = .collapsed
    private var rewrittenText: String = ""

    // MARK: Event monitors
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?
    
    // MARK: Auto-hide timer
    private var autoHideTimer: Timer?

    // MARK: Sizing
    private static let miniIconSize = AppConstants.miniIconSize
    private static let noSelectionSize = NSSize(width: 160, height: 36)
    /// Tail height reserved at the bottom of the panel for default/loading states
    private static let tailHeight: CGFloat = BubbleContainerView.tailHeight
    private static let bubbleCorner: CGFloat = BubbleContainerView.cornerRadius
    /// Panel sizes per state
    private static let defaultSize  = NSSize(width: 230, height: 44 + tailHeight)
    private static let loadingSize  = NSSize(width: 200, height: 44 + tailHeight)
    private static let resultWidth: CGFloat  = 360
    private static let errorWidth: CGFloat   = 300

    // MARK: Colors
    private static let darkBubbleBG  = NSColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1)
    private static let resultCardBG  = NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)
    private static let resultBorder  = NSColor(red: 0.30, green: 0.30, blue: 0.33, alpha: 1)
    private static let primaryText   = NSColor.white
    private static let secondaryText = NSColor(white: 0.7, alpha: 1)
    private static let contentBG     = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 230, height: 52),
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
    }

    // MARK: - Positioning Constants
    
    private static let horizontalGap: CGFloat = 4      // Gap between selection and tooltip
    private static let screenEdgePadding: CGFloat = 8  // Minimum distance from screen edges
    
    // MARK: - Show / Hide

    func show(near cursorRect: CGRect) {
        showInternal(near: cursorRect, state: .collapsed, size: Self.defaultSize)
    }
    
    /// Show mini icon positioned at the LEFT edge of the selection
    func showMiniIcon(for selection: SelectionResult) {
        let size = NSSize(width: Self.miniIconSize, height: Self.miniIconSize)
        showAtSelectionStart(selection: selection, state: .miniIcon, size: size)
        startAutoHideTimer(delay: AppConstants.miniIconAutoHideDelay)
    }
    
    /// Legacy method for compatibility - uses cursor rect
    func showMiniIcon(near cursorRect: CGRect) {
        let size = NSSize(width: Self.miniIconSize, height: Self.miniIconSize)
        showInternal(near: cursorRect, state: .miniIcon, size: size, offsetRight: true)
        startAutoHideTimer(delay: AppConstants.miniIconAutoHideDelay)
    }
    
    func showNoSelection(near cursorRect: CGRect) {
        showInternal(near: cursorRect, state: .noSelection, size: Self.noSelectionSize)
        startAutoHideTimer(delay: AppConstants.noSelectionAutoHideDelay)
    }
    
    /// Show collapsed tooltip positioned at the LEFT edge of the selection
    func showCollapsed(for selection: SelectionResult) {
        showAtSelectionStart(selection: selection, state: .collapsed, size: Self.defaultSize)
    }
    
    // MARK: - Smart Positioning (at LEFT edge of selection)
    
    /// Positions the tooltip at the START (left edge) of the text selection
    /// with intelligent edge handling and flip logic
    private func showAtSelectionStart(selection: SelectionResult, state: TooltipState, size: NSSize) {
        cancelAutoHideTimer()
        
        NSLog("🎯 showAtSelectionStart: hasPreciseBounds=%d, selectionStart=(%0.f, %0.f), firstLineBounds=(%0.f, %0.f, %0.f, %0.f)",
              selection.hasPreciseBounds ? 1 : 0,
              selection.selectionStartPoint.x, selection.selectionStartPoint.y,
              selection.firstLineBounds.origin.x, selection.firstLineBounds.origin.y,
              selection.firstLineBounds.width, selection.firstLineBounds.height)
        
        // CRITICAL: If we don't have precise bounds (AX API failed for Electron/browser),
        // fall back to selection START position (where user began selecting)
        guard selection.hasPreciseBounds else {
            NSLog("⚠️ Using selection START position for fallback at (%0.f, %0.f)", selection.selectionStartPoint.x, selection.selectionStartPoint.y)
            let fallbackRect = CGRect(
                x: selection.selectionStartPoint.x,
                y: selection.selectionStartPoint.y,
                width: 1,
                height: selection.lineHeight
            )
            showInternal(near: fallbackRect, state: state, size: size, offsetRight: true)
            return
        }
        
        let anchorPoint = selection.tooltipAnchorPoint
        let lineHeight = selection.lineHeight
        let selectionBounds = selection.firstLineBounds
        
        // Find the screen containing the selection
        let screen = NSScreen.screens.first { $0.frame.contains(anchorPoint) } ?? NSScreen.main!
        let visibleFrame = screen.visibleFrame
        
        // Calculate origin: position to the LEFT of selection start, vertically centered
        var origin = calculateLeftEdgePosition(
            anchorPoint: anchorPoint,
            lineHeight: lineHeight,
            tooltipSize: size,
            visibleFrame: visibleFrame
        )
        
        // Check if tooltip overflows left edge - if so, flip to RIGHT side
        if origin.x < visibleFrame.minX + Self.screenEdgePadding {
            origin = calculateRightEdgePosition(
                selectionBounds: selectionBounds,
                lineHeight: lineHeight,
                tooltipSize: size,
                visibleFrame: visibleFrame
            )
            Logger.tooltip.info("Flipped tooltip to right side due to left overflow")
        }
        
        // Handle vertical overflow
        origin = handleVerticalOverflow(origin: origin, size: size, visibleFrame: visibleFrame)
        
        // Ensure horizontal bounds
        origin.x = max(visibleFrame.minX + Self.screenEdgePadding,
                       min(origin.x, visibleFrame.maxX - size.width - Self.screenEdgePadding))
        
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        
        switch state {
        case .miniIcon:
            buildMiniIconUI(size: size)
        case .collapsed:
            buildCollapsedUI(size: size)
        default:
            break
        }
        
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }
        
        addEventMonitors()
        Logger.tooltip.info("Tooltip shown at (\(origin.x), \(origin.y)) state: \(String(describing: state)), hasPreciseBounds: true")
    }
    
    /// Calculate position for tooltip to appear at LEFT of selection
    private func calculateLeftEdgePosition(
        anchorPoint: CGPoint,
        lineHeight: CGFloat,
        tooltipSize: NSSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        // Position tooltip to the LEFT of the anchor point
        // X: tooltip's right edge aligns with selection's left edge (minus gap)
        // Y: vertically centered with the text line
        return CGPoint(
            x: anchorPoint.x - tooltipSize.width - Self.horizontalGap,
            y: anchorPoint.y - tooltipSize.height / 2
        )
    }
    
    /// Calculate position for tooltip to appear at RIGHT of selection (fallback)
    private func calculateRightEdgePosition(
        selectionBounds: CGRect,
        lineHeight: CGFloat,
        tooltipSize: NSSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        // Position tooltip to the RIGHT of the selection
        // X: tooltip's left edge aligns with selection's right edge (plus gap)
        // Y: vertically centered with the text line
        return CGPoint(
            x: selectionBounds.maxX + Self.horizontalGap,
            y: selectionBounds.midY - tooltipSize.height / 2
        )
    }
    
    /// Handle vertical overflow by adjusting Y position
    private func handleVerticalOverflow(origin: CGPoint, size: NSSize, visibleFrame: CGRect) -> CGPoint {
        var adjustedOrigin = origin
        
        // Check top overflow
        if adjustedOrigin.y + size.height > visibleFrame.maxY - Self.screenEdgePadding {
            adjustedOrigin.y = visibleFrame.maxY - size.height - Self.screenEdgePadding
        }
        
        // Check bottom overflow
        if adjustedOrigin.y < visibleFrame.minY + Self.screenEdgePadding {
            adjustedOrigin.y = visibleFrame.minY + Self.screenEdgePadding
        }
        
        return adjustedOrigin
    }
    
    /// Legacy positioning method (for backward compatibility)
    private func showInternal(near cursorRect: CGRect, state: TooltipState, size: NSSize, offsetRight: Bool = false) {
        cancelAutoHideTimer()
        
        let cursorPoint = NSPoint(x: cursorRect.midX, y: cursorRect.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(cursorPoint) } ?? NSScreen.main!
        let visibleFrame = screen.visibleFrame

        var origin: CGPoint
        if offsetRight {
            // Position to the right of cursor (legacy mini icon behavior)
            origin = CGPoint(
                x: cursorPoint.x + 20,
                y: cursorPoint.y - size.height / 2
            )
        } else {
            // Center above cursor
            origin = CGPoint(
                x: cursorPoint.x - size.width / 2,
                y: cursorPoint.y + 16
            )
        }

        origin.x = max(visibleFrame.minX + Self.screenEdgePadding,
                       min(origin.x, visibleFrame.maxX - size.width - Self.screenEdgePadding))

        origin = handleVerticalOverflow(origin: origin, size: size, visibleFrame: visibleFrame)

        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        
        switch state {
        case .miniIcon:
            buildMiniIconUI(size: size)
        case .noSelection:
            buildNoSelectionUI(size: size)
        case .collapsed:
            buildCollapsedUI(size: size)
        default:
            break
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }

        addEventMonitors()
        Logger.tooltip.info("Tooltip shown at (\(origin.x), \(origin.y)) state: \(String(describing: state))")
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
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { [weak self] in
                self?.panel.orderOut(nil)
            }
        }
        Logger.tooltip.info("Tooltip hidden")
    }

    var isVisible: Bool { panel.isVisible }
    var windowFrame: NSRect { panel.frame }

    var isInteracting: Bool {
        switch currentState {
        case .loading, .result, .error, .collapsed: return true
        case .miniIcon, .noSelection: return false
        }
    }
    
    var isMiniIcon: Bool {
        if case .miniIcon = currentState { return true }
        return false
    }

    // MARK: - Public state updater (called from AppDelegate)

    func updateUI(_ state: TooltipState) {
        cancelAutoHideTimer()
        currentState = state
        switch state {
        case .miniIcon:
            panel.isMovableByWindowBackground = false
            let size = NSSize(width: Self.miniIconSize, height: Self.miniIconSize)
            buildMiniIconUI(size: size)
            resizeAndReanchor(to: size, hasTail: false)
            startAutoHideTimer(delay: AppConstants.miniIconAutoHideDelay)
        case .noSelection:
            panel.isMovableByWindowBackground = false
            buildNoSelectionUI(size: Self.noSelectionSize)
            resizeAndReanchor(to: Self.noSelectionSize, hasTail: false)
            startAutoHideTimer(delay: AppConstants.noSelectionAutoHideDelay)
        case .collapsed:
            panel.isMovableByWindowBackground = false
            buildCollapsedUI(size: Self.defaultSize)
            resizeAndReanchor(to: Self.defaultSize)
        case .loading:
            panel.isMovableByWindowBackground = false
            buildLoadingUI()
            resizeAndReanchor(to: Self.loadingSize)
        case .result(let text):
            rewrittenText = text
            let height = resultCardHeight(for: text)
            buildResultUI(text: text, height: height)
            resizeAndReanchor(to: NSSize(width: Self.resultWidth, height: height), hasTail: false)
            panel.isMovableByWindowBackground = true
        case .error(let message):
            let height: CGFloat = 100
            buildErrorUI(message: message)
            resizeAndReanchor(to: NSSize(width: Self.errorWidth, height: height), hasTail: false)
            panel.isMovableByWindowBackground = true
        }
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

    // MARK: - Collapsed State

    private func buildCollapsedUI(size: NSSize) {
        currentState = .collapsed
        clearContainer()

        let bubble = BubbleContainerView(frame: NSRect(origin: .zero, size: size))
        bubble.bubbleColor = Self.darkBubbleBG
        bubble.autoresizingMask = [.width, .height]
        containerView.addSubview(bubble)

        // Inner horizontal stack (sits in bubble body, above tail)
        let th = Self.tailHeight
        let innerFrame = NSRect(x: 0, y: th, width: size.width, height: size.height - th)

        let icon = makeAvatarImageView(size: 26)
        icon.frame = NSRect(x: 14, y: (innerFrame.height - 26) / 2 + th, width: 26, height: 26)
        containerView.addSubview(icon)

        let label = makeLabel("Rephrase with Tone Studio", size: 13, weight: .medium, color: Self.primaryText)
        let labelX: CGFloat = 14 + 26 + 10
        let labelW = size.width - labelX - 14
        label.frame = NSRect(x: labelX, y: (innerFrame.height - 17) / 2 + th, width: labelW, height: 17)
        containerView.addSubview(label)

        // Make the entire bubble tappable
        let clickArea = ClickThroughButton(frame: NSRect(origin: .zero, size: size))
        clickArea.target = self
        clickArea.action = #selector(rephraseTapped)
        clickArea.isBordered = false
        clickArea.bezelStyle = .shadowlessSquare
        containerView.addSubview(clickArea)
    }

    // MARK: - Loading State

    private func buildLoadingUI() {
        currentState = .loading
        clearContainer()
        let size = Self.loadingSize

        let bubble = BubbleContainerView(frame: NSRect(origin: .zero, size: size))
        bubble.bubbleColor = Self.darkBubbleBG
        bubble.autoresizingMask = [.width, .height]
        containerView.addSubview(bubble)

        let th = Self.tailHeight
        let innerH = size.height - th

        let spinner = NSProgressIndicator(frame: NSRect(x: 14, y: (innerH - 18) / 2 + th, width: 18, height: 18))
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.appearance = NSAppearance(named: .vibrantDark)
        spinner.startAnimation(nil)
        containerView.addSubview(spinner)

        let label = makeLabel("Generating...", size: 13, weight: .regular, color: Self.secondaryText)
        let labelX: CGFloat = 14 + 18 + 10
        let labelW = size.width - labelX - 14
        label.frame = NSRect(x: labelX, y: (innerH - 17) / 2 + th, width: labelW, height: 17)
        containerView.addSubview(label)
    }

    // MARK: - Result State

    private func buildResultUI(text: String, height: CGFloat) {
        currentState = .result(text)
        clearContainer()
        let width = Self.resultWidth

        // Card background (no tail)
        let cardLayer = CALayer()
        cardLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
        cardLayer.backgroundColor = Self.resultCardBG.cgColor
        cardLayer.cornerRadius = 14
        cardLayer.borderColor = Self.resultBorder.cgColor
        cardLayer.borderWidth = 1
        cardLayer.masksToBounds = true
        containerView.layer?.addSublayer(cardLayer)

        let headerH: CGFloat = 48
        let padding: CGFloat = 14

        // Header: icon
        let icon = makeAvatarImageView(size: 26)
        icon.frame = NSRect(x: padding, y: height - headerH + (headerH - 26) / 2, width: 26, height: 26)
        containerView.addSubview(icon)

        // Header: title
        let title = makeLabel("Tone Studio", size: 14, weight: .semibold, color: Self.primaryText)
        title.frame = NSRect(x: padding + 26 + 10, y: height - headerH + (headerH - 18) / 2, width: 160, height: 18)
        containerView.addSubview(title)

        // Header action buttons (right side): Refresh, Copy, Close
        let refreshBtn = makeIconButton(symbolName: "arrow.clockwise", action: #selector(retryTapped))
        let copyBtn    = makeIconButton(symbolName: "doc.on.doc",       action: #selector(copyTapped))
        let closeBtn   = makeIconButton(symbolName: "xmark",            action: #selector(cancelTapped))

        let btnSize: CGFloat = 28
        let btnY = height - headerH + (headerH - btnSize) / 2
        closeBtn.frame   = NSRect(x: width - padding - btnSize, y: btnY, width: btnSize, height: btnSize)
        copyBtn.frame    = NSRect(x: width - padding - btnSize * 2 - 6, y: btnY, width: btnSize, height: btnSize)
        refreshBtn.frame = NSRect(x: width - padding - btnSize * 3 - 12, y: btnY, width: btnSize, height: btnSize)
        containerView.addSubview(refreshBtn)
        containerView.addSubview(copyBtn)
        containerView.addSubview(closeBtn)

        // Content area background (slightly different shade)
        let contentY: CGFloat = 12
        let contentH = height - headerH - 14 - contentY
        let contentBG = NSView(frame: NSRect(x: padding, y: contentY, width: width - padding * 2, height: contentH))
        contentBG.wantsLayer = true
        contentBG.layer?.backgroundColor = Self.contentBG.cgColor
        contentBG.layer?.cornerRadius = 8
        containerView.addSubview(contentBG)

        // Text view inside content area
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width - padding * 2, height: contentH))
        textView.isEditable = false
        textView.isSelectable = true
        textView.string = text
        textView.font = .systemFont(ofSize: 13)
        textView.textColor = NSColor(white: 0.85, alpha: 1)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineBreakMode = .byWordWrapping

        let scrollView = NSScrollView(frame: NSRect(x: padding, y: contentY, width: width - padding * 2, height: contentH))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        containerView.addSubview(scrollView)
    }

    // MARK: - Error State

    private func buildErrorUI(message: String) {
        currentState = .error(message)
        clearContainer()
        let width = Self.errorWidth
        let height: CGFloat = 100

        let cardLayer = CALayer()
        cardLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
        cardLayer.backgroundColor = Self.resultCardBG.cgColor
        cardLayer.cornerRadius = 14
        cardLayer.borderColor = NSColor.systemRed.withAlphaComponent(0.4).cgColor
        cardLayer.borderWidth = 1
        containerView.layer?.addSublayer(cardLayer)

        let padding: CGFloat = 14
        let errorIcon = makeLabel("⚠️", size: 14, weight: .regular, color: .white)
        errorIcon.frame = NSRect(x: padding, y: height - 40, width: 22, height: 22)
        containerView.addSubview(errorIcon)

        let msgLabel = makeLabel(message, size: 12, weight: .regular, color: NSColor(white: 0.75, alpha: 1))
        msgLabel.frame = NSRect(x: padding + 26, y: height - 38, width: width - padding * 2 - 26, height: 36)
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
    }

    private func resultCardHeight(for text: String) -> CGFloat {
        let textWidth = Self.resultWidth - 28 - 16 // padding * 2 - textInset
        let attr = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 13)])
        let textRect = attr.boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let textH = min(max(ceil(textRect.height) + 16, 60), 180)
        return 48 + 14 + textH + 12 // header + divider gap + content + bottom padding
    }

    /// Resize panel and keep top-left corner anchored (panel grows downward)
    private func resizeAndReanchor(to size: NSSize, hasTail: Bool = true) {
        var frame = panel.frame
        let topLeft = CGPoint(x: frame.minX, y: frame.maxY)
        frame.size = size
        frame.origin = CGPoint(x: topLeft.x, y: topLeft.y - size.height)
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
            case .result, .error:
                break
            case .miniIcon, .noSelection:
                let mouseLoc = NSEvent.mouseLocation
                if !self.panel.frame.contains(mouseLoc) {
                    self.hide()
                }
            case .collapsed, .loading:
                let mouseLoc = NSEvent.mouseLocation
                if !self.panel.frame.contains(mouseLoc) {
                    self.hide()
                    self.onCancel?()
                }
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
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

    // MARK: - Button actions

    @objc private func rephraseTapped() { onRephrase?() }
    @objc private func copyTapped()     { onCopy?(rewrittenText) }
    @objc private func cancelTapped()   { hide(); onCancel?() }
    @objc private func retryTapped()    { onRetry?() }
    
    @objc private func miniIconTapped() {
        cancelAutoHideTimer()
        updateUI(.collapsed)
    }
}

// MARK: - Invisible click-through button overlay

/// Transparent NSButton that captures clicks over the full bubble area
private final class ClickThroughButton: NSButton {
    override func draw(_ dirtyRect: NSRect) { /* transparent */ }
}
