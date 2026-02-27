import SwiftUI
import MarkdownUI
import AppKit
import OSLog

private let logger = Logger(subsystem: "com.upendranath.ToneStudio", category: "Markdown")

struct MarkdownResponseView: View {
    let content: String
    let maxWidth: CGFloat
    
    init(content: String, maxWidth: CGFloat) {
        self.content = content
        self.maxWidth = maxWidth
        logger.debug("MarkdownResponseView init - content length: \(content.count), maxWidth: \(maxWidth)")
        logger.debug("Content preview: \(String(content.prefix(200)))")
    }
    
    var body: some View {
        Markdown(content)
            .markdownTheme(.toneStudioDark)
            .textSelection(.enabled)
            .environment(\.colorScheme, .dark)
    }
}

extension Theme {
    static let toneStudioDark = Theme()
        .text {
            ForegroundColor(.white)
            FontSize(14)
        }
        .strong {
            FontWeight(.bold)
        }
        .emphasis {
            FontStyle(.italic)
        }
        .link {
            ForegroundColor(Color(nsColor: .systemBlue))
        }
        .strikethrough {
            StrikethroughStyle(.single)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
            ForegroundColor(Color(red: 0.9, green: 0.6, blue: 0.4))
            BackgroundColor(Color.white.opacity(0.08))
        }
        .heading1 { configuration in
            configuration.label
                .relativePadding(.bottom, length: .em(0.3))
                .relativeLineSpacing(.em(0.125))
                .markdownMargin(top: 16, bottom: 12)
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(1.8))
                    ForegroundColor(.white)
                }
        }
        .heading2 { configuration in
            configuration.label
                .relativePadding(.bottom, length: .em(0.3))
                .relativeLineSpacing(.em(0.125))
                .markdownMargin(top: 14, bottom: 10)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.4))
                    ForegroundColor(.white)
                }
        }
        .heading3 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.125))
                .markdownMargin(top: 12, bottom: 8)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.2))
                    ForegroundColor(.white)
                }
        }
        .heading4 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.125))
                .markdownMargin(top: 10, bottom: 6)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    ForegroundColor(.white)
                }
        }
        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.2))
                .markdownMargin(top: 0, bottom: 12)
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.3))
                    .relativeFrame(width: .em(0.2))
                configuration.label
                    .markdownTextStyle { ForegroundColor(.white.opacity(0.8)) }
                    .relativePadding(.horizontal, length: .em(0.8))
            }
            .fixedSize(horizontal: false, vertical: true)
            .markdownMargin(top: 8, bottom: 8)
        }
        .codeBlock { configuration in
            ToneStudioCodeBlockView(configuration: configuration)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.2))
        }
        .taskListMarker { configuration in
            Image(systemName: configuration.isCompleted ? "checkmark.square.fill" : "square")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(configuration.isCompleted ? Color.green : Color.white.opacity(0.5))
                .imageScale(.small)
                .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
        }
        .table { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .markdownTableBorderStyle(.init(color: .white.opacity(0.2), width: 1))
                .markdownTableBackgroundStyle(
                    .alternatingRows(Color.white.opacity(0.03), Color.clear)
                )
                .markdownMargin(top: 8, bottom: 12)
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    if configuration.row == 0 {
                        FontWeight(.semibold)
                    }
                    BackgroundColor(nil)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .relativeLineSpacing(.em(0.2))
        }
        .thematicBreak {
            Divider()
                .relativeFrame(height: .em(0.2))
                .overlay(Color.white.opacity(0.2))
                .markdownMargin(top: 16, bottom: 16)
        }
}

