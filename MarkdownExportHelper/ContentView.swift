//
//  ContentView.swift
//  MarkdownExportHelper
//
//  Created by Gigass on 2025/7/25.
//

import SwiftUI

// Temporary inline classes until project structure is fixed
struct HistoryItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    let title: String
    
    init(content: String) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.title = String(content.prefix(50)) + (content.count > 50 ? "..." : "")
    }
}

class SimpleMarkdownViewModel: ObservableObject {
    @Published var markdownText: String = ""
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var history: [HistoryItem] = []
    @Published var isExportingImage = false
    
    private let maxHistoryItems = 50
    private let userDefaults = UserDefaults.standard
    private let historyKey = "MarkdownHistory"
    private let lastContentKey = "LastMarkdownContent"
    
    init() {
        loadHistory()
    }
    
    func loadContent() {
        if let lastContent = userDefaults.string(forKey: lastContentKey), !lastContent.isEmpty {
            markdownText = lastContent
            showToast(message: "已恢复上次编辑的内容")
        } else if let clipboardContent = UIPasteboard.general.string, !clipboardContent.isEmpty {
            markdownText = clipboardContent
            showToast(message: "已从剪贴板加载内容")
        } else {
            markdownText = """
# Markdown Export Helper

这是一个功能强大的 Markdown 编辑和导出工具。

## 主要功能

- **实时预览**: 即时查看 Markdown 渲染结果
- **多格式导出**: 支持 PNG、PDF、HTML、Markdown 格式
- **主题切换**: 支持亮色和暗色主题
- **历史管理**: 自动保存编辑历史
- **智能加载**: 自动从剪贴板加载内容

开始编辑您的 Markdown 内容吧！
"""
        }
    }
    
    private func saveToHistory() {
        guard !markdownText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Check if content already exists in history
        if let existingIndex = history.firstIndex(where: { $0.content == markdownText }) {
            // Move existing item to front
            let existingItem = history.remove(at: existingIndex)
            history.insert(existingItem, at: 0)
        } else {
            // Add new item
            let historyItem = HistoryItem(content: markdownText)
            history.insert(historyItem, at: 0)
        }
        
        // Keep only the latest items
        if history.count > maxHistoryItems {
            history = Array(history.prefix(maxHistoryItems))
        }
        
        saveHistory()
        userDefaults.set(markdownText, forKey: lastContentKey)
    }
    
    func saveToHistoryManually() {
        saveToHistory()
        showToast(message: "已保存到历史")
    }
    
    func exportAsImage(completion: @escaping (UIImage?) -> Void) {
        isExportingImage = true
        
        DispatchQueue.main.async {
            let view = MarkdownPreviewView(content: self.markdownText)
                .padding(32)
                .background(Color(.systemBackground))
            
            let image = view.renderAsLongImage(width: 750)
            
            self.isExportingImage = false
            completion(image)
        }
    }
    
