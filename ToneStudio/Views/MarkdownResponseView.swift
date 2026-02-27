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
        print("[MARKDOWN DEBUG] MarkdownResponseView init - content length: \(content.count), maxWidth: \(maxWidth)")
        print("[MARKDOWN DEBUG] Content preview: \(String(content.prefix(300)))")
    }
    
    var body: some View {
        // Try basic Markdown without custom theme first to isolate theme issues
        Markdown(content)
            .markdownTheme(.gitHub)  // Use built-in theme to isolate issue
            .textSelection(.enabled)
            .preferredColorScheme(.dark)
            .background(Color.red.opacity(0.3))  // DEBUG: Should see red tint if SwiftUI renders
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
        print("[MARKDOWN DEBUG] configure() called - content length: \(content.count), maxWidth: \(maxWidth)")
        print("[MARKDOWN DEBUG] configure() - window: \(String(describing: self.window)), bounds: \(self.bounds)")
        print("[MARKDOWN DEBUG] Content debugDescription: \(content.debugDescription)")
        
        // Print first 50 bytes to check for invisible characters
        let bytes = Array(content.utf8.prefix(100))
        print("[MARKDOWN DEBUG] First 100 content bytes: \(bytes)")
        
        // Check for triple backticks
        if content.contains("```") {
            print("[MARKDOWN DEBUG] Content CONTAINS triple backticks")
        } else {
            print("[MARKDOWN DEBUG] WARNING: Content does NOT contain triple backticks!")
        }
        
        self.currentContent = content
        self.currentMaxWidth = maxWidth
        
        // Always create hosting controller immediately - don't wait for window
        // The SwiftUI content can render even before being in window hierarchy
        print("[MARKDOWN DEBUG] configure() - creating hosting controller immediately (window: \(window != nil))")
        createOrUpdateHostingController()
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        print("[MARKDOWN DEBUG] viewDidMoveToWindow() - window: \(String(describing: self.window)), bounds: \(self.bounds)")
        print("[MARKDOWN DEBUG] viewDidMoveToWindow() - currentContent.isEmpty: \(currentContent.isEmpty), isConfigured: \(isConfigured)")
        
        if window != nil && !currentContent.isEmpty && !isConfigured {
            print("[MARKDOWN DEBUG] viewDidMoveToWindow() - creating hosting controller for deferred content")
            createOrUpdateHostingController()
        } else {
            print("[MARKDOWN DEBUG] viewDidMoveToWindow() - NOT creating controller (window=\(window != nil), content=\(!currentContent.isEmpty), configured=\(!isConfigured))")
        }
    }
    
    private func createOrUpdateHostingController() {
        print("[MARKDOWN DEBUG] createOrUpdateHostingController() - bounds: \(self.bounds), frame: \(self.frame)")
        
        // Allow zero bounds initially - the view will be laid out later
        if bounds.width == 0 || bounds.height == 0 {
            print("[MARKDOWN DEBUG] Note: Zero bounds, using frame instead")
        }
        
        // Use frame if bounds is zero (frame was set in init)
        let effectiveBounds = bounds.width > 0 ? bounds : frame
        print("[MARKDOWN DEBUG] Using effectiveBounds: \(effectiveBounds)")
        
        // DEBUG: Test with hardcoded content to isolate issue
        let useHardcodedContent = false  // Set to false to use actual content
        let testContent = """
        # Test Heading
        
        This is **bold** and *italic* text.
        
        ```python
        def hello():
            print("Hello World")
        ```
        
        Normal text after code block.
        """
        
        let contentToUse = useHardcodedContent ? testContent : currentContent
        print("[MARKDOWN DEBUG] Using \(useHardcodedContent ? "HARDCODED" : "ACTUAL") content")
        
        let swiftUIView = MarkdownResponseView(content: contentToUse, maxWidth: currentMaxWidth)
        
        if let existing = hostingController {
            print("[MARKDOWN DEBUG] createOrUpdateHostingController() - updating existing controller")
            existing.rootView = swiftUIView
            existing.view.needsLayout = true
            existing.view.layoutSubtreeIfNeeded()
        } else {
            print("[MARKDOWN DEBUG] createOrUpdateHostingController() - creating NEW controller")
            
            let controller = NSHostingController(rootView: swiftUIView)
            
            if #available(macOS 13.0, *) {
                controller.sizingOptions = [.intrinsicContentSize]
            }
            
            controller.view.translatesAutoresizingMaskIntoConstraints = true
            controller.view.frame = effectiveBounds
            controller.view.autoresizingMask = [.width, .height]
            controller.view.wantsLayer = true
            controller.view.layer?.backgroundColor = NSColor.clear.cgColor
            
            addSubview(controller.view)
            self.hostingController = controller
            
            print("[MARKDOWN DEBUG] createOrUpdateHostingController() - controller added, frame: \(controller.view.frame)")
        }
        
        isConfigured = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let controller = self.hostingController else { return }
            controller.view.frame = self.bounds
            controller.view.needsLayout = true
            controller.view.layoutSubtreeIfNeeded()
            controller.view.needsDisplay = true
            self.needsDisplay = true
            print("[MARKDOWN DEBUG] createOrUpdateHostingController() - async layout complete, frame: \(controller.view.frame)")
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