struct ToneStudioCodeBlockView: View {
    let configuration: CodeBlockConfiguration
    
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language = configuration.language, !language.isEmpty {
                HStack {
                    Text(language.uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                    
                    Button(action: copyCode) {
                        HStack(spacing: 4) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                            Text(isCopied ? "Copied" : "Copy")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(13)
                    }
                    .padding(12)
            }
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .markdownMargin(top: 8, bottom: 8)
    }
    
    private func copyCode() {
        let code = configuration.content
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        
        withAnimation {
            isCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}


final class MarkdownHostingView: NSView {
    private var hostingController: NSHostingController<MarkdownResponseView>?
    private var currentContent: String = ""
    private var currentMaxWidth: CGFloat = 400
    private var isConfigured: Bool = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        logger.debug("MarkdownHostingView init with frame: \(frameRect.debugDescription)")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var calculatedHeight: CGFloat {
        guard let hostingController else { 
            logger.debug("calculatedHeight: no hostingController, returning 100")
            return 100 
        }
        hostingController.view.layoutSubtreeIfNeeded()
        let fittingSize = hostingController.view.fittingSize
        logger.debug("calculatedHeight: fittingSize = \(fittingSize.debugDescription)")
        return max(fittingSize.height, 50)
    }
    
    func configure(content: String, maxWidth: CGFloat) {
        logger.debug("configure() called - content length: \(content.count), maxWidth: \(maxWidth)")
        logger.debug("configure() - window: \(String(describing: self.window)), bounds: \(self.bounds.debugDescription)")
        
        self.currentContent = content
        self.currentMaxWidth = maxWidth
        
        if window != nil {
            logger.debug("configure() - view is in window hierarchy, creating hosting controller now")
            createOrUpdateHostingController()
        } else {
            logger.debug("configure() - view NOT in window hierarchy, deferring to viewDidMoveToWindow")
            isConfigured = false
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        logger.debug("viewDidMoveToWindow() - window: \(String(describing: self.window))")
        
        if window != nil && !currentContent.isEmpty && !isConfigured {
            logger.debug("viewDidMoveToWindow() - creating hosting controller for deferred content")
            createOrUpdateHostingController()
        }
    }
    
    private func createOrUpdateHostingController() {
        logger.debug("createOrUpdateHostingController() - bounds: \(self.bounds.debugDescription)")
        
        let swiftUIView = MarkdownResponseView(content: currentContent, maxWidth: currentMaxWidth)
        
        if let existing = hostingController {
            logger.debug("createOrUpdateHostingController() - updating existing controller")
            existing.rootView = swiftUIView
            existing.view.needsLayout = true
            existing.view.layoutSubtreeIfNeeded()
        } else {
            logger.debug("createOrUpdateHostingController() - creating new controller")
            
            let controller = NSHostingController(rootView: swiftUIView)
            
            if #available(macOS 13.0, *) {
                controller.sizingOptions = [.intrinsicContentSize]
            }
            
            controller.view.translatesAutoresizingMaskIntoConstraints = true
            controller.view.frame = bounds
            controller.view.autoresizingMask = [.width, .height]
            controller.view.wantsLayer = true
            controller.view.layer?.backgroundColor = NSColor.clear.cgColor
            
            addSubview(controller.view)
            self.hostingController = controller
            
            logger.debug("createOrUpdateHostingController() - controller added, frame: \(controller.view.frame.debugDescription)")
        }
        
        isConfigured = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let controller = self.hostingController else { return }
            controller.view.frame = self.bounds
            controller.view.needsLayout = true
            controller.view.layoutSubtreeIfNeeded()
            controller.view.needsDisplay = true
            self.needsDisplay = true
            logger.debug("createOrUpdateHostingController() - async layout complete, frame: \(controller.view.frame.debugDescription)")
        }
    }
    
    override func layout() {
        super.layout()
        if let controller = hostingController {
            controller.view.frame = bounds
        }
    }
    
    override var intrinsicContentSize: NSSize {
        guard let hostingController else {
            return NSSize(width: currentMaxWidth, height: NSView.noIntrinsicMetric)
        }
        return hostingController.view.fittingSize
    }
}

#Preview {
    MarkdownResponseView(
        content: """
        # Welcome to ToneStudio
        
        This is a **bold** and *italic* example with `inline code`.
        
        ## Features
        
        - Markdown rendering
        - Syntax highlighting
        - Tables support
        
        ### Code Example
        
        ```swift
        func greet(name: String) -> String {
            return "Hello, \\(name)!"
        }
        ```
        
        > This is a blockquote for important notes.
        
        | Feature | Status |
        |---------|--------|
        | Headings | Done |
        | Lists | Done |
        | Code | Done |
        
        ---
        
        That's all for now!
        """,
        maxWidth: 400
    )
    .padding()
    .background(Color(red: 0.145, green: 0.145, blue: 0.149))
}