    func shareImage(_ image: UIImage) {
        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        // 获取当前显示的视图控制器
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            var rootViewController = window.rootViewController
            
            // 找到最顶层的视图控制器
            while let presentedViewController = rootViewController?.presentedViewController {
                rootViewController = presentedViewController
            }
            
            if let topViewController = rootViewController {
                // iPad支持
                if UIDevice.current.userInterfaceIdiom == .pad {
                    activityViewController.popoverPresentationController?.sourceView = topViewController.view
                    activityViewController.popoverPresentationController?.sourceRect = CGRect(
                        x: topViewController.view.bounds.midX,
                        y: topViewController.view.bounds.midY,
                        width: 0,
                        height: 0
                    )
                    activityViewController.popoverPresentationController?.permittedArrowDirections = []
                }
                
                topViewController.present(activityViewController, animated: true, completion: nil)
            }
        }
    }
    
    private func loadHistory() {
        if let data = userDefaults.data(forKey: historyKey),
           let decodedHistory = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            history = decodedHistory
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            userDefaults.set(encoded, forKey: historyKey)
        }
    }
    
    func restoreFromHistory(_ item: HistoryItem, onComplete: (() -> Void)? = nil) {
        markdownText = item.content
        showToast(message: "已恢复历史内容")
        onComplete?()
    }
    
    func deleteHistoryItem(_ item: HistoryItem) {
        history.removeAll { $0.id == item.id }
        saveHistory()
        showToast(message: "已删除历史记录")
    }
    
    func clearHistory(onComplete: (() -> Void)? = nil) {
        history.removeAll()
        saveHistory()
        showToast(message: "已清空所有历史记录")
        onComplete?()
    }
    
    func clearContent() {
        markdownText = ""
        showToast(message: "内容已清空")
    }
    
    func pasteFromClipboard() {
        if let clipboardContent = UIPasteboard.general.string, !clipboardContent.isEmpty {
            markdownText = clipboardContent
            showToast(message: "已从剪贴板粘贴内容")
        } else {
            showToast(message: "剪贴板为空")
        }
    }
    
    func exportAsPNG() {
        exportAsImage { image in
            guard let image = image else {
                self.showToast(message: "图片生成失败")
                return
            }
            
            // Save to history when exporting
            self.saveToHistory()
            
            let imageSaver = ImageSaver()
            imageSaver.onSuccess = {
                self.showToast(message: "已保存到相册")
            }
            imageSaver.onError = { error in
                self.showToast(message: "保存失败: \(error.localizedDescription)")
            }
            imageSaver.writeToPhotoAlbum(image: image)
        }
    }
    
    func exportAsPDF() {
        // Save to history when exporting
        saveToHistory()
        
        isExportingImage = true
        
        DispatchQueue.main.async {
            let view = MarkdownPreviewView(content: self.markdownText)
                .padding(32)
                .background(Color(.systemBackground))
            
            guard let pdfData = view.renderAsPDF() else {
                self.isExportingImage = false
                self.showToast(message: "PDF 生成失败")
                return
            }
            
            self.isExportingImage = false
            self.savePDFToFiles(data: pdfData)
        }
    }
    
    private func savePDFToFiles(data: Data) {
        let fileName = "Markdown_Export_\(Date().timeIntervalSince1970).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            presentActivityViewController(with: [tempURL])
            showToast(message: "PDF 已生成")
        } catch {
            showToast(message: "PDF 保存失败: \(error.localizedDescription)")
        }
    }
    
    private func presentActivityViewController(with items: [Any]) {
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            var rootViewController = window.rootViewController
            
            // 找到最顶层的视图控制器
            while let presentedViewController = rootViewController?.presentedViewController {
                rootViewController = presentedViewController
            }
            
            if let topViewController = rootViewController {
                // iPad支持
                if UIDevice.current.userInterfaceIdiom == .pad {
                    activityViewController.popoverPresentationController?.sourceView = topViewController.view
                    activityViewController.popoverPresentationController?.sourceRect = CGRect(
                        x: topViewController.view.bounds.midX,
                        y: topViewController.view.bounds.midY,
                        width: 0,
                        height: 0
                    )
                    activityViewController.popoverPresentationController?.permittedArrowDirections = []
                }
                
                topViewController.present(activityViewController, animated: true, completion: nil)
            }
        }
    }
    
    func exportAsHTML() {
        // Save to history when exporting
        saveToHistory()
        
        let htmlContent = convertMarkdownToHTML(markdownText)
        let fileName = "Markdown_Export_\(Date().timeIntervalSince1970).html"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try htmlContent.write(to: tempURL, atomically: true, encoding: .utf8)
            presentActivityViewController(with: [tempURL])
            showToast(message: "HTML 文件已生成")
        } catch {
            showToast(message: "HTML 保存失败: \(error.localizedDescription)")
        }
    }
    
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        var html = markdown
        
        // 替换标题
        html = html.replacingOccurrences(of: "### (.+)", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "## (.+)", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "# (.+)", with: "<h1>$1</h1>", options: .regularExpression)
        
        // 替换粗体和斜体
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
        
        // 替换行内代码
        html = html.replacingOccurrences(of: "`(.+?)`", with: "<code>$1</code>", options: .regularExpression)
        
        // 替换列表项
        html = html.replacingOccurrences(of: "^- (.+)", with: "<li>$1</li>", options: .regularExpression)
        html = html.replacingOccurrences(of: "^\\* (.+)", with: "<li>$1</li>", options: .regularExpression)
        
        // 替换引用
        html = html.replacingOccurrences(of: "^> (.+)", with: "<blockquote>$1</blockquote>", options: .regularExpression)
        
        // 处理段落
        let lines = html.components(separatedBy: .newlines)
        var processedLines: [String] = []
        var inList = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty {
                if inList {
                    processedLines.append("</ul>")
                    inList = false
                }
                processedLines.append("<br>")
            } else if trimmedLine.hasPrefix("<li>") {
                if !inList {
                    processedLines.append("<ul>")
                    inList = true
                }
                processedLines.append(trimmedLine)
            } else {
                if inList {
                    processedLines.append("</ul>")
                    inList = false
                }
                
                if !trimmedLine.hasPrefix("<h") && !trimmedLine.hasPrefix("<blockquote>") {
                    processedLines.append("<p>\(trimmedLine)</p>")
                } else {
                    processedLines.append(trimmedLine)
                }
            }
        }
        
        if inList {
            processedLines.append("</ul>")
        }
        
        let bodyContent = processedLines.joined(separator: "\n")
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Markdown Export</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    max-width: 800px;
                    margin: 0 auto;
                    padding: 20px;
                    color: #333;
                }
                h1, h2, h3 {
                    color: #2c3e50;
                    margin-top: 24px;
                    margin-bottom: 16px;
                }
                h1 {
                    font-size: 2em;
                    border-bottom: 2px solid #eee;
                    padding-bottom: 8px;
                }
                h2 {
                    font-size: 1.5em;
                    border-bottom: 1px solid #eee;
                    padding-bottom: 4px;
                }
                h3 {
                    font-size: 1.2em;
                }
                code {
                    background-color: #f4f4f4;
                    padding: 2px 4px;
                    border-radius: 3px;
                    font-family: Monaco, 'Courier New', monospace;
                }
                blockquote {
                    border-left: 4px solid #ddd;
                    margin: 0;
                    padding-left: 16px;
                    color: #666;
                    font-style: italic;
                }
                ul {
                    padding-left: 20px;
                }
                li {
                    margin-bottom: 4px;
                }
                p {
                    margin-bottom: 16px;
                }
            </style>
        </head>
        <body>
        \(bodyContent)
        </body>
        </html>
        """
    }
    
    func exportAsMarkdown() {
        // Save to history when exporting
        saveToHistory()
        
        let fileName = "Markdown_Export_\(Date().timeIntervalSince1970).md"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try markdownText.write(to: tempURL, atomically: true, encoding: .utf8)
            presentActivityViewController(with: [tempURL])
            showToast(message: "Markdown 文件已生成")
        } catch {
            showToast(message: "Markdown 文件保存失败: \(error.localizedDescription)")
        }
    }
    
    func exportAsWord() {
        // Save to history when exporting
        saveToHistory()
        
        let wordContent = convertMarkdownToWordHTML(markdownText)
        let fileName = "Markdown_Export_\(Date().timeIntervalSince1970).doc"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try wordContent.write(to: tempURL, atomically: true, encoding: .utf8)
            presentActivityViewController(with: [tempURL])
            showToast(message: "Word 文档已生成")
        } catch {
            showToast(message: "Word 文档保存失败: \(error.localizedDescription)")
        }
    }
    
    private func convertMarkdownToWordHTML(_ markdown: String) -> String {
        var html = markdown
        
        // 替换标题
        html = html.replacingOccurrences(of: "### (.+)", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "## (.+)", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "# (.+)", with: "<h1>$1</h1>", options: .regularExpression)
        
        // 替换粗体和斜体
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
        
        // 替换行内代码
        html = html.replacingOccurrences(of: "`(.+?)`", with: "<code>$1</code>", options: .regularExpression)
        
        // 替换列表项
        html = html.replacingOccurrences(of: "^- (.+)", with: "<li>$1</li>", options: .regularExpression)
        html = html.replacingOccurrences(of: "^\\* (.+)", with: "<li>$1</li>", options: .regularExpression)
        
        // 替换引用
        html = html.replacingOccurrences(of: "^> (.+)", with: "<blockquote>$1</blockquote>", options: .regularExpression)
        
        // 处理段落
        let lines = html.components(separatedBy: .newlines)
        var processedLines: [String] = []
        var inList = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty {
                if inList {
                    processedLines.append("</ul>")
                    inList = false
                }
                processedLines.append("<br>")
            } else if trimmedLine.hasPrefix("<li>") {
                if !inList {
                    processedLines.append("<ul>")
                    inList = true
                }
                processedLines.append(trimmedLine)
            } else {
                if inList {
                    processedLines.append("</ul>")
                    inList = false
                }
                
                if !trimmedLine.hasPrefix("<h") && !trimmedLine.hasPrefix("<blockquote>") {
                    processedLines.append("<p>\(trimmedLine)</p>")
                } else {
                    processedLines.append(trimmedLine)
                }
            }
        }
        
        if inList {
            processedLines.append("</ul>")
        }
        
        let bodyContent = processedLines.joined(separator: "\n")
        
        return """
        <!DOCTYPE html>
        <html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40">
        <head>
            <meta charset="UTF-8">
            <meta name="ProgId" content="Word.Document">
            <meta name="Generator" content="Microsoft Word">
            <meta name="Originator" content="Microsoft Word">
            <title>Markdown Export</title>
            <!--[if gte mso 9]>
            <xml>
                <w:WordDocument>
                    <w:View>Print</w:View>
                    <w:Zoom>90</w:Zoom>
                    <w:DoNotOptimizeForBrowser/>
                </w:WordDocument>
            </xml>
            <![endif]-->
            <style>
                @page {
                    size: A4;
                    margin: 2.54cm 1.91cm 2.54cm 1.91cm;
                    mso-header-margin: 1.27cm;
                    mso-footer-margin: 1.27cm;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                    font-size: 16px;
                    line-height: 1.6;
                    color: #333333;
                    margin: 0;
                    padding: 20px;
                    background-color: white;
                    -webkit-text-size-adjust: 100%;
                    -ms-text-size-adjust: 100%;
                }
                
                h1, h2, h3 {
                    color: #2c3e50;
                    margin-top: 24px;
                    margin-bottom: 16px;
                    font-weight: 600;
                    page-break-after: avoid;
                }
                
                h1 {
                    font-size: 32px;
                    border-bottom: 3px solid #3498db;
                    padding-bottom: 10px;
                    margin-top: 0;
                }
                
                h2 {
                    font-size: 24px;
                    border-bottom: 2px solid #ecf0f1;
                    padding-bottom: 8px;
                }
                
                h3 {
                    font-size: 20px;
                    color: #34495e;
                }
                
                p {
                    margin-bottom: 16px;
                    text-align: justify;
                    orphans: 2;
                    widows: 2;
                }
                
                strong {
                    font-weight: 600;
                    color: #2c3e50;
                }
                
                em {
                    font-style: italic;
                    color: #7f8c8d;
                }
                
                code {
                    font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
                    font-size: 14px;
                    background-color: #f8f9fa;
                    color: #d73a49;
                    padding: 2px 6px;
                    border-radius: 4px;
                    border: 1px solid #e1e4e8;
                }
                
                blockquote {
                    margin: 16px 0;
                    padding: 0 16px;
                    border-left: 4px solid #3498db;
                    background-color: #f8f9fa;
                    font-style: italic;
                    color: #6c757d;
                    page-break-inside: avoid;
                }
                
                ul {
                    margin: 16px 0;
                    padding-left: 24px;
                }
                
                li {
                    margin-bottom: 8px;
                    line-height: 1.5;
                }
                
                /* Word-specific styles */
                @media print {
                    body {
                        -webkit-print-color-adjust: exact;
                        print-color-adjust: exact;
                    }
                }
                
                /* Ensure consistent spacing */
                * {
                    box-sizing: border-box;
                }
            </style>
        </head>
        <body>
        \(bodyContent)
        </body>
        </html>
        """
    }
    
    private func showToast(message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showToast = false
        }
    }
}

struct MarkdownPreviewView: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(parseMarkdown(content), id: \.id) { element in
                renderElement(element)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func parseMarkdown(_ text: String) -> [MarkdownElement] {
        let lines = text.components(separatedBy: .newlines)
        var elements: [MarkdownElement] = []
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty {
                continue
            } else if trimmedLine.hasPrefix("# ") {
                let content = String(trimmedLine.dropFirst(2))
                elements.append(MarkdownElement(id: index, type: .heading1, content: content, formattedContent: createAttributedString(content)))
            } else if trimmedLine.hasPrefix("## ") {
                let content = String(trimmedLine.dropFirst(3))
                elements.append(MarkdownElement(id: index, type: .heading2, content: content, formattedContent: createAttributedString(content)))
            } else if trimmedLine.hasPrefix("### ") {
                let content = String(trimmedLine.dropFirst(4))
                elements.append(MarkdownElement(id: index, type: .heading3, content: content, formattedContent: createAttributedString(content)))
            } else if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") {
                let content = String(trimmedLine.dropFirst(2))
                elements.append(MarkdownElement(id: index, type: .listItem, content: content, formattedContent: createAttributedString(content)))
            } else if trimmedLine.hasPrefix("> ") {
                let content = String(trimmedLine.dropFirst(2))
                elements.append(MarkdownElement(id: index, type: .quote, content: content, formattedContent: createAttributedString(content)))
            } else if trimmedLine.hasPrefix("```") {
                elements.append(MarkdownElement(id: index, type: .codeBlock, content: trimmedLine, formattedContent: AttributedString(trimmedLine)))
            } else {
                elements.append(MarkdownElement(id: index, type: .paragraph, content: trimmedLine, formattedContent: createAttributedString(trimmedLine)))
            }
        }
        
        return elements
    }
    
    private func createAttributedString(_ text: String) -> AttributedString {
        let attributedString = try! AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        return attributedString
    }
    
    @ViewBuilder
    private func renderElement(_ element: MarkdownElement) -> some View {
        switch element.type {
        case .heading1:
            Text(element.content)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .primary.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.vertical, 16)
                .padding(.bottom, 8)
        case .heading2:
            Text(element.content)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.vertical, 12)
                .padding(.bottom, 6)
        case .heading3:
            Text(element.content)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .padding(.vertical, 10)
                .padding(.bottom, 4)
        case .paragraph:
            Text(element.formattedContent)
                .font(.system(size: 16, weight: .regular))
                .lineSpacing(6)
                .foregroundColor(.primary)
                .padding(.vertical, 8)
        case .listItem:
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
                    .padding(.top, 8)
                
                Text(element.formattedContent)
                    .font(.system(size: 16))
                    .lineSpacing(4)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.leading, 8)
        case .quote:
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(element.formattedContent)
                        .font(.system(size: 16, weight: .medium))
                        .italic()
                        .lineSpacing(4)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.05))
            )
        case .codeBlock:
            Text(element.content)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.vertical, 8)
        }
    }
}

struct MarkdownElement {
    let id: Int
    let type: MarkdownElementType
    let content: String
    let formattedContent: AttributedString
}

enum MarkdownElementType {
    case heading1, heading2, heading3, paragraph, listItem, quote, codeBlock
}

struct SimpleToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
                    .shadow(radius: 5)
            )
    }
}

struct ContentView: View {
    @StateObject private var viewModel = SimpleMarkdownViewModel()
    @State private var isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
    @State private var showingExportMenu = false
    @State private var showingHistory = false
    @State private var selectedTab = 0
    @State private var showingImageExportOptions = false
    @State private var isToolbarExpanded = false
    @State private var showingProjectInfo = false
    @State private var scrollToTop = false
    @State private var editorScrollTrigger = UUID()
    @State private var previewScrollTrigger = UUID()
    
    // iPad适配相关属性
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var shouldUseSideBySideLayout: Bool {
        isIPad // iPad总是使用侧边布局
    }
    
    private func cardSpacing(for geometry: GeometryProxy) -> CGFloat {
        isIPad ? 24 : 12
    }
    
    private func horizontalPadding(for geometry: GeometryProxy) -> CGFloat {
        if isIPad {
            return max(24, geometry.size.width * 0.05) // iPad使用更大的边距
        }
        return 16
    }
    
    private func cardWidth(for geometry: GeometryProxy) -> CGFloat {
        let padding = horizontalPadding(for: geometry)
        let spacing = cardSpacing(for: geometry)
        return (geometry.size.width - padding * 2 - spacing) * 0.5
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Unified background - 确保完全填满屏幕
                Color(.systemGroupedBackground)
                    .ignoresSafeArea(.all)
                
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Custom top toolbar - unified with background  
                        modernToolbar
                            .padding(.horizontal, horizontalPadding(for: geometry))
                            .padding(.vertical, isIPad ? 12 : 8)
                        
                        if shouldUseSideBySideLayout || geometry.size.width > geometry.size.height {
                            // iPad或横屏：侧边布局
                            HStack(spacing: cardSpacing(for: geometry)) {
                                modernEditorCard
                                    .frame(width: cardWidth(for: geometry))
                                
                                modernPreviewCard
                                    .frame(width: cardWidth(for: geometry))
                            }
                            .padding(.horizontal, horizontalPadding(for: geometry))
                        } else {
                            // iPhone竖屏：标签页布局
                            VStack(spacing: 0) {
                                // Custom tab selector - more compact
                                modernTabSelector
                                    .padding(.horizontal, horizontalPadding(for: geometry))
                                    .padding(.vertical, 8)
                                
                                // Content area - flexible height
                                TabView(selection: $selectedTab) {
                                    modernEditorCard
                                        .tag(0)
                                    
                                    modernPreviewCard
                                        .tag(1)
                                }
                                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                .animation(.easeInOut(duration: 0.3), value: selectedTab)
                                .padding(.horizontal, horizontalPadding(for: geometry))
                                .onChange(of: scrollToTop) { _ in
                                    if scrollToTop {
                                        // 在iPhone TabView模式下，强制切换到编辑器tab然后滚动
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            selectedTab = 0
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                            // 重置TextEditor
                                            editorScrollTrigger = UUID()
                                            previewScrollTrigger = UUID()
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                            scrollToTop = false
                                        }
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 0)
                    }
                    
                }
                
                // Loading overlay - 移到外层确保全屏覆盖
                if viewModel.isExportingImage {
                    VStack {
                        ProgressView("正在生成图片...")
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
                    .ignoresSafeArea(.all)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle()) // 强制使用堆栈样式，避免iPad分栏显示
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $showingExportMenu) {
            ModernExportSheet(viewModel: viewModel, showingImageExportOptions: $showingImageExportOptions)
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView(viewModel: viewModel) {
                scrollToTop = true
            }
        }
        .sheet(isPresented: $showingProjectInfo) {
            ProjectInfoView()
        }
        .confirmationDialog("导出长图", isPresented: $showingImageExportOptions, titleVisibility: .visible) {
            Button("保存到相册") {
                viewModel.exportAsPNG()
            }
            Button("分享") {
                viewModel.exportAsImage { image in
                    if let image = image {
                        viewModel.shareImage(image)
                    }
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("请选择操作")
        }
        .overlay(
            Group {
                if viewModel.showToast {
                    VStack {
                        Spacer()
                        SimpleToastView(message: viewModel.toastMessage)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                    }
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.showToast)
                }
            }
        )
        .onAppear {
            viewModel.loadContent()
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    
    private var modernToolbar: some View {
        ZStack {
            // 中心标题 - 使用ZStack确保真正居中
            Text("Markdown Editor")
                .font(.system(size: isIPad ? 28 : 22, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: isDarkMode ? [.white, .gray] : [.primary, .secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // 右侧按钮组
            HStack {
                Spacer()
                
                HStack(spacing: isIPad ? 12 : 8) {
                    // 展开的功能按钮组
                    if isToolbarExpanded {
                        HStack(spacing: isIPad ? 12 : 8) {
                            ModernButton(
                                icon: "info.circle.fill",
                                action: { 
                                    showingProjectInfo.toggle()
                                },
                                isDarkMode: isDarkMode,
                                isIPad: isIPad
                            )
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.15)),
                                removal: .scale.combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.8))
                            ))
                            
                            ModernButton(
                                icon: "clock.fill",
                                action: { 
                                    showingHistory.toggle()
                                },
                                isDarkMode: isDarkMode,
                                isIPad: isIPad
                            )
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1)),
                                removal: .scale.combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.8))
                            ))
                            
                            ModernButton(
                                icon: "square.and.arrow.up.fill",
                                action: { 
                                    showingExportMenu.toggle()
                                },
                                isDarkMode: isDarkMode,
                                isIPad: isIPad
                            )
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.05)),
                                removal: .scale.combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.8))
                            ))
                            
                            ModernButton(
                                icon: isDarkMode ? "sun.max.fill" : "moon.fill",
                                action: { 
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        isDarkMode.toggle()
                                        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
                                    }
                                },
                                isDarkMode: isDarkMode,
                                isIPad: isIPad
                            )
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.8)),
                                removal: .scale.combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.8))
                            ))
                        }
                    }
                    
                    // 主工具按钮 - 始终显示
                    ModernButton(
                        icon: isToolbarExpanded ? "xmark" : "ellipsis",
                        action: { 
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                isToolbarExpanded.toggle()
                            }
                        },
                        isDarkMode: isDarkMode,
                        isIPad: isIPad
                    )
                }
            }
        }
    }
    
    private var modernTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(0..<2) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        selectedTab = index
                        // Auto-dismiss keyboard when switching to preview
                        if index == 1 {
                            hideKeyboard()
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: index == 0 ? "pencil.line" : "eye.fill")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(index == 0 ? "编辑" : "预览")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(selectedTab == index ? .white : .secondary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        ZStack {
                            if selectedTab == index {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.blue.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                        }
                    )
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: selectedTab)
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
    
    private var modernEditorCard: some View {
        VStack(spacing: 0) {
            // Compact card header
            HStack {
                Label("编辑器", systemImage: "pencil.line")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Compact action buttons
                HStack(spacing: isIPad ? 10 : 6) {
                    SmallActionButton(
                        icon: "square.and.arrow.down.fill",
                        color: .green,
                        action: { viewModel.saveToHistoryManually() },
                        isIPad: isIPad
                    )
                    
                    SmallActionButton(
                        icon: "trash.fill",
                        color: .red,
                        action: { viewModel.clearContent() },
                        isIPad: isIPad
                    )
                    
                    SmallActionButton(
                        icon: "doc.on.clipboard.fill",
                        color: .blue,
                        action: { viewModel.pasteFromClipboard() },
                        isIPad: isIPad
                    )
                    
                    SmallActionButton(
                        icon: "keyboard.chevron.compact.down",
                        color: .gray,
                        action: { hideKeyboard() },
                        isIPad: isIPad
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            
            // Text editor - simplified
            TextEditor(text: $viewModel.markdownText)
                .font(.system(size: isIPad ? 17 : 15, design: .monospaced))
                .padding(isIPad ? 16 : 12)
                .background(Color(.systemBackground))
                .scrollContentBackground(.hidden)
                .onTapGesture(count: 2) {
                    hideKeyboard()
                }
                .id(editorScrollTrigger) // 通过改变ID来重置滚动位置
        }
        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 20 : 16))
        .background(
            RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: isIPad ? 12 : 8, x: 0, y: isIPad ? 3 : 2)
    }
    
    private var modernPreviewCard: some View {
        VStack(spacing: 0) {
            // Compact card header
            HStack {
                Label("预览", systemImage: "eye.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            
            // Preview content - simplified
            ScrollView {
                if viewModel.markdownText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        VStack(spacing: 6) {
                            Text("开始编写")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("在编辑器中输入 Markdown 内容\n这里会显示实时预览")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                } else {
                    MarkdownPreviewView(content: viewModel.markdownText)
                        .padding(isIPad ? 20 : 16)
                }
            }
            .background(Color(.systemBackground))
            .id(previewScrollTrigger) // 通过改变ID来重置滚动位置
        }
        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 20 : 16))
        .background(
            RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: isIPad ? 12 : 8, x: 0, y: isIPad ? 3 : 2)
    }
}

// MARK: - Modern UI Components
struct ModernButton: View {
    let icon: String
    let action: () -> Void
    let isDarkMode: Bool
    let isIPad: Bool
    
    private var buttonSize: CGFloat {
        isIPad ? 48 : 40
    }
    
    private var touchAreaSize: CGFloat {
        isIPad ? 60 : 44 // 更大的触摸区域
    }
    
    private var iconSize: CGFloat {
        isIPad ? 20 : 16
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: isIPad ? 10 : 8, x: 0, y: isIPad ? 5 : 4)
        }
        .buttonStyle(PlainButtonStyle()) // 使用Plain样式确保响应
        .frame(width: touchAreaSize, height: touchAreaSize) // 扩大触摸区域
        .contentShape(Circle()) // 确保整个圆形区域都可以点击
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDarkMode)
    }
}

struct SmallActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    let isIPad: Bool
    
    private var buttonSize: CGFloat {
        isIPad ? 34 : 28
    }
    
    private var iconSize: CGFloat {
        isIPad ? 14 : 12
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(color)
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    Circle()
                        .fill(color.opacity(0.12))
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.15), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle()) // 确保响应
        .contentShape(Circle()) // 确保整个圆形区域都可以点击
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: color)
    }
}

struct ModernExportSheet: View {
    let viewModel: SimpleMarkdownViewModel
    @Environment(\.presentationMode) var presentationMode
    @Binding var showingImageExportOptions: Bool
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(spacing: 8) {
                        Text("导出文档")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("选择您需要的导出格式")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 32)
                
                // Export options
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: isIPad ? 24 : 16), count: isIPad ? 3 : 2), spacing: isIPad ? 24 : 16) {
                    ExportOptionCard(
                        icon: "photo.fill",
                        title: "长图",
                        subtitle: "PNG 格式",
                        color: .green,
                        action: {
                            presentationMode.wrappedValue.dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showingImageExportOptions = true
                            }
                        }
                    )
                    
                    ExportOptionCard(
                        icon: "doc.fill",
                        title: "PDF",
                        subtitle: "文档格式",
                        color: .red,
                        action: {
                            viewModel.exportAsPDF()
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                    
                    ExportOptionCard(
                        icon: "doc.text.fill",
                        title: "Word",
                        subtitle: "DOC 格式",
                        color: .blue,
                        action: {
                            viewModel.exportAsWord()
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                    
                    ExportOptionCard(
                        icon: "safari.fill",
                        title: "HTML",
                        subtitle: "网页格式",
                        color: .orange,
                        action: {
                            viewModel.exportAsHTML()
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                    
                    ExportOptionCard(
                        icon: "m.square.fill",
                        title: "Markdown",
                        subtitle: "MD 格式",
                        color: .purple,
                        action: {
                            viewModel.exportAsMarkdown()
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
    }
}

struct ExportOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: color)
    }
}

struct ProjectInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(spacing: 12) {
                            Text("Markdown Export Helper")
                                .font(.system(size: isIPad ? 32 : 24, weight: .bold))
                                .multilineTextAlignment(.center)
                            
                            Text("强大的 Markdown 编辑和导出工具")
                                .font(.system(size: isIPad ? 18 : 16))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Features
                    VStack(spacing: 20) {
                        FeatureRow(
                            icon: "eye.fill",
                            title: "实时预览",
                            description: "即时查看 Markdown 渲染结果"
                        )
                        
                        FeatureRow(
                            icon: "square.and.arrow.up.fill",
                            title: "多格式导出",
                            description: "支持 PNG、PDF、HTML、Word、Markdown"
                        )
                        
                        FeatureRow(
                            icon: "paintbrush.fill",
                            title: "主题切换",
                            description: "支持亮色和暗色主题"
                        )
                        
                        FeatureRow(
                            icon: "clock.fill",
                            title: "历史管理",
                            description: "自动保存编辑历史，支持50条记录"
                        )
                        
                        FeatureRow(
                            icon: "ipad.and.iphone",
                            title: "多设备适配",
                            description: "完美适配 iPhone 和 iPad"
                        )
                    }
                    
                    // GitHub Link
                    VStack(spacing: 16) {
                        Text("开源项目")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Button(action: {
                            if let url = URL(string: "https://github.com/Gigass/MarkdownExportHelperIos") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "link")
                                    .font(.system(size: 18, weight: .semibold))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("GitHub 仓库")
                                        .font(.system(size: 16, weight: .semibold))
                                    
                                    Text("github.com/Gigass/MarkdownExportHelperIos")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.primary)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Footer
                    VStack(spacing: 8) {
                        Text("由 Gigass 开发")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("Version 1.0")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    ContentView()
}
