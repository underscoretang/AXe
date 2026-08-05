//
//  WebContentTestView.swift
//  AxePlayground
//
//  Fixture for `describe-ui --include-web-content`: the page content renders in a separate
//  WebContent process, reachable only by cross-process hit-testing.
//

import SwiftUI
import WebKit

struct WebContentTestView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Web Content Playground")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityIdentifier("web-content-test-title")

            // This label IS in the native tree, so a test can tell "the screen is up" apart from
            // "the web content was discovered".
            Text("Native sibling label")
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("web-content-native-sibling")

            WebContentFixtureView()
                .accessibilityIdentifier("web-content-test-webview")
        }
        .padding()
        .navigationTitle("Web Content Test")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WebContentFixtureView: UIViewRepresentable {
    // Loaded from a string rather than a URL: the fixture must render identically with no network.
    private static let html = """
        <!DOCTYPE html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
              body { font: 17px -apple-system, sans-serif; margin: 12px; }
              /* Generous vertical spacing so each element sits in its own hit-test grid row. */
              h1 { font-size: 24px; margin: 0 0 24px; }
              p, div { margin: 0 0 24px; }
              button, input { font-size: 17px; padding: 8px; }
            </style>
          </head>
          <body>
            <h1>AXE_WEB_HEADING</h1>
            <p>AXE_WEB_PARAGRAPH body text</p>
            <div><a href="#">AXE_WEB_LINK</a></div>
            <div><button type="button">AXE_WEB_BUTTON</button></div>
            <div><input type="text" aria-label="AXE_WEB_FIELD" value="field"></div>
          </body>
        </html>
        """

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.loadHTMLString(Self.html, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

#Preview {
    WebContentTestView()
}
