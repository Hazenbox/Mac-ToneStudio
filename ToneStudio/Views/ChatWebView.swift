import WebKit
import Down
import OSLog

private let logger = Logger(subsystem: "com.upendranath.ToneStudio", category: "ChatWebView")

protocol ChatWebViewDelegate: AnyObject {
    func chatWebView(_ view: ChatWebView, didClickAction action: String, forMessageAt index: Int)
    func chatWebViewDidClickClearSelectedText(_ view: ChatWebView)
}

final class ChatWebView: NSView {
    private var webView: WKWebView!
    weak var delegate: ChatWebViewDelegate?
    
    private var currentMessages: [(role: String, content: String)] = []
    private var currentSelectedText: String = ""
    private var currentLastAction: String = ""
    private var isLoading: Bool = false
    
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
        let handler = ChatMessageHandler(view: self)
        contentController.add(handler, name: "actionClicked")
        contentController.add(handler, name: "clearSelectedText")
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
        
        loadEmptyState()
    }
    
    private func loadEmptyState() {
        let html = buildFullHTML(messages: [], selectedText: "", lastAction: "", isLoading: false)
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    func updateChat(messages: [(role: String, content: String)], selectedText: String, lastAction: String, isLoading: Bool) {
        self.currentMessages = messages
        self.currentSelectedText = selectedText
        self.currentLastAction = lastAction
        self.isLoading = isLoading
        
        let html = buildFullHTML(messages: messages, selectedText: selectedText, lastAction: lastAction, isLoading: isLoading)
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    func scrollToBottom() {
        webView.evaluateJavaScript("window.scrollTo(0, document.body.scrollHeight);", completionHandler: nil)
    }
    
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        let preprocessed = preprocessMarkdown(markdown)
        let down = Down(markdownString: preprocessed)
        
        do {
            return try down.toHTML([.smart, .unsafe])
        } catch {
            logger.error("Failed to convert markdown: \(error.localizedDescription)")
            let escaped = markdown
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            return "<pre style=\"white-space: pre-wrap;\">\(escaped)</pre>"
        }
    }
    
    private func preprocessMarkdown(_ markdown: String) -> String {
        var result = markdown
        
        if let regex = try? NSRegularExpression(pattern: #"```(\w+)[ \t]*([^\n])"#, options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "```$1\n$2"
            )
        }
        
        if let regex = try? NSRegularExpression(pattern: #"```([^`\w\n])"#, options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "```\n$1"
            )
        }
        
        if let regex = try? NSRegularExpression(pattern: #"([^\n])```"#, options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1\n```"
            )
        }
        
        return result
    }
    
    private func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    fileprivate func handleAction(_ action: String, messageIndex: Int) {
        delegate?.chatWebView(self, didClickAction: action, forMessageAt: messageIndex)
    }
    
    fileprivate func handleClearSelectedText() {
        delegate?.chatWebViewDidClickClearSelectedText(self)
    }
    
    private func buildFullHTML(messages: [(role: String, content: String)], selectedText: String, lastAction: String, isLoading: Bool) -> String {
        var messagesHTML = ""
        
        for (index, message) in messages.enumerated() {
            if message.role == "user" {
                let escapedContent = escapeHTML(message.content)
                messagesHTML += """
                <div class="message user" data-index="\(index)">
                    <div class="bubble">\(escapedContent)</div>
                </div>
                """
            } else if message.role == "assistant" {
                let htmlContent = convertMarkdownToHTML(message.content)
                messagesHTML += """
                <div class="message assistant" data-index="\(index)">
                    <div class="content">\(htmlContent)</div>
                    <div class="actions">
                        <button class="action-btn" data-action="copy" data-index="\(index)" title="Copy">
                            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                                <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
                            </svg>
                        </button>
                        <button class="action-btn" data-action="regenerate" data-index="\(index)" title="Regenerate">
                            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <polyline points="23 4 23 10 17 10"></polyline>
                                <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"></path>
                            </svg>
                        </button>
                        <button class="action-btn" data-action="like" data-index="\(index)" title="Like">
                            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M14 9V5a3 3 0 0 0-3-3l-4 9v11h11.28a2 2 0 0 0 2-1.7l1.38-9a2 2 0 0 0-2-2.3zM7 22H4a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2h3"></path>
                            </svg>
                        </button>
                        <button class="action-btn" data-action="dislike" data-index="\(index)" title="Dislike">
                            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M10 15v4a3 3 0 0 0 3 3l4-9V2H5.72a2 2 0 0 0-2 1.7l-1.38 9a2 2 0 0 0 2 2.3zm7-13h2.67A2.31 2.31 0 0 1 22 4v7a2.31 2.31 0 0 1-2.33 2H17"></path>
                            </svg>
                        </button>
                    </div>
                </div>
                """
            }
        }
        
        let selectedTextHTML: String
        if !selectedText.isEmpty {
            let truncated = selectedText.count > 40 ? String(selectedText.prefix(40)) + "..." : selectedText
            let escapedText = escapeHTML(truncated)
            selectedTextHTML = """
            <div class="selected-text-banner">
                <svg class="doc-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
                    <polyline points="14 2 14 8 20 8"></polyline>
                    <line x1="16" y1="13" x2="8" y2="13"></line>
                    <line x1="16" y1="17" x2="8" y2="17"></line>
                </svg>
                <span class="text">Selected: \(escapedText)</span>
                <button class="close-btn" onclick="clearSelectedText()">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <line x1="18" y1="6" x2="6" y2="18"></line>
                        <line x1="6" y1="6" x2="18" y2="18"></line>
                    </svg>
                </button>
            </div>
            """
        } else {
            selectedTextHTML = ""
        }
        
        let lastActionHTML: String
        if !lastAction.isEmpty && messages.isEmpty {
            let escapedAction = escapeHTML(lastAction)
            lastActionHTML = """
            <div class="action-pill">\(escapedAction)</div>
            """
        } else {
            lastActionHTML = ""
        }
        
        let loadingHTML: String
        if isLoading {
            loadingHTML = """
            <div class="loading-indicator">
                <div class="typing-dots">
                    <span></span>
                    <span></span>
                    <span></span>
                </div>
            </div>
            """
        } else {
            loadingHTML = ""
        }
        
        let emptyStateHTML: String
        if messages.isEmpty && selectedText.isEmpty && lastAction.isEmpty && !isLoading {
            emptyStateHTML = """
            <div class="empty-state">
                Ask me anything, questions, content help, or select text to get started
            </div>
            """
        } else {
            emptyStateHTML = ""
        }
        
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
                    margin: 0;
                    padding: 0;
                }
                
                html, body {
                    height: 100%;
                    overflow-x: hidden;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
                    font-size: 14px;
                    line-height: 1.55;
                    color: rgba(255, 255, 255, 0.95);
                    background-color: transparent;
                    -webkit-font-smoothing: antialiased;
                    overflow-y: auto;
                }
                
                .chat-container {
                    display: flex;
                    flex-direction: column;
                    min-height: 100%;
                    padding: 8px;
                    gap: 12px;
                }
                
                /* Selected text banner */
                .selected-text-banner {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    background: rgba(255, 255, 255, 0.06);
                    border-radius: 8px;
                    padding: 10px 12px;
                    font-size: 12px;
                    color: rgba(255, 255, 255, 0.9);
                }
                
                .selected-text-banner .doc-icon {
                    flex-shrink: 0;
                    opacity: 0.7;
                }
                
                .selected-text-banner .text {
                    flex: 1;
                    overflow: hidden;
                    text-overflow: ellipsis;
                    white-space: nowrap;
                }
                
                .selected-text-banner .close-btn {
                    background: none;
                    border: none;
                    cursor: pointer;
                    padding: 4px;
                    opacity: 0.6;
                    color: inherit;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                
                .selected-text-banner .close-btn:hover {
                    opacity: 1;
                }
                
                /* Action pill for first action */
                .action-pill {
                    align-self: flex-end;
                    background: rgba(255, 255, 255, 0.1);
                    border-radius: 20px;
                    padding: 10px 18px;
                    font-size: 14px;
                    max-width: 80%;
                }
                
                /* Empty state */
                .empty-state {
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    text-align: center;
                    color: rgba(255, 255, 255, 0.5);
                    font-size: 13px;
                    padding: 40px 20px;
                    flex: 1;
                }
                
                /* Messages */
                .message {
                    display: flex;
                    flex-direction: column;
                    max-width: 100%;
                }
                
                .message.user {
                    align-items: flex-end;
                }
                
                .message.user .bubble {
                    background: rgba(255, 255, 255, 0.1);
                    border-radius: 18px;
                    padding: 10px 16px;
                    max-width: 80%;
                    word-wrap: break-word;
                    white-space: pre-wrap;
                }
                
                .message.assistant {
                    align-items: flex-start;
                    width: 100%;
                }
                
                .message.assistant .content {
                    width: 100%;
                }
                
                .message.assistant .actions {
                    display: flex;
                    gap: 4px;
                    margin-top: 6px;
                }
                
                .action-btn {
                    background: none;
                    border: none;
                    cursor: pointer;
                    padding: 4px;
                    color: rgba(255, 255, 255, 0.4);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    border-radius: 4px;
                    transition: color 0.15s, background 0.15s;
                }
                
                .action-btn:hover {
                    color: rgba(255, 255, 255, 0.8);
                    background: rgba(255, 255, 255, 0.1);
                }
                
                /* Loading indicator */
                .loading-indicator {
                    padding: 8px 0;
                }
                
                .typing-dots {
                    display: flex;
                    gap: 4px;
                }
                
                .typing-dots span {
                    width: 6px;
                    height: 6px;
                    background: rgba(255, 255, 255, 0.4);
                    border-radius: 50%;
                    animation: bounce 1.4s infinite ease-in-out both;
                }
                
                .typing-dots span:nth-child(1) { animation-delay: -0.32s; }
                .typing-dots span:nth-child(2) { animation-delay: -0.16s; }
                .typing-dots span:nth-child(3) { animation-delay: 0s; }
                
                @keyframes bounce {
                    0%, 80%, 100% { transform: scale(0); }
                    40% { transform: scale(1); }
                }
                
                /* Markdown content styles */
                .content h1, .content h2, .content h3, .content h4, .content h5, .content h6 {
                    color: white;
                    font-weight: 600;
                    margin-top: 16px;
                    margin-bottom: 8px;
                    line-height: 1.3;
                }
                
                .content h1:first-child, .content h2:first-child, .content h3:first-child {
                    margin-top: 0;
                }
                
                .content h1 { font-size: 1.4em; }
                .content h2 { font-size: 1.25em; }
                .content h3 { font-size: 1.1em; }
                .content h4 { font-size: 1em; }
                
                .content p {
                    margin: 0 0 10px 0;
                }
                
                .content p:last-child {
                    margin-bottom: 0;
                }
                
                .content a {
                    color: #58a6ff;
                    text-decoration: none;
                }
                
                .content a:hover {
                    text-decoration: underline;
                }
                
                .content strong, .content b {
                    font-weight: 600;
                    color: white;
                }
                
                .content em, .content i {
                    font-style: italic;
                }
                
                .content code:not(pre code) {
                    font-family: "SF Mono", Monaco, Consolas, monospace;
                    font-size: 0.88em;
                    background: rgba(255, 255, 255, 0.12);
                    padding: 2px 6px;
                    border-radius: 4px;
                    color: #e6a07c;
                }
                
                .content pre {
                    background: #141414;
                    border-radius: 8px;
                    padding: 14px 16px;
                    margin: 10px 0;
                    overflow-x: auto;
                    border: 1px solid rgba(255, 255, 255, 0.1);
                }
                
                .content pre code {
                    font-family: "SF Mono", Monaco, Consolas, monospace;
                    font-size: 13px;
                    line-height: 1.5;
                    background: transparent;
                    padding: 0;
                    color: #e6e6e6;
                    white-space: pre-wrap;
                    word-wrap: break-word;
                }
                
                .content ul, .content ol {
                    margin: 8px 0;
                    padding-left: 24px;
                }
                
                .content li {
                    margin: 4px 0;
                    line-height: 1.5;
                }
                
                .content blockquote {
                    border-left: 3px solid rgba(255, 255, 255, 0.25);
                    margin: 10px 0;
                    padding: 6px 0 6px 14px;
                    color: rgba(255, 255, 255, 0.8);
                    background: rgba(255, 255, 255, 0.02);
                    border-radius: 0 6px 6px 0;
                }
                
                .content blockquote p {
                    margin: 0;
                }
                
                /* Tables */
                .content .table-wrapper {
                    overflow-x: auto;
                    margin: 10px 0;
                    border-radius: 8px;
                }
                
                .content table {
                    border-collapse: collapse;
                    min-width: 100%;
                    font-size: 13px;
                }
                
                .content th, .content td {
                    border: 1px solid rgba(255, 255, 255, 0.15);
                    padding: 8px 12px;
                    text-align: left;
                }
                
                .content th {
                    font-weight: 600;
                    color: white;
                    background: rgba(255, 255, 255, 0.06);
                }
                
                .content tbody tr:nth-child(odd) {
                    background: rgba(255, 255, 255, 0.02);
                }
                
                .content hr {
                    border: none;
                    border-top: 1px solid rgba(255, 255, 255, 0.15);
                    margin: 16px 0;
                }
                
                .content del, .content s {
                    text-decoration: line-through;
                    color: rgba(255, 255, 255, 0.6);
                }
                
                .content kbd {
                    background: rgba(255, 255, 255, 0.1);
                    border: 1px solid rgba(255, 255, 255, 0.2);
                    border-radius: 4px;
                    padding: 2px 6px;
                    font-family: "SF Mono", Monaco, monospace;
                    font-size: 0.85em;
                }
                
                /* Scrollbar */
                ::-webkit-scrollbar {
                    width: 6px;
                    height: 6px;
                }
                
                ::-webkit-scrollbar-track {
                    background: transparent;
                }
                
                ::-webkit-scrollbar-thumb {
                    background: rgba(255, 255, 255, 0.2);
                    border-radius: 3px;
                }
                
                ::-webkit-scrollbar-thumb:hover {
                    background: rgba(255, 255, 255, 0.3);
                }
                
                ::selection {
                    background: rgba(88, 166, 255, 0.3);
                    color: white;
                }
            </style>
        </head>
        <body>
            <div class="chat-container">
                \(selectedTextHTML)
                \(lastActionHTML)
                \(messagesHTML)
                \(loadingHTML)
                \(emptyStateHTML)
            </div>
            <script>
                (function() {
                    // Wrap tables in scroll containers
                    document.querySelectorAll('.content table').forEach(function(table) {
                        if (!table.parentElement.classList.contains('table-wrapper')) {
                            var wrapper = document.createElement('div');
                            wrapper.className = 'table-wrapper';
                            table.parentNode.insertBefore(wrapper, table);
                            wrapper.appendChild(table);
                        }
                    });
                    
                    // Action button handlers
                    document.querySelectorAll('.action-btn').forEach(function(btn) {
                        btn.addEventListener('click', function(e) {
                            e.preventDefault();
                            var action = this.getAttribute('data-action');
                            var index = parseInt(this.getAttribute('data-index'), 10);
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.actionClicked) {
                                window.webkit.messageHandlers.actionClicked.postMessage({action: action, index: index});
                            }
                        });
                    });
                    
                    // Auto-scroll to bottom
                    window.scrollTo(0, document.body.scrollHeight);
                    
                    // Handle external links
                    document.querySelectorAll('.content a').forEach(function(link) {
                        link.addEventListener('click', function(e) {
                            e.preventDefault();
                            var href = this.getAttribute('href');
                            if (href && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.openLink) {
                                window.webkit.messageHandlers.openLink.postMessage(href);
                            }
                        });
                    });
                })();
                
                function clearSelectedText() {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.clearSelectedText) {
                        window.webkit.messageHandlers.clearSelectedText.postMessage({});
                    }
                }
            </script>
        </body>
        </html>
        """
    }
}

extension ChatWebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.debug("ChatWebView navigation finished")
        scrollToBottom()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("ChatWebView navigation failed: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}

private class ChatMessageHandler: NSObject, WKScriptMessageHandler {
    weak var view: ChatWebView?
    
    init(view: ChatWebView) {
        self.view = view
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        if message.name == "actionClicked",
           let body = message.body as? [String: Any],
           let action = body["action"] as? String,
           let index = body["index"] as? Int {
            view?.handleAction(action, messageIndex: index)
        } else if message.name == "clearSelectedText" {
            view?.handleClearSelectedText()
        }
    }
}
