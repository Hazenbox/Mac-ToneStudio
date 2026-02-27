import WebKit
import Down
import OSLog

private let logger = Logger(subsystem: "com.upendranath.ToneStudio", category: "MarkdownWebView")

final class MarkdownWebView: NSView {
    private var webView: WKWebView!
    private var onHeightChange: ((CGFloat) -> Void)?
    private var currentHeight: CGFloat = 50
    
    private static var cachedTemplateHTML: String?
    private static let resourceSubdirectory = "Resources/Markdown"
    
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
        
        let fullHTML = buildFullHTML(body: htmlBody)
        
        let baseURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Markdown")
        
        webView.loadHTMLString(fullHTML, baseURL: baseURL)
    }
    
    private func buildFullHTML(body: String) -> String {
        if let cached = Self.cachedTemplateHTML {
            return cached.replacingOccurrences(of: "{{CONTENT}}", with: body)
        }
        
        if let templateURL = Bundle.main.url(forResource: "template", withExtension: "html", subdirectory: "Resources/Markdown"),
           let template = try? String(contentsOf: templateURL, encoding: .utf8) {
            Self.cachedTemplateHTML = template
            return template.replacingOccurrences(of: "{{CONTENT}}", with: body)
        }
        
        logger.warning("Template not found, using inline fallback HTML")
        return buildFallbackHTML(body: body)
    }
    
    private func buildFallbackHTML(body: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <style>
                :root { color-scheme: dark; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
                    font-size: 14px;
                    line-height: 1.5;
                    color: rgba(255, 255, 255, 0.95);
                    background: transparent;
                    margin: 0;
                    padding: 0;
                    -webkit-font-smoothing: antialiased;
                }
                h1, h2, h3, h4 { color: white; font-weight: 600; margin-top: 16px; margin-bottom: 8px; }
                h1 { font-size: 1.6em; }
                h2 { font-size: 1.3em; }
                h3 { font-size: 1.1em; }
                p { margin: 0 0 12px 0; }
                a { color: #58a6ff; text-decoration: none; }
                a:hover { text-decoration: underline; }
                strong { font-weight: 600; }
                code:not(pre code) {
                    font-family: "SF Mono", Monaco, monospace;
                    font-size: 0.88em;
                    background: rgba(255, 255, 255, 0.1);
                    padding: 2px 6px;
                    border-radius: 4px;
                    color: #e6a07c;
                }
                pre {
                    background: #141414;
                    border-radius: 8px;
                    padding: 14px;
                    margin: 12px 0;
                    overflow-x: auto;
                    border: 1px solid rgba(255, 255, 255, 0.08);
                }
                pre code {
                    font-family: "SF Mono", Monaco, monospace;
                    font-size: 13px;
                    line-height: 1.5;
                    background: transparent;
                    padding: 0;
                    color: #e6e6e6;
                }
                ul, ol { margin: 10px 0; padding-left: 24px; }
                li { margin: 6px 0; }
                blockquote {
                    border-left: 3px solid rgba(255, 255, 255, 0.25);
                    margin: 12px 0;
                    padding: 6px 0 6px 16px;
                    color: rgba(255, 255, 255, 0.8);
                }
                table { border-collapse: collapse; width: 100%; margin: 12px 0; }
                th, td { border: 1px solid rgba(255, 255, 255, 0.12); padding: 10px 14px; text-align: left; }
                th { background: rgba(255, 255, 255, 0.06); font-weight: 600; }
                tr:nth-child(even) { background: rgba(255, 255, 255, 0.02); }
                hr { border: none; border-top: 1px solid rgba(255, 255, 255, 0.15); margin: 20px 0; }
            </style>
        </head>
        <body>
            <div id="content">\(body)</div>
            <script>
                setTimeout(function() {
                    var height = document.body.scrollHeight;
                    window.webkit.messageHandlers.heightChanged.postMessage(height);
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
