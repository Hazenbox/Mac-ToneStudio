import Cocoa
import OSLog

enum TooltipState {
    case collapsed
    case loading
    case result(String)
    case error(String)
}

@MainActor
final class TooltipWindow {

    var onRephrase: (() -> Void)?
    var onReplace: ((String) -> Void)?
    var onCopy: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onRetry: (() -> Void)?

    private let panel: NSPanel
    private let effectView: NSVisualEffectView
    private let contentStack: NSStackView

    private var rephraseButton: NSButton!
    private var spinner: NSProgressIndicator!
    private var statusLabel: NSTextField!
    private var resultTextView: NSScrollView!
    private var resultTextField: NSTextView!
    private var actionStack: NSStackView!

    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?

    private var currentState: TooltipState = .collapsed
    private var rewrittenText: String = ""

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 140, height: 40),
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

        effectView = NSVisualEffectView()
        effectView.material = .popover
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 10
        effectView.layer?.masksToBounds = true

        contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.spacing = 8
        contentStack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        effectView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: effectView.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
        ])

        panel.contentView = effectView

        buildUI()
        updateUI(.collapsed)
    }

    // MARK: - Build UI elements

    private func buildUI() {
        rephraseButton = NSButton(title: "✨ Rephrase", target: self, action: #selector(rephraseTapped))
        rephraseButton.bezelStyle = .accessoryBarAction
        rephraseButton.controlSize = .regular
        rephraseButton.font = .systemFont(ofSize: 13, weight: .medium)

        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true

        statusLabel = NSTextField(labelWithString: "Rephrasing...")
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor

        let resultTV = NSTextView()
        resultTV.isEditable = false
        resultTV.isSelectable = true
        resultTV.font = .systemFont(ofSize: 13)
        resultTV.textColor = .labelColor
        resultTV.backgroundColor = .clear
        resultTV.isVerticallyResizable = true
        resultTV.isHorizontallyResizable = false
        resultTV.textContainer?.widthTracksTextView = true
        resultTV.textContainer?.lineBreakMode = .byWordWrapping
        resultTextField = resultTV

        let scrollView = NSScrollView()
        scrollView.documentView = resultTV
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        resultTextView = scrollView

        let replaceBtn = NSButton(title: "Replace", target: self, action: #selector(replaceTapped))
        replaceBtn.bezelStyle = .accessoryBarAction
        replaceBtn.controlSize = .small

        let copyBtn = NSButton(title: "Copy", target: self, action: #selector(copyTapped))
        copyBtn.bezelStyle = .accessoryBarAction
        copyBtn.controlSize = .small

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelBtn.bezelStyle = .accessoryBarAction
        cancelBtn.controlSize = .small

        actionStack = NSStackView(views: [replaceBtn, copyBtn, cancelBtn])
        actionStack.orientation = .horizontal
        actionStack.spacing = 6
    }

    // MARK: - State management

    func updateUI(_ state: TooltipState) {
        currentState = state

        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        switch state {
        case .collapsed:
            contentStack.addArrangedSubview(rephraseButton)
            resizePanel(width: 140, height: 40)

        case .loading:
            spinner.startAnimation(nil)
            let loadingStack = NSStackView(views: [spinner, statusLabel])
            loadingStack.orientation = .horizontal
            loadingStack.spacing = 8
            statusLabel.stringValue = "Rephrasing..."
            contentStack.addArrangedSubview(loadingStack)
            resizePanel(width: 220, height: 44)

        case .result(let text):
            rewrittenText = text
            spinner.stopAnimation(nil)
            resultTextField.string = text

            let textHeight = min(max(heightForText(text, width: 260), 30), 150)
            resultTextView.heightAnchor.constraint(equalToConstant: textHeight).isActive = true

            contentStack.addArrangedSubview(resultTextView)
            contentStack.addArrangedSubview(actionStack)
            resizePanel(width: 300, height: textHeight + 56)

        case .error(let message):
            spinner.stopAnimation(nil)
            statusLabel.stringValue = message
            statusLabel.textColor = .systemRed

            let retryBtn = NSButton(title: "Retry", target: self, action: #selector(retryTapped))
            retryBtn.bezelStyle = .accessoryBarAction
            retryBtn.controlSize = .small

            let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
            cancelBtn.bezelStyle = .accessoryBarAction
            cancelBtn.controlSize = .small

            let errorActions = NSStackView(views: [retryBtn, cancelBtn])
            errorActions.orientation = .horizontal
            errorActions.spacing = 6

            contentStack.addArrangedSubview(statusLabel)
            contentStack.addArrangedSubview(errorActions)
            resizePanel(width: 280, height: 64)
        }
    }

    // MARK: - Show / Hide

    func show(near selectionRect: CGRect) {
        updateUI(.collapsed)

        let panelSize = panel.frame.size
        var origin = CGPoint(
            x: selectionRect.midX - panelSize.width / 2,
            y: selectionRect.minY - panelSize.height - 4
        )

        let screen = NSScreen.screens.first { $0.visibleFrame.contains(origin) } ?? NSScreen.main!
        let visibleFrame = screen.visibleFrame

        origin.x = max(visibleFrame.minX + 4, min(origin.x, visibleFrame.maxX - panelSize.width - 4))

        if origin.y < visibleFrame.minY {
            origin.y = selectionRect.maxY + 4
        }

        panel.setFrameOrigin(origin)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.animator().alphaValue = 1

        addEventMonitors()
        Logger.tooltip.info("Tooltip shown at (\(origin.x), \(origin.y))")
    }

    func hide() {
        removeEventMonitors()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { [weak self] in
                self?.panel.orderOut(nil)
                self?.statusLabel.textColor = .secondaryLabelColor
            }
        }
        Logger.tooltip.info("Tooltip hidden")
    }

    var isVisible: Bool {
        panel.isVisible
    }

    // MARK: - Panel resizing

    private func resizePanel(width: CGFloat, height: CGFloat) {
        var frame = panel.frame
        let oldHeight = frame.height
        frame.size = NSSize(width: width, height: height)
        frame.origin.y -= (height - oldHeight)
        panel.animator().setFrame(frame, display: true)
    }

    // MARK: - Text height estimation

    private func heightForText(_ text: String, width: CGFloat) -> CGFloat {
        let attr = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 13)])
        let rect = attr.boundingRect(with: NSSize(width: width - 24, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading])
        return ceil(rect.height) + 8
    }

    // MARK: - Event monitors (click outside + Escape)

    private func addEventMonitors() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.panel.isVisible else { return }
            let clickLocation = event.locationInWindow
            if !self.panel.frame.contains(clickLocation) {
                self.hide()
                self.onCancel?()
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
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }

    // MARK: - Button actions

    @objc private func rephraseTapped() {
        onRephrase?()
    }

    @objc private func replaceTapped() {
        onReplace?(rewrittenText)
    }

    @objc private func copyTapped() {
        onCopy?(rewrittenText)
    }

    @objc private func cancelTapped() {
        hide()
        onCancel?()
    }

    @objc private func retryTapped() {
        onRetry?()
    }
}
