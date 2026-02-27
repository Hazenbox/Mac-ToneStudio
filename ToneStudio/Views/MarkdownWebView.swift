import WebKit
import Down
import OSLog

private let logger = Logger(subsystem: "com.upendranath.ToneStudio", category: "MarkdownWebView")

final class MarkdownWebView: NSView {
    private var webView: WKWebView!
    private var onHeightChange: ((CGFloat) -> Void)?
    private var currentHeight: CGFloat = 50
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupWebView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWebView()
    }
    
    private func setupWebView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        
        let contentController = WKUserContentController()
        contentController.add(HeightMessageHandler(view: self), name: "heightChanged")
        config.userContentController = contentController
        
        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = false
        config.preferences = preferences
        
        webView = WKWebView(frame: bounds, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        
        webView.setValue(false, forKey: "drawsBackground")
        webView.enclosingScrollView?.drawsBackground = false
        webView.enclosingScrollView?.backgroundColor = .clear
        
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(markdown: String, onHeightChange: ((CGFloat) -> Void)? = nil) {
        self.onHeightChange = onHeightChange
        
        logger.debug("Configuring MarkdownWebView with content length: \(markdown.count)")
        
        let down = Down(markdownString: markdown)
        let htmlBody: String
        
        do {
            htmlBody = try down.toHTML([.smart, .unsafe])
            logger.debug("Converted markdown to HTML, length: \(htmlBody.count)")
        } catch {
            logger.error("Failed to convert markdown to HTML: \(error.localizedDescription)")
            let escaped = markdown
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            htmlBody = "<pre style=\"white-space: pre-wrap;\">\(escaped)</pre>"
        }
        
        let fullHTML = buildHTML(body: htmlBody)
        webView.loadHTMLString(fullHTML, baseURL: nil)
    }
    
    private func buildHTML(body: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <style>
                :root {
                    color-scheme: dark;
                }
                
                * {
                    box-sizing: border-box;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
                    font-size: 14px;
                    line-height: 1.55;
                    color: rgba(255, 255, 255, 0.95);
                    background-color: transparent;
                    margin: 0;
                    padding: 0;
                    -webkit-font-smoothing: antialiased;
                    -webkit-text-size-adjust: 100%;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                }
                
                #content {
                    padding: 0;
                }
                
                /* Headings */
                h1, h2, h3, h4, h5, h6 {
                    color: white;
                    font-weight: 600;
                    margin-top: 20px;
                    margin-bottom: 10px;
                    line-height: 1.3;
                }
                
                h1:first-child, h2:first-child, h3:first-child {
                    margin-top: 0;
                }
                
                h1 { font-size: 1.5em; }
                h2 { font-size: 1.3em; }
                h3 { font-size: 1.15em; }
                h4 { font-size: 1.05em; }
                
                /* Paragraphs */
                p {
                    margin: 0 0 12px 0;
                }
                
                p:last-child {
                    margin-bottom: 0;
                }
                
                /* Links */
                a {
                    color: #58a6ff;
                    text-decoration: none;
                }
                
                a:hover {
                    text-decoration: underline;
                }
                
                /* Bold and Italic */
                strong, b {
                    font-weight: 600;
                    color: white;
                }
                
                em, i {
                    font-style: italic;
                }
                
                /* Inline code */
                code:not(pre code) {
                    font-family: "SF Mono", Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
                    font-size: 0.88em;
                    background: rgba(255, 255, 255, 0.12);
                    padding: 2px 6px;
                    border-radius: 4px;
                    color: #e6a07c;
                    white-space: nowrap;
                }
                
                /* Code blocks - CRITICAL */
                pre {
                    background: #141414;
                    border-radius: 8px;
                    padding: 14px 16px;
                    margin: 12px 0;
                    overflow-x: auto;
                    border: 1px solid rgba(255, 255, 255, 0.1);
                    white-space: pre-wrap;
                    word-wrap: break-word;
                }
                
                pre code {
                    font-family: "SF Mono", Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
                    font-size: 13px;
                    line-height: 1.5;
                    background: transparent;
                    padding: 0;
                    border-radius: 0;
                    color: #e6e6e6;
                    white-space: pre-wrap;
                    word-wrap: break-word;
                    display: block;
                }
                
                /* Basic syntax highlighting */
                .keyword { color: #ff7b72; }
                .string { color: #a5d6ff; }
                .comment { color: #8b949e; }
                .number { color: #79c0ff; }
                .function { color: #d2a8ff; }
                
                /* Lists */
                ul, ol {
                    margin: 10px 0;
                    padding-left: 24px;
                }
                
                li {
                    margin: 6px 0;
                    line-height: 1.5;
                }
                
                li > ul, li > ol {
                    margin: 4px 0;
                }
                
                /* Task lists */
                input[type="checkbox"] {
                    margin-right: 8px;
                    accent-color: #58a6ff;
                }
                
                /* Blockquotes */
                blockquote {
                    border-left: 3px solid rgba(255, 255, 255, 0.25);
                    margin: 12px 0;
                    padding: 6px 0 6px 16px;
                    color: rgba(255, 255, 255, 0.8);
                    background: rgba(255, 255, 255, 0.02);
                    border-radius: 0 6px 6px 0;
                }
                
                blockquote p {
                    margin: 0;
                }
                
                /* Tables */
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 12px 0;
                    font-size: 13px;
                    border-radius: 8px;
                    overflow: hidden;
                }
                
                thead {
                    background: rgba(255, 255, 255, 0.06);
                }
                
                th, td {
                    border: 1px solid rgba(255, 255, 255, 0.12);
                    padding: 10px 14px;
                    text-align: left;
                }
                
                th {
                    font-weight: 600;
                    color: white;
                }
                
                tr:nth-child(even) {
                    background: rgba(255, 255, 255, 0.02);
                }
                
                /* Horizontal rule */
                hr {
                    border: none;
                    border-top: 1px solid rgba(255, 255, 255, 0.15);
                    margin: 20px 0;
                }
                
                /* Images */
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 6px;
                }
                
                /* Selection styling */
                ::selection {
                    background: rgba(88, 166, 255, 0.3);
                    color: white;
                }
                
                /* Scrollbar styling */
                ::-webkit-scrollbar {
                    width: 8px;
                    height: 8px;
                }
                
                ::-webkit-scrollbar-track {
                    background: transparent;
                }
                
                ::-webkit-scrollbar-thumb {
                    background: rgba(255, 255, 255, 0.2);
                    border-radius: 4px;
                }
                
                ::-webkit-scrollbar-thumb:hover {
                    background: rgba(255, 255, 255, 0.3);
                }
            </style>
        </head>
        <body>
            <div id="content">\(body)</div>
            <script>
                setTimeout(function() {
                    var height = document.body.scrollHeight;
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.heightChanged) {
                        window.webkit.messageHandlers.heightChanged.postMessage(height);
                    }
                }, 50);
            </script>
        </body>
        </html>
        """
    }
    
    var calculatedHeight: CGFloat {
        return currentHeight
    }
    
    fileprivate func updateHeight(_ height: CGFloat) {
        guard height > 0 else { return }
        currentHeight = height
        onHeightChange?(height)
        logger.debug("WebView height updated to: \(height)")
    }
}

extension MarkdownWebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, error in
            if let height = result as? CGFloat, height > 0 {
                self?.updateHeight(height)
            } else if let height = result as? Double {
                self?.updateHeight(CGFloat(height))
            }
        }
        
        logger.debug("WebView navigation finished")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("WebView navigation failed: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, 
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            logger.debug("Opened external link: \(url.absoluteString)")
        } else {
            decisionHandler(.allow)
        }
    }
}

private class HeightMessageHandler: NSObject, WKScriptMessageHandler {
    weak var view: MarkdownWebView?
    
    init(view: MarkdownWebView) {
        self.view = view
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController, 
                               didReceive message: WKScriptMessage) {
        if message.name == "heightChanged",
           let height = message.body as? CGFloat {
            view?.updateHeight(height)
        } else if message.name == "heightChanged",
                  let height = message.body as? Double {
            view?.updateHeight(CGFloat(height))
        }
    }
}
