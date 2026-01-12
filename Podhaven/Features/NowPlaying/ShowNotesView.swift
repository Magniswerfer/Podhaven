import SwiftUI
import WebKit

struct ShowNotesView: View {
    let episode: Episode
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            Group {
                if let html = episode.showNotesHTML, !html.isEmpty {
                    ShowNotesWebView(
                        html: html,
                        isDarkMode: colorScheme == .dark
                    )
                } else if let description = episode.episodeDescription, !description.isEmpty {
                    ScrollView {
                        Text(description)
                            .padding()
                    }
                } else {
                    ContentUnavailableView {
                        Label("No Show Notes", systemImage: "doc.text")
                    } description: {
                        Text("This episode doesn't have any show notes available.")
                    }
                }
            }
            .navigationTitle("Show Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - WebView Wrapper

struct ShowNotesWebView: UIViewRepresentable {
    let html: String
    let isDarkMode: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let styledHTML = wrapHTMLWithStyles(html)
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func wrapHTMLWithStyles(_ content: String) -> String {
        let backgroundColor = isDarkMode ? "#1c1c1e" : "#ffffff"
        let textColor = isDarkMode ? "#ffffff" : "#000000"
        let secondaryColor = isDarkMode ? "#8e8e93" : "#6c6c70"
        let linkColor = isDarkMode ? "#0a84ff" : "#007aff"
        let codeBackground = isDarkMode ? "#2c2c2e" : "#f2f2f7"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    box-sizing: border-box;
                }
                
                html, body {
                    margin: 0;
                    padding: 0;
                    background-color: \(backgroundColor);
                    color: \(textColor);
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                    font-size: 17px;
                    line-height: 1.5;
                    -webkit-text-size-adjust: 100%;
                }
                
                body {
                    padding: 16px;
                }
                
                h1, h2, h3, h4, h5, h6 {
                    font-weight: 600;
                    margin-top: 24px;
                    margin-bottom: 12px;
                    line-height: 1.3;
                }
                
                h1 { font-size: 28px; }
                h2 { font-size: 22px; }
                h3 { font-size: 20px; }
                h4 { font-size: 18px; }
                
                p {
                    margin: 0 0 16px 0;
                }
                
                a {
                    color: \(linkColor);
                    text-decoration: none;
                }
                
                a:active {
                    opacity: 0.7;
                }
                
                ul, ol {
                    padding-left: 24px;
                    margin: 0 0 16px 0;
                }
                
                li {
                    margin-bottom: 8px;
                }
                
                blockquote {
                    margin: 16px 0;
                    padding: 12px 16px;
                    border-left: 4px solid \(linkColor);
                    background-color: \(codeBackground);
                    border-radius: 4px;
                }
                
                blockquote p:last-child {
                    margin-bottom: 0;
                }
                
                code {
                    font-family: 'SF Mono', Menlo, monospace;
                    font-size: 15px;
                    background-color: \(codeBackground);
                    padding: 2px 6px;
                    border-radius: 4px;
                }
                
                pre {
                    background-color: \(codeBackground);
                    padding: 12px;
                    border-radius: 8px;
                    overflow-x: auto;
                    margin: 16px 0;
                }
                
                pre code {
                    padding: 0;
                    background: none;
                }
                
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 8px;
                    margin: 8px 0;
                }
                
                hr {
                    border: none;
                    border-top: 1px solid \(secondaryColor);
                    margin: 24px 0;
                    opacity: 0.3;
                }
                
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 16px 0;
                }
                
                th, td {
                    padding: 8px 12px;
                    border: 1px solid \(secondaryColor);
                    text-align: left;
                }
                
                th {
                    background-color: \(codeBackground);
                    font-weight: 600;
                }
                
                /* Timestamp links styling */
                a[href*="timestamp"], a[href^="#t="] {
                    background-color: \(codeBackground);
                    padding: 2px 8px;
                    border-radius: 4px;
                    font-family: 'SF Mono', Menlo, monospace;
                    font-size: 14px;
                }
            </style>
        </head>
        <body>
            \(content)
        </body>
        </html>
        """
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Open external links in Safari
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

#Preview {
    ShowNotesView(episode: .sample)
}
