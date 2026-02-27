import SwiftUI
import MarkdownUI
import AppKit

struct MarkdownResponseView: View {
    let content: String
    let maxWidth: CGFloat
    
    var body: some View {
        Markdown(content)
            .markdownTheme(.toneStudio)
            .textSelection(.enabled)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension Theme {
    static let toneStudio = Theme()
        .text {
            ForegroundColor(.white)
            FontSize(14)
        }
        .heading1 { configuration in
            configuration.label
                .markdownMargin(top: 16, bottom: 8)
                .markdownTextStyle {
                    FontSize(22)
                    FontWeight(.bold)
                    ForegroundColor(.white)
                }
        }
        .heading2 { configuration in
            configuration.label
                .markdownMargin(top: 14, bottom: 6)
                .markdownTextStyle {
                    FontSize(18)
                    FontWeight(.semibold)
                    ForegroundColor(.white)
                }
        }
        .heading3 { configuration in
            configuration.label
                .markdownMargin(top: 12, bottom: 4)
                .markdownTextStyle {
                    FontSize(16)
                    FontWeight(.semibold)
                    ForegroundColor(.white)
                }
        }
        .heading4 { configuration in
            configuration.label
                .markdownMargin(top: 10, bottom: 4)
                .markdownTextStyle {
                    FontSize(14)
                    FontWeight(.semibold)
                    ForegroundColor(.white)
                }
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
            FontSize(13)
            ForegroundColor(Color(red: 0.9, green: 0.6, blue: 0.4))
            BackgroundColor(Color.white.opacity(0.08))
        }
        .codeBlock { configuration in
            ToneStudioCodeBlockView(configuration: configuration)
        }
        .blockquote { configuration in
            configuration.label
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 3)
                }
                .markdownMargin(top: 8, bottom: 8)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 2, bottom: 2)
        }
        .paragraph { configuration in
            configuration.label
                .markdownMargin(top: 0, bottom: 8)
        }
        .table { configuration in
            configuration.label
                .markdownMargin(top: 8, bottom: 8)
                .markdownTableBorderStyle(.init(color: .white.opacity(0.2), width: 1))
                .markdownTableBackgroundStyle(
                    .alternatingRows(Color.white.opacity(0.05), Color.clear)
                )
        }
        .tableCell { configuration in
            configuration.label
                .padding(8)
        }
        .thematicBreak {
            Divider()
                .overlay(Color.white.opacity(0.2))
                .markdownMargin(top: 12, bottom: 12)
        }
        .taskListMarker { configuration in
            Image(systemName: configuration.isCompleted ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isCompleted ? .green : .white.opacity(0.5))
                .font(.system(size: 14))
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
    private var hostingController: NSHostingController<AnyView>?
    private var content: String = ""
    private var maxWidth: CGFloat = 400
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var calculatedHeight: CGFloat {
        guard let hostingController else { return 0 }
        let fittingSize = hostingController.view.fittingSize
        return max(fittingSize.height, 20)
    }
    
    func configure(content: String, maxWidth: CGFloat) {
        self.content = content
        self.maxWidth = maxWidth
        
        hostingController?.view.removeFromSuperview()
        hostingController = nil
        
        let swiftUIView = MarkdownResponseView(content: content, maxWidth: maxWidth)
            .environment(\.colorScheme, .dark)
        
        let controller = NSHostingController(rootView: AnyView(swiftUIView))
        
        if #available(macOS 13.0, *) {
            controller.sizingOptions = [.intrinsicContentSize]
        }
        
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor
        
        addSubview(controller.view)
        
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        self.hostingController = controller
        
        controller.view.needsLayout = true
        controller.view.layoutSubtreeIfNeeded()
        needsLayout = true
        layoutSubtreeIfNeeded()
    }
    
    override var intrinsicContentSize: NSSize {
        guard let hostingController else {
            return NSSize(width: maxWidth, height: NSView.noIntrinsicMetric)
        }
        return hostingController.view.fittingSize
    }
    
    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        hostingController?.view.invalidateIntrinsicContentSize()
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
