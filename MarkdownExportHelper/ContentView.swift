//
//  ContentView.swift
//  MarkdownExportHelper
//
//  Created by Gigass on 2025/7/25.
//

import SwiftUI
import MarkdownUI
import Ink
import ToastUI

struct ToastConfig {
    var message: String
    var systemImage: String
    var color: Color
    
    static func success(message: String) -> ToastConfig {
        ToastConfig(message: message, systemImage: "checkmark.circle.fill", color: .green)
    }
    
    static func failure(message: String) -> ToastConfig {
        ToastConfig(message: "Error: \(message)", systemImage: "xmark.circle.fill", color: .red)
    }
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @State private var markdownText: String = """
    # Markdown Export Helper
    
    A powerful and elegant tool for iOS.
    
    ## Features
    
    - Real-time preview
    - Multiple export formats
    - Light & Dark themes
    
    ```swift
    struct ContentView: View {
        var body: some View {
            Text("Hello, SwiftUI!")
        }
    }
    ```
    """
    @State private var isDarkMode = false
    @State private var history: [String] = []
    @State private var showToast = false
    @State private var toastConfig = ToastConfig.success(message: "")
    @State private var showPreview = true // For compact view toggle

    private var renderableView: some View {
        Markdown(markdownText)
            .markdownTheme(.gitHub)
            .padding()
            .background(Color(.systemBackground))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if sizeClass == .regular {
                    // iPad-like side-by-side layout
                    HStack(spacing: 0) {
                        editorView
                        Divider()
                        previewView
                    }
                } else {
                    // iPhone-like tabbed layout
                    VStack {
                        if showPreview {
                            previewView
                        } else {
                            editorView
                        }
                    }
                }
                
                Divider()
                footerButtons
            }
            .navigationTitle("Markdown Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Toolbar items
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if sizeClass != .regular {
                        Button(action: { showPreview.toggle() }) {
                            Image(systemName: showPreview ? "doc.text.fill" : "eye.fill")
                        }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    historyMenu
                    Toggle(isOn: $isDarkMode) {
                        Image(systemName: "moon.fill")
                    }
                    .toggleStyle(.button)
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear(perform: intelligentLoad)
        .toast(isPresented: $showToast) {
            HStack {
                Image(systemName: toastConfig.systemImage)
                Text(toastConfig.message)
            }
            .foregroundColor(.white)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(toastConfig.color)
            .cornerRadius(8)
        }
    }
    
    // MARK: - View Components
    
    private var editorView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Markdown").font(.headline).padding()
            TextEditor(text: $markdownText)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal)
        }
        .background(Color(.secondarySystemBackground))
    }
    
    private var previewView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Preview").font(.headline).padding()
            ScrollView {
                Markdown(markdownText)
                    .markdownTheme(.gitHub)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(.secondarySystemBackground))
    }
    
    private var footerButtons: some View {
        HStack {
            Button(action: exportAsImage) { Label("Image", systemImage: "photo") }
            Spacer()
            Button(action: exportAsPDF) { Label("PDF", systemImage: "doc.text") }
            Spacer()
            Button(action: exportAsHTML) { Label("HTML", systemImage: "safari") }
            Spacer()
            Button(action: exportAsMarkdown) { Label("MD", systemImage: "markdown") }
        }
        .padding()
        .labelStyle(.iconOnly)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    private var historyMenu: some View {
        Menu {
            if history.isEmpty {
                Text("No History")
            } else {
                ForEach(history, id: \.self) { item in
                    Button(action: { self.markdownText = item }) {
                        Text(item.prefix(30).trimmingCharacters(in: .whitespacesAndNewlines) + "...")
                    }
                }
                Divider()
                Button(role: .destructive, action: clearHistory) {
                    Label("Clear History", systemImage: "trash")
                }
            }
        } label: {
            Label("History", systemImage: "clock")
        }
    }
    
    // MARK: - Export Functions
    
    private func exportAsImage() {
        if let image = renderableView.renderAsImage() {
            share(items: [image])
            presentToast(config: .success(message: "Image Ready!"))
        } else {
            presentToast(config: .failure(message: "Failed to render image."))
        }
    }
    
    private func exportAsPDF() {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect.zero)
        let hostingController = UIHostingController(rootView: renderableView)
        let viewSize = hostingController.view.intrinsicContentSize
        hostingController.view.bounds.size = viewSize

        let pdfData = renderer.pdfData { (context) in
            context.beginPage(withBounds: CGRect(origin: .zero, size: viewSize), pageInfo: [:])
            hostingController.view.layer.render(in: context.cgContext)
        }
        share(items: [pdfData])
        presentToast(config: .success(message: "PDF Ready!"))
    }
    
    private func exportAsHTML() {
        let parser = MarkdownParser()
        let htmlBody = parser.html(from: markdownText)
        let css = isDarkMode ? darkThemeCSS : lightThemeCSS
        let html = htmlTemplate(body: htmlBody, css: css)
        
        saveAndShare(text: html, fileName: "export.html", successMessage: "HTML Ready!")
    }
    
    private func exportAsMarkdown() {
        saveAndShare(text: markdownText, fileName: "export.md", successMessage: "Markdown Ready!")
    }

    private func saveAndShare(text: String, fileName: String, successMessage: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try text.write(to: tempURL, atomically: true, encoding: .utf8)
            share(items: [tempURL])
            presentToast(config: .success(message: successMessage))
        } catch {
            presentToast(config: .failure(message: "Failed to save file."))
        }
    }

    private func share(items: [Any]) {
        guard let source = UIApplication.shared.windows.first?.rootViewController else {
            return
        }
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // For iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = source.view
            popover.sourceRect = CGRect(x: source.view.bounds.midX, y: source.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        source.present(activityVC, animated: true)
        addToHistory(markdownText)
    }

    // MARK: - History & Loading
    
    private func presentToast(config: ToastConfig) {
        self.toastConfig = config
        self.showToast = true
    }
    
    private func intelligentLoad() {
        loadHistory()
        if let latest = history.first {
            markdownText = latest
        } else {
            if let clipboardString = UIPasteboard.general.string {
                markdownText = clipboardString
            }
        }
    }
    
    private func loadHistory() {
        self.history = UserDefaults.standard.stringArray(forKey: "markdownHistory") ?? []
    }
    
    private func addToHistory(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !history.contains(text) else { return }
        var updatedHistory = [text] + history
        if updatedHistory.count > 20 {
            updatedHistory = Array(updatedHistory.prefix(20))
        }
        self.history = updatedHistory
        UserDefaults.standard.set(self.history, forKey: "markdownHistory")
    }
    
    private func clearHistory() {
        self.history = []
        UserDefaults.standard.removeObject(forKey: "markdownHistory")
    }
    
    // MARK: - HTML Templates
    private var lightThemeCSS: String {
        """
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
            line-height: 1.6;
            padding: 20px;
            background-color: #ffffff;
            color: #24292e;
        }
        .markdown-body {
            box-sizing: border-box;
            min-width: 200px;
            max-width: 980px;
            margin: 0 auto;
            padding: 45px;
        }
        """
    }
    private var darkThemeCSS: String {
        """
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
            line-height: 1.6;
            padding: 20px;
            background-color: #0d1117;
            color: #c9d1d9;
        }
        .markdown-body {
            box-sizing: border-box;
            min-width: 200px;
            max-width: 980px;
            margin: 0 auto;
            padding: 45px;
        }
        """
    }
    private func htmlTemplate(body: String, css: String) -> String {
        return """
        <!DOCTYPE html><html><head><meta charset="utf-8"><title>Markdown Export</title><style>\(css)</style></head>
        <body class="markdown-body">\(body)</body></html>
        """
    }
}

#Preview {
    ContentView()
}
