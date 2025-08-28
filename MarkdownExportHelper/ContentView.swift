//
//  ContentView.swift
//  MarkdownExportHelper
//
//  Created by Gigass on 2025/7/25.
//

import SwiftUI
import PDFKit
import CoreText

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
    @Published var showSaveConfirmation = false
    @Published var showClearConfirmation = false
    @Published var showPasteConfirmation = false
    @Published var showCopyPlainTextConfirmation = false
    
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
        showSaveConfirmation = true
    }
    
    func confirmSaveToHistory() {
        saveToHistory()
        showToast(message: "已保存到历史")
    }
    
    func exportAsImage(completion: @escaping (UIImage?) -> Void) {
        guard !markdownText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showToast(message: "内容为空，无法导出")
            completion(nil)
            return
        }
        
        isExportingImage = true
        print("Starting image export for content length: \(markdownText.count)")
        
        let view = ProfessionalMarkdownPreview(content: self.markdownText)
            .padding(32)
            .background(Color(.systemBackground))
        
        // 使用 DispatchQueue.main.async 延迟执行，避免阻塞当前UI操作
        DispatchQueue.main.async {
            let image = view.renderAsLongImage(width: 750)
            
            self.isExportingImage = false
            
            if let image = image {
                print("Image export successful: \(image.size)")
                completion(image)
            } else {
                print("Image export failed")
                self.showToast(message: "图片生成失败，请尝试减少内容长度")
                completion(nil)
            }
        }
    }
    
    func shareImage(_ image: UIImage) {
        presentActivityViewController(with: [image])
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
        showClearConfirmation = true
    }
    
    func confirmClearContent() {
        markdownText = ""
        showToast(message: "内容已清空")
    }
    
    func pasteFromClipboard() {
        guard UIPasteboard.general.string != nil && !UIPasteboard.general.string!.isEmpty else {
            showToast(message: "剪贴板为空")
            return
        }
        showPasteConfirmation = true
    }
    
    func confirmPasteFromClipboard() {
        if let clipboardContent = UIPasteboard.general.string, !clipboardContent.isEmpty {
            markdownText = clipboardContent
            showToast(message: "已从剪贴板粘贴内容")
        } else {
            showToast(message: "剪贴板为空")
        }
    }
    
    func copyPlainText() {
        showCopyPlainTextConfirmation = true
    }
    
    func confirmCopyPlainText() {
        let plainText = convertMarkdownToPlainText(markdownText)
        UIPasteboard.general.string = plainText
        showToast(message: "已复制纯文本到剪贴板")
    }
    
    private func convertMarkdownToPlainText(_ markdown: String) -> String {
        // 使用新的增强解析器来提取纯文本
        let elements = parseEnhancedMarkdownForPlainText(markdown)
        var plainTextLines: [String] = []
        
        for element in elements {
            switch element.type {
            case .heading, .paragraph, .unorderedList, .orderedList, .quote:
                // 使用 AttributedString 来提取纯文本（已去除所有Markdown标记）
                let plainString = extractPlainTextFromAttributedString(element.formattedContent)
                if !plainString.isEmpty {
                    plainTextLines.append(plainString)
                }
            case .codeBlock:
                // 包含代码块内容，但不包含```标记
                if !element.content.isEmpty {
                    plainTextLines.append(element.content)
                }
            case .horizontalRule:
                // 分割线用简单的文本表示
                plainTextLines.append("---")
            }
        }
        
        return plainTextLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // 专门为纯文本提取使用的解析器
    private func parseEnhancedMarkdownForPlainText(_ text: String) -> [EnhancedMarkdownElement] {
        let lines = text.components(separatedBy: .newlines)
        var elements: [EnhancedMarkdownElement] = []
        var codeBlockContent: [String] = []
        var inCodeBlock = false
        var codeBlockLanguage = ""
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // 处理代码块
            if trimmedLine.hasPrefix("```") {
                if inCodeBlock {
                    // 结束代码块
                    let fullContent = codeBlockContent.joined(separator: "\n")
                    elements.append(EnhancedMarkdownElement(
                        id: index, 
                        type: .codeBlock(language: codeBlockLanguage), 
                        content: fullContent, 
                        formattedContent: AttributedString(fullContent)
                    ))
                    codeBlockContent = []
                    inCodeBlock = false
                    codeBlockLanguage = ""
                } else {
                    // 开始代码块
                    inCodeBlock = true
                    codeBlockLanguage = String(trimmedLine.dropFirst(3))
                }
                continue
            }
            
            if inCodeBlock {
                codeBlockContent.append(line) // 保持原始缩进
                continue
            }
            
            if trimmedLine.isEmpty {
                continue
            } else if trimmedLine.hasPrefix("######") {
                let content = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 6), content: content, formattedContent: createEnhancedAttributedStringForPlainText(content)))
            } else if trimmedLine.hasPrefix("#####") {
                let content = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 5), content: content, formattedContent: createEnhancedAttributedStringForPlainText(content)))
            } else if trimmedLine.hasPrefix("####") {
                let content = String(trimmedLine.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 4), content: content, formattedContent: createEnhancedAttributedStringForPlainText(content)))
            } else if trimmedLine.hasPrefix("###") {
                let content = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 3), content: content, formattedContent: createEnhancedAttributedStringForPlainText(content)))
            } else if trimmedLine.hasPrefix("##") {
                let content = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 2), content: content, formattedContent: createEnhancedAttributedStringForPlainText(content)))
            } else if trimmedLine.hasPrefix("#") {
                let content = String(trimmedLine.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 1), content: content, formattedContent: createEnhancedAttributedStringForPlainText(content)))
            } else if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") || trimmedLine.hasPrefix("+ ") {
                let content = String(trimmedLine.dropFirst(2))
                elements.append(EnhancedMarkdownElement(id: index, type: .unorderedList, content: content, formattedContent: createEnhancedAttributedStringForPlainText(content)))
            } else if let match = trimmedLine.range(of: "^\\d+\\. ", options: .regularExpression) {
                let content = String(trimmedLine[match.upperBound...])
                elements.append(EnhancedMarkdownElement(id: index, type: .orderedList, content: content, formattedContent: createEnhancedAttributedStringForPlainText(content)))
            } else if trimmedLine.hasPrefix("> ") {
                let content = String(trimmedLine.dropFirst(2))
                elements.append(EnhancedMarkdownElement(id: index, type: .quote, content: content, formattedContent: createEnhancedAttributedStringForPlainText(content)))
            } else if trimmedLine == "---" || trimmedLine == "***" || trimmedLine == "___" {
                elements.append(EnhancedMarkdownElement(id: index, type: .horizontalRule, content: "", formattedContent: AttributedString("")))
            } else {
                elements.append(EnhancedMarkdownElement(id: index, type: .paragraph, content: trimmedLine, formattedContent: createEnhancedAttributedStringForPlainText(trimmedLine)))
            }
        }
        
        return elements
    }
    
    // 为纯文本提取创建AttributedString
    private func createEnhancedAttributedStringForPlainText(_ text: String) -> AttributedString {
        do {
            let attributedString = try AttributedString(markdown: text, options: .init(interpretedSyntax: .full))
            return attributedString
        } catch {
            return AttributedString(text)
        }
    }
    
    private func extractPlainTextFromAttributedString(_ attributedString: AttributedString) -> String {
        // AttributedString 的字符序列就是纯文本
        return String(attributedString.characters)
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
        guard !markdownText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showToast(message: "内容为空，无法导出")
            return
        }
        
        // Save to history when exporting
        saveToHistory()
        
        isExportingImage = true
        print("Starting editable PDF export for content length: \(markdownText.count)")
        
        DispatchQueue.main.async {
            let pdfData = self.createEditablePDF()
            
            self.isExportingImage = false
            self.savePDFToFiles(data: pdfData)
            self.showToast(message: "可编辑PDF已生成")
            print("Editable PDF export completed")
        }
    }
    
    private func createEditablePDF() -> Data {
        let a4Width: CGFloat = 595 // A4纸的宽度 (点数)
        let a4Height: CGFloat = 842 // A4纸的高度 (点数)
        let margin: CGFloat = 50 // 页边距
        let contentWidth = a4Width - margin * 2
        let contentHeight = a4Height - margin * 2
        
        // 使用新的增强解析器解析Markdown内容
        let elements = parseEnhancedMarkdownForPDF(markdownText)
        print("PDF Generation - Enhanced elements count: \(elements.count)")
        
        // 使用 UIGraphicsPDFRenderer 创建可编辑的PDF
        let pdfData = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: a4Width, height: a4Height)).pdfData { context in
            var currentY: CGFloat = margin
            var pageNumber = 1
            
            context.beginPage()
            print("PDF Generation - Started page \(pageNumber)")
            
            // 添加测试内容确保PDF不为空
            if elements.isEmpty {
                let testText = "PDF生成测试内容"
                let testAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16),
                    .foregroundColor: UIColor.black
                ]
                let testAttributedString = NSAttributedString(string: testText, attributes: testAttributes)
                UIGraphicsPushContext(context.cgContext)
                testAttributedString.draw(at: CGPoint(x: margin, y: margin))
                UIGraphicsPopContext()
                print("PDF Generation - Added test content")
                return
            }
            
            for (index, element) in elements.enumerated() {
                let elementHeight = estimateEnhancedElementHeight(element, width: contentWidth)
                print("PDF Generation - Enhanced element \(index): \(element.type), height: \(elementHeight)")
                
                // 检查是否需要新页面
                if currentY + elementHeight > contentHeight + margin {
                    // 开始新页面
                    context.beginPage()
                    currentY = margin
                    pageNumber += 1
                    print("PDF Generation - Started page \(pageNumber)")
                }
                
                // 渲染元素到PDF
                print("PDF Generation - Rendering enhanced element at y: \(currentY)")
                renderEnhancedElementToPDF(element: element, 
                                         context: context.cgContext, 
                                         rect: CGRect(x: margin, y: currentY, width: contentWidth, height: elementHeight))
                
                currentY += elementHeight + 15 // 增加元素间距
            }
            
            print("PDF Generation - Completed with \(pageNumber) pages")
        }
        
        return pdfData
    }
    
    // 专门为PDF使用的增强解析器（复用预览逻辑）
    private func parseEnhancedMarkdownForPDF(_ text: String) -> [EnhancedMarkdownElement] {
        let lines = text.components(separatedBy: .newlines)
        var elements: [EnhancedMarkdownElement] = []
        var codeBlockContent: [String] = []
        var inCodeBlock = false
        var codeBlockLanguage = ""
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // 处理代码块
            if trimmedLine.hasPrefix("```") {
                if inCodeBlock {
                    // 结束代码块
                    let fullContent = codeBlockContent.joined(separator: "\n")
                    elements.append(EnhancedMarkdownElement(
                        id: index, 
                        type: .codeBlock(language: codeBlockLanguage), 
                        content: fullContent, 
                        formattedContent: AttributedString(fullContent)
                    ))
                    codeBlockContent = []
                    inCodeBlock = false
                    codeBlockLanguage = ""
                } else {
                    // 开始代码块
                    inCodeBlock = true
                    codeBlockLanguage = String(trimmedLine.dropFirst(3))
                }
                continue
            }
            
            if inCodeBlock {
                codeBlockContent.append(line) // 保持原始缩进
                continue
            }
            
            if trimmedLine.isEmpty {
                continue
            } else if trimmedLine.hasPrefix("######") {
                let content = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 6), content: content, formattedContent: createEnhancedAttributedStringForPDF(content)))
            } else if trimmedLine.hasPrefix("#####") {
                let content = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 5), content: content, formattedContent: createEnhancedAttributedStringForPDF(content)))
            } else if trimmedLine.hasPrefix("####") {
                let content = String(trimmedLine.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 4), content: content, formattedContent: createEnhancedAttributedStringForPDF(content)))
            } else if trimmedLine.hasPrefix("###") {
                let content = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 3), content: content, formattedContent: createEnhancedAttributedStringForPDF(content)))
            } else if trimmedLine.hasPrefix("##") {
                let content = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 2), content: content, formattedContent: createEnhancedAttributedStringForPDF(content)))
            } else if trimmedLine.hasPrefix("#") {
                let content = String(trimmedLine.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 1), content: content, formattedContent: createEnhancedAttributedStringForPDF(content)))
            } else if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") || trimmedLine.hasPrefix("+ ") {
                let content = String(trimmedLine.dropFirst(2))
                elements.append(EnhancedMarkdownElement(id: index, type: .unorderedList, content: content, formattedContent: createEnhancedAttributedStringForPDF(content)))
            } else if let match = trimmedLine.range(of: "^\\d+\\. ", options: .regularExpression) {
                let content = String(trimmedLine[match.upperBound...])
                elements.append(EnhancedMarkdownElement(id: index, type: .orderedList, content: content, formattedContent: createEnhancedAttributedStringForPDF(content)))
            } else if trimmedLine.hasPrefix("> ") {
                let content = String(trimmedLine.dropFirst(2))
                elements.append(EnhancedMarkdownElement(id: index, type: .quote, content: content, formattedContent: createEnhancedAttributedStringForPDF(content)))
            } else if trimmedLine == "---" || trimmedLine == "***" || trimmedLine == "___" {
                elements.append(EnhancedMarkdownElement(id: index, type: .horizontalRule, content: "", formattedContent: AttributedString("")))
            } else {
                elements.append(EnhancedMarkdownElement(id: index, type: .paragraph, content: trimmedLine, formattedContent: createEnhancedAttributedStringForPDF(trimmedLine)))
            }
        }
        
        return elements
    }
    
    // 为PDF创建增强的AttributedString
    private func createEnhancedAttributedStringForPDF(_ text: String) -> AttributedString {
        // 使用完整的markdown语法支持
        do {
            let attributedString = try AttributedString(markdown: text, options: .init(interpretedSyntax: .full))
            return attributedString
        } catch {
            // 如果解析失败，返回原始文本
            return AttributedString(text)
        }
    }
    
    
    // 增强版元素高度估算
    private func estimateEnhancedElementHeight(_ element: EnhancedMarkdownElement, width: CGFloat) -> CGFloat {
        let font: UIFont
        switch element.type {
        case .heading(let level):
            switch level {
            case 1: font = UIFont.boldSystemFont(ofSize: 24)
            case 2: font = UIFont.boldSystemFont(ofSize: 20)
            case 3: font = UIFont.boldSystemFont(ofSize: 18)
            case 4: font = UIFont.boldSystemFont(ofSize: 16)
            case 5: font = UIFont.boldSystemFont(ofSize: 14)
            default: font = UIFont.boldSystemFont(ofSize: 12) // level 6
            }
        case .paragraph, .unorderedList, .orderedList, .quote:
            font = UIFont.systemFont(ofSize: 16)
        case .codeBlock:
            font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        case .horizontalRule:
            return 30 // 固定高度
        }
        
        // 确保文本不为空
        let textToMeasure = element.content.isEmpty ? " " : element.content
        
        let textSize = textToMeasure.boundingRect(
            with: CGSize(width: width - 20, height: .greatestFiniteMagnitude), // 减去一些边距
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        
        return max(ceil(textSize.height) + 20, 40) // 增加更多的间距和最小高度
    }
    
    // 增强版PDF元素渲染
    private func renderEnhancedElementToPDF(element: EnhancedMarkdownElement, context: CGContext, rect: CGRect) {
        print("Rendering enhanced element: '\(element.content)' in rect: \(rect)")
        
        switch element.type {
        case .heading(let level):
            let font: UIFont
            switch level {
            case 1: font = UIFont.boldSystemFont(ofSize: 24)
            case 2: font = UIFont.boldSystemFont(ofSize: 20)
            case 3: font = UIFont.boldSystemFont(ofSize: 18)
            case 4: font = UIFont.boldSystemFont(ofSize: 16)
            case 5: font = UIFont.boldSystemFont(ofSize: 14)
            default: font = UIFont.boldSystemFont(ofSize: 12) // level 6
            }
            drawEnhancedFormattedText(element, baseFont: font, rect: rect, context: context)
            
        case .paragraph:
            drawEnhancedFormattedText(element, baseFont: UIFont.systemFont(ofSize: 16), rect: rect, context: context)
            
        case .unorderedList:
            let bulletPoint = "• "
            drawEnhancedBulletListItem(element, bulletPoint: bulletPoint, baseFont: UIFont.systemFont(ofSize: 16), rect: rect, context: context)
            
        case .orderedList:
            let bulletPoint = "▪ " // 使用不同的符号区分有序列表
            drawEnhancedBulletListItem(element, bulletPoint: bulletPoint, baseFont: UIFont.systemFont(ofSize: 16), rect: rect, context: context)
            
        case .quote:
            drawEnhancedFormattedText(element, baseFont: UIFont.italicSystemFont(ofSize: 16), rect: rect, context: context)
            // 绘制左侧引用线
            context.setStrokeColor(UIColor.blue.cgColor)
            context.setLineWidth(3)
            context.move(to: CGPoint(x: rect.minX - 10, y: rect.minY))
            context.addLine(to: CGPoint(x: rect.minX - 10, y: rect.maxY))
            context.strokePath()
            
        case .codeBlock:
            context.setFillColor(UIColor.lightGray.cgColor)
            context.fill(rect.insetBy(dx: -5, dy: -5))
            drawPlainTextToPDF(element.content.isEmpty ? "[空内容]" : element.content, 
                              font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                              color: .black, rect: rect, context: context)
            
        case .horizontalRule:
            // 绘制水平分割线
            context.setStrokeColor(UIColor.systemGray.cgColor)
            context.setLineWidth(1)
            let lineY = rect.midY
            context.move(to: CGPoint(x: rect.minX, y: lineY))
            context.addLine(to: CGPoint(x: rect.maxX, y: lineY))
            context.strokePath()
        }
    }
    
    private func drawEnhancedFormattedText(_ element: EnhancedMarkdownElement, baseFont: UIFont, rect: CGRect, context: CGContext) {
        // 直接使用element.formattedContent，它已经处理了所有Markdown格式
        let attributedString = NSAttributedString(element.formattedContent)
        
        // 调整基础字体大小以匹配PDF输出
        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
        let range = NSRange(location: 0, length: mutableAttributedString.length)
        
        // 设置基础字体大小，保持原有的格式（粗体、斜体等）
        mutableAttributedString.enumerateAttribute(.font, in: range, options: []) { (fontValue, range, _) in
            if let currentFont = fontValue as? UIFont {
                let newFont: UIFont
                if currentFont.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    newFont = UIFont.boldSystemFont(ofSize: baseFont.pointSize)
                } else if currentFont.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    newFont = UIFont.italicSystemFont(ofSize: baseFont.pointSize)
                } else {
                    newFont = baseFont
                }
                mutableAttributedString.addAttribute(.font, value: newFont, range: range)
            } else {
                mutableAttributedString.addAttribute(.font, value: baseFont, range: range)
            }
        }
        
        // 确保颜色为黑色
        mutableAttributedString.addAttribute(.foregroundColor, value: UIColor.black, range: range)
        
        UIGraphicsPushContext(context)
        mutableAttributedString.draw(in: rect)
        UIGraphicsPopContext()
    }
    
    private func drawEnhancedBulletListItem(_ element: EnhancedMarkdownElement, bulletPoint: String, baseFont: UIFont, rect: CGRect, context: CGContext) {
        // 为列表项添加项目符号，然后使用formattedContent
        let bulletAttributedString = NSMutableAttributedString(string: bulletPoint, attributes: [
            .font: baseFont,
            .foregroundColor: UIColor.black
        ])
        
        let contentAttributedString = NSMutableAttributedString(attributedString: NSAttributedString(element.formattedContent))
        
        // 调整内容的字体大小
        let range = NSRange(location: 0, length: contentAttributedString.length)
        contentAttributedString.enumerateAttribute(.font, in: range, options: []) { (fontValue, range, _) in
            if let currentFont = fontValue as? UIFont {
                let newFont: UIFont
                if currentFont.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    newFont = UIFont.boldSystemFont(ofSize: baseFont.pointSize)
                } else if currentFont.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    newFont = UIFont.italicSystemFont(ofSize: baseFont.pointSize)
                } else {
                    newFont = baseFont
                }
                contentAttributedString.addAttribute(.font, value: newFont, range: range)
            } else {
                contentAttributedString.addAttribute(.font, value: baseFont, range: range)
            }
        }
        contentAttributedString.addAttribute(.foregroundColor, value: UIColor.black, range: range)
        
        bulletAttributedString.append(contentAttributedString)
        
        UIGraphicsPushContext(context)
        bulletAttributedString.draw(in: rect)
        UIGraphicsPopContext()
    }
    
    private func drawPlainTextToPDF(_ text: String, font: UIFont, color: UIColor, rect: CGRect, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        UIGraphicsPushContext(context)
        attributedString.draw(in: rect)
        UIGraphicsPopContext()
    }
    
    
    
    
    
    
    private func savePDFToFiles(data: Data) {
        // 创建一个自定义的活动项提供器
        let activityItem = PDFActivityItemProvider(pdfData: data)
        presentActivityViewController(with: [activityItem])
        showToast(message: "PDF 已生成")
    }
    
    private func presentActivityViewController(with items: [Any]) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                self.showToast(message: "无法打开分享界面")
                return
            }
            
            let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
            
            // 确保包含常用的分享应用和保存选项
            activityViewController.excludedActivityTypes = [
                .assignToContact,
                .addToReadingList,
                .openInIBooks
            ]
            
            // iPad支持
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityViewController.popoverPresentationController?.sourceView = rootViewController.view
                activityViewController.popoverPresentationController?.sourceRect = CGRect(
                    x: rootViewController.view.bounds.midX,
                    y: rootViewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                activityViewController.popoverPresentationController?.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true, completion: nil)
        }
    }
    
    func exportAsHTML() {
        // Save to history when exporting
        saveToHistory()
        
        let htmlContent = convertMarkdownToHTML(markdownText)
        let fileName = "Markdown_Export_\(Date().timeIntervalSince1970).html"
        let activityItem = TextActivityItemProvider(text: htmlContent, fileName: fileName, mimeType: "text/html")
        
        presentActivityViewController(with: [activityItem])
        showToast(message: "HTML 文件已生成")
    }
    
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        // 使用新的增强解析器解析Markdown内容
        let elements = parseEnhancedMarkdownForHTML(markdown)
        var htmlContent: [String] = []
        var inUnorderedList = false
        var inOrderedList = false
        
        for element in elements {
            switch element.type {
            case .heading(let level):
                // 关闭任何开放的列表
                if inUnorderedList {
                    htmlContent.append("</ul>")
                    inUnorderedList = false
                }
                if inOrderedList {
                    htmlContent.append("</ol>")
                    inOrderedList = false
                }
                
                let plainText = extractPlainTextFromAttributedString(element.formattedContent)
                htmlContent.append("<h\(level)>\(escapeHTML(plainText))</h\(level)>")
                
            case .paragraph:
                // 关闭任何开放的列表
                if inUnorderedList {
                    htmlContent.append("</ul>")
                    inUnorderedList = false
                }
                if inOrderedList {
                    htmlContent.append("</ol>")
                    inOrderedList = false
                }
                
                let htmlText = convertAttributedStringToHTML(element.formattedContent)
                htmlContent.append("<p>\(htmlText)</p>")
                
            case .unorderedList:
                if !inUnorderedList {
                    if inOrderedList {
                        htmlContent.append("</ol>")
                        inOrderedList = false
                    }
                    htmlContent.append("<ul>")
                    inUnorderedList = true
                }
                let htmlText = convertAttributedStringToHTML(element.formattedContent)
                htmlContent.append("<li>\(htmlText)</li>")
                
            case .orderedList:
                if !inOrderedList {
                    if inUnorderedList {
                        htmlContent.append("</ul>")
                        inUnorderedList = false
                    }
                    htmlContent.append("<ol>")
                    inOrderedList = true
                }
                let htmlText = convertAttributedStringToHTML(element.formattedContent)
                htmlContent.append("<li>\(htmlText)</li>")
                
            case .quote:
                // 关闭任何开放的列表
                if inUnorderedList {
                    htmlContent.append("</ul>")
                    inUnorderedList = false
                }
                if inOrderedList {
                    htmlContent.append("</ol>")
                    inOrderedList = false
                }
                
                let htmlText = convertAttributedStringToHTML(element.formattedContent)
                htmlContent.append("<blockquote>\(htmlText)</blockquote>")
                
            case .codeBlock:
                // 关闭任何开放的列表
                if inUnorderedList {
                    htmlContent.append("</ul>")
                    inUnorderedList = false
                }
                if inOrderedList {
                    htmlContent.append("</ol>")
                    inOrderedList = false
                }
                
                htmlContent.append("<pre><code>\(escapeHTML(element.content))</code></pre>")
                
            case .horizontalRule:
                // 关闭任何开放的列表
                if inUnorderedList {
                    htmlContent.append("</ul>")
                    inUnorderedList = false
                }
                if inOrderedList {
                    htmlContent.append("</ol>")
                    inOrderedList = false
                }
                
                htmlContent.append("<hr>")
            }
        }
        
        // 关闭任何仍然开放的列表
        if inUnorderedList {
            htmlContent.append("</ul>")
        }
        if inOrderedList {
            htmlContent.append("</ol>")
        }
        
        let bodyContent = htmlContent.joined(separator: "\n")
        
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
                h1, h2, h3, h4, h5, h6 {
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
                h4 {
                    font-size: 1.1em;
                }
                h5 {
                    font-size: 1em;
                    font-weight: 600;
                }
                h6 {
                    font-size: 0.9em;
                    font-weight: 600;
                }
                code {
                    background-color: #f4f4f4;
                    padding: 2px 4px;
                    border-radius: 3px;
                    font-family: Monaco, 'Courier New', monospace;
                }
                pre {
                    background-color: #f4f4f4;
                    padding: 16px;
                    border-radius: 6px;
                    overflow-x: auto;
                }
                pre code {
                    background: none;
                    padding: 0;
                }
                blockquote {
                    border-left: 4px solid #ddd;
                    margin: 0 0 16px 0;
                    padding-left: 16px;
                    color: #666;
                    font-style: italic;
                }
                ul, ol {
                    padding-left: 20px;
                    margin-bottom: 16px;
                }
                li {
                    margin-bottom: 4px;
                }
                p {
                    margin-bottom: 16px;
                }
                hr {
                    border: none;
                    border-top: 1px solid #ddd;
                    margin: 24px 0;
                }
                strong {
                    font-weight: 600;
                }
                em {
                    font-style: italic;
                }
            </style>
        </head>
        <body>
        \(bodyContent)
        </body>
        </html>
        """
    }
    
    // 专门为HTML使用的增强解析器
    private func parseEnhancedMarkdownForHTML(_ text: String) -> [EnhancedMarkdownElement] {
        let lines = text.components(separatedBy: .newlines)
        var elements: [EnhancedMarkdownElement] = []
        var codeBlockContent: [String] = []
        var inCodeBlock = false
        var codeBlockLanguage = ""
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // 处理代码块
            if trimmedLine.hasPrefix("```") {
                if inCodeBlock {
                    // 结束代码块
                    let fullContent = codeBlockContent.joined(separator: "\n")
                    elements.append(EnhancedMarkdownElement(
                        id: index, 
                        type: .codeBlock(language: codeBlockLanguage), 
                        content: fullContent, 
                        formattedContent: AttributedString(fullContent)
                    ))
                    codeBlockContent = []
                    inCodeBlock = false
                    codeBlockLanguage = ""
                } else {
                    // 开始代码块
                    inCodeBlock = true
                    codeBlockLanguage = String(trimmedLine.dropFirst(3))
                }
                continue
            }
            
            if inCodeBlock {
                codeBlockContent.append(line) // 保持原始缩进
                continue
            }
            
            if trimmedLine.isEmpty {
                continue
            } else if trimmedLine.hasPrefix("######") {
                let content = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 6), content: content, formattedContent: createEnhancedAttributedStringForHTML(content)))
            } else if trimmedLine.hasPrefix("#####") {
                let content = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 5), content: content, formattedContent: createEnhancedAttributedStringForHTML(content)))
            } else if trimmedLine.hasPrefix("####") {
                let content = String(trimmedLine.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 4), content: content, formattedContent: createEnhancedAttributedStringForHTML(content)))
            } else if trimmedLine.hasPrefix("###") {
                let content = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 3), content: content, formattedContent: createEnhancedAttributedStringForHTML(content)))
            } else if trimmedLine.hasPrefix("##") {
                let content = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 2), content: content, formattedContent: createEnhancedAttributedStringForHTML(content)))
            } else if trimmedLine.hasPrefix("#") {
                let content = String(trimmedLine.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 1), content: content, formattedContent: createEnhancedAttributedStringForHTML(content)))
            } else if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") || trimmedLine.hasPrefix("+ ") {
                let content = String(trimmedLine.dropFirst(2))
                elements.append(EnhancedMarkdownElement(id: index, type: .unorderedList, content: content, formattedContent: createEnhancedAttributedStringForHTML(content)))
            } else if let match = trimmedLine.range(of: "^\\d+\\. ", options: .regularExpression) {
                let content = String(trimmedLine[match.upperBound...])
                elements.append(EnhancedMarkdownElement(id: index, type: .orderedList, content: content, formattedContent: createEnhancedAttributedStringForHTML(content)))
            } else if trimmedLine.hasPrefix("> ") {
                let content = String(trimmedLine.dropFirst(2))
                elements.append(EnhancedMarkdownElement(id: index, type: .quote, content: content, formattedContent: createEnhancedAttributedStringForHTML(content)))
            } else if trimmedLine == "---" || trimmedLine == "***" || trimmedLine == "___" {
                elements.append(EnhancedMarkdownElement(id: index, type: .horizontalRule, content: "", formattedContent: AttributedString("")))
            } else {
                elements.append(EnhancedMarkdownElement(id: index, type: .paragraph, content: trimmedLine, formattedContent: createEnhancedAttributedStringForHTML(trimmedLine)))
            }
        }
        
        return elements
    }
    
    // 为HTML创建增强的AttributedString
    private func createEnhancedAttributedStringForHTML(_ text: String) -> AttributedString {
        // 使用完整的markdown语法支持
        do {
            let attributedString = try AttributedString(markdown: text, options: .init(interpretedSyntax: .full))
            return attributedString
        } catch {
            // 如果解析失败，返回原始文本
            return AttributedString(text)
        }
    }
    
    // 将AttributedString转换为HTML标记
    private func convertAttributedStringToHTML(_ attributedString: AttributedString) -> String {
        // 简化实现：直接提取纯文本并转换常见格式
        let plainText = extractPlainTextFromAttributedString(attributedString)
        
        // 使用简单的正则表达式转换基本格式
        var htmlText = escapeHTML(plainText)
        
        // 转换粗体
        htmlText = htmlText.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        
        // 转换斜体
        htmlText = htmlText.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
        
        // 转换行内代码
        htmlText = htmlText.replacingOccurrences(of: "`(.+?)`", with: "<code>$1</code>", options: .regularExpression)
        
        return htmlText
    }
    
    // HTML转义
    private func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    func exportAsMarkdown() {
        // Save to history when exporting
        saveToHistory()
        
        let fileName = "Markdown_Export_\(Date().timeIntervalSince1970).md"
        let activityItem = TextActivityItemProvider(text: markdownText, fileName: fileName, mimeType: "text/markdown")
        
        presentActivityViewController(with: [activityItem])
        showToast(message: "Markdown 文件已生成")
    }
    
    func exportAsWord() {
        // Save to history when exporting
        saveToHistory()
        
        let wordContent = convertMarkdownToWordHTML(markdownText)
        let fileName = "Markdown_Export_\(Date().timeIntervalSince1970).doc"
        let activityItem = TextActivityItemProvider(text: wordContent, fileName: fileName, mimeType: "application/msword")
        
        presentActivityViewController(with: [activityItem])
        showToast(message: "Word 文档已生成")
    }
    
    private func convertMarkdownToWordHTML(_ markdown: String) -> String {
        // 使用新的增强解析器解析Markdown内容
        let elements = parseEnhancedMarkdownForWord(markdown)
        var htmlContent: [String] = []
        var inUnorderedList = false
        var inOrderedList = false
        
        for element in elements {
            switch element.type {
            case .heading(let level):
                // 关闭任何开放的列表
                if inUnorderedList {
                    htmlContent.append("</ul>")
                    inUnorderedList = false
                }
                if inOrderedList {
                    htmlContent.append("</ol>")
                    inOrderedList = false
                }
                
                let plainText = extractPlainTextFromAttributedString(element.formattedContent)
                htmlContent.append("<h\(level)>\(escapeHTML(plainText))</h\(level)>")
                
            case .paragraph:
                // 关闭任何开放的列表
                if inUnorderedList {
                    htmlContent.append("</ul>")
                    inUnorderedList = false
                }
                if inOrderedList {
                    htmlContent.append("</ol>")
                    inOrderedList = false
                }
                
                let htmlText = convertAttributedStringToHTML(element.formattedContent)
                htmlContent.append("<p>\(htmlText)</p>")
                
            case .unorderedList:
                if !inUnorderedList {
                    if inOrderedList {
                        htmlContent.append("</ol>")
                        inOrderedList = false
                    }
                    htmlContent.append("<ul>")
                    inUnorderedList = true
                }
                let htmlText = convertAttributedStringToHTML(element.formattedContent)
                htmlContent.append("<li>\(htmlText)</li>")
                
            case .orderedList:
                if !inOrderedList {
                    if inUnorderedList {
                        htmlContent.append("</ul>")
                        inUnorderedList = false
                    }
                    htmlContent.append("<ol>")
                    inOrderedList = true
                }
                let htmlText = convertAttributedStringToHTML(element.formattedContent)
                htmlContent.append("<li>\(htmlText)</li>")
                
            case .quote:
                // 关闭任何开放的列表
                if inUnorderedList {
                    htmlContent.append("</ul>")
                    inUnorderedList = false
                }
                if inOrderedList {
                    htmlContent.append("</ol>")
                    inOrderedList = false
                }
                
                let htmlText = convertAttributedStringToHTML(element.formattedContent)
                htmlContent.append("<blockquote>\(htmlText)</blockquote>")
                
            case .codeBlock:
                // 关闭任何开放的列表
                if inUnorderedList {
                    htmlContent.append("</ul>")
                    inUnorderedList = false
                }
                if inOrderedList {
                    htmlContent.append("</ol>")
                    inOrderedList = false
                }
                
                htmlContent.append("<pre><code>\(escapeHTML(element.content))</code></pre>")
                
            case .horizontalRule:
                // 关闭任何开放的列表
                if inUnorderedList {
                    htmlContent.append("</ul>")
                    inUnorderedList = false
                }
                if inOrderedList {
                    htmlContent.append("</ol>")
                    inOrderedList = false
                }
                
                htmlContent.append("<hr>")
            }
        }
        
        // 关闭任何仍然开放的列表
        if inUnorderedList {
            htmlContent.append("</ul>")
        }
        if inOrderedList {
            htmlContent.append("</ol>")
        }
        
        let bodyContent = htmlContent.joined(separator: "\n")
        
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
                
                h1, h2, h3, h4, h5, h6 {
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
                
                h4 {
                    font-size: 18px;
                    color: #34495e;
                }
                
                h5 {
                    font-size: 16px;
                    color: #34495e;
                    font-weight: 600;
                }
                
                h6 {
                    font-size: 14px;
                    color: #34495e;
                    font-weight: 600;
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
                
                ul, ol {
                    margin: 16px 0;
                    padding-left: 24px;
                }
                
                pre {
                    background-color: #f8f9fa;
                    padding: 16px;
                    border-radius: 6px;
                    overflow-x: auto;
                    border: 1px solid #e1e4e8;
                }
                
                pre code {
                    background: none;
                    padding: 0;
                    border: none;
                }
                
                hr {
                    border: none;
                    border-top: 1px solid #ddd;
                    margin: 24px 0;
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
    
    // 专门为Word使用的增强解析器
    private func parseEnhancedMarkdownForWord(_ text: String) -> [EnhancedMarkdownElement] {
        let lines = text.components(separatedBy: .newlines)
        var elements: [EnhancedMarkdownElement] = []
        var codeBlockContent: [String] = []
        var inCodeBlock = false
        var codeBlockLanguage = ""
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // 处理代码块
            if trimmedLine.hasPrefix("```") {
                if inCodeBlock {
                    // 结束代码块
                    let fullContent = codeBlockContent.joined(separator: "\n")
                    elements.append(EnhancedMarkdownElement(
                        id: index, 
                        type: .codeBlock(language: codeBlockLanguage), 
                        content: fullContent, 
                        formattedContent: AttributedString(fullContent)
                    ))
                    codeBlockContent = []
                    inCodeBlock = false
                    codeBlockLanguage = ""
                } else {
                    // 开始代码块
                    inCodeBlock = true
                    codeBlockLanguage = String(trimmedLine.dropFirst(3))
                }
                continue
            }
            
            if inCodeBlock {
                codeBlockContent.append(line) // 保持原始缩进
                continue
            }
            
            if trimmedLine.isEmpty {
                continue
            } else if trimmedLine.hasPrefix("######") {
                let content = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 6), content: content, formattedContent: createEnhancedAttributedStringForWord(content)))
            } else if trimmedLine.hasPrefix("#####") {
                let content = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 5), content: content, formattedContent: createEnhancedAttributedStringForWord(content)))
            } else if trimmedLine.hasPrefix("####") {
                let content = String(trimmedLine.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 4), content: content, formattedContent: createEnhancedAttributedStringForWord(content)))
            } else if trimmedLine.hasPrefix("###") {
                let content = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 3), content: content, formattedContent: createEnhancedAttributedStringForWord(content)))
            } else if trimmedLine.hasPrefix("##") {
                let content = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 2), content: content, formattedContent: createEnhancedAttributedStringForWord(content)))
            } else if trimmedLine.hasPrefix("#") {
                let content = String(trimmedLine.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 1), content: content, formattedContent: createEnhancedAttributedStringForWord(content)))
            } else if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") || trimmedLine.hasPrefix("+ ") {
                let content = String(trimmedLine.dropFirst(2))
                elements.append(EnhancedMarkdownElement(id: index, type: .unorderedList, content: content, formattedContent: createEnhancedAttributedStringForWord(content)))
            } else if let match = trimmedLine.range(of: "^\\d+\\. ", options: .regularExpression) {
                let content = String(trimmedLine[match.upperBound...])
                elements.append(EnhancedMarkdownElement(id: index, type: .orderedList, content: content, formattedContent: createEnhancedAttributedStringForWord(content)))
            } else if trimmedLine.hasPrefix("> ") {
                let content = String(trimmedLine.dropFirst(2))
                elements.append(EnhancedMarkdownElement(id: index, type: .quote, content: content, formattedContent: createEnhancedAttributedStringForWord(content)))
            } else if trimmedLine == "---" || trimmedLine == "***" || trimmedLine == "___" {
                elements.append(EnhancedMarkdownElement(id: index, type: .horizontalRule, content: "", formattedContent: AttributedString("")))
            } else {
                elements.append(EnhancedMarkdownElement(id: index, type: .paragraph, content: trimmedLine, formattedContent: createEnhancedAttributedStringForWord(trimmedLine)))
            }
        }
        
        return elements
    }
    
    // 为Word创建增强的AttributedString
    private func createEnhancedAttributedStringForWord(_ text: String) -> AttributedString {
        // 使用完整的markdown语法支持
        do {
            let attributedString = try AttributedString(markdown: text, options: .init(interpretedSyntax: .full))
            return attributedString
        } catch {
            // 如果解析失败，返回原始文本
            return AttributedString(text)
        }
    }
    
    private func showToast(message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showToast = false
        }
    }
}


// MARK: - 专业Markdown预览组件（改进版本）
struct ProfessionalMarkdownPreview: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("在左侧编辑器中输入Markdown内容...")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // 使用增强版的markdown解析器
                ForEach(parseEnhancedMarkdown(content), id: \.id) { element in
                    renderEnhancedElement(element)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // 增强版Markdown解析器 - 支持更多格式
    private func parseEnhancedMarkdown(_ text: String) -> [EnhancedMarkdownElement] {
        let lines = text.components(separatedBy: .newlines)
        var elements: [EnhancedMarkdownElement] = []
        var codeBlockContent: [String] = []
        var inCodeBlock = false
        var codeBlockLanguage = ""
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // 处理代码块
            if trimmedLine.hasPrefix("```") {
                if inCodeBlock {
                    // 结束代码块
                    let fullContent = codeBlockContent.joined(separator: "\n")
                    elements.append(EnhancedMarkdownElement(
                        id: index, 
                        type: .codeBlock(language: codeBlockLanguage), 
                        content: fullContent, 
                        formattedContent: AttributedString(fullContent)
                    ))
                    codeBlockContent = []
                    inCodeBlock = false
                    codeBlockLanguage = ""
                } else {
                    // 开始代码块
                    inCodeBlock = true
                    codeBlockLanguage = String(trimmedLine.dropFirst(3))
                }
                continue
            }
            
            if inCodeBlock {
                codeBlockContent.append(line) // 保持原始缩进
                continue
            }
            
            if trimmedLine.isEmpty {
                continue
            } else if trimmedLine.hasPrefix("######") {
                let content = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 6), content: content, formattedContent: createEnhancedAttributedString(content)))
            } else if trimmedLine.hasPrefix("#####") {
                let content = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 5), content: content, formattedContent: createEnhancedAttributedString(content)))
            } else if trimmedLine.hasPrefix("####") {
                let content = String(trimmedLine.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 4), content: content, formattedContent: createEnhancedAttributedString(content)))
            } else if trimmedLine.hasPrefix("###") {
                let content = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 3), content: content, formattedContent: createEnhancedAttributedString(content)))
            } else if trimmedLine.hasPrefix("##") {
                let content = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 2), content: content, formattedContent: createEnhancedAttributedString(content)))
            } else if trimmedLine.hasPrefix("#") {
                let content = String(trimmedLine.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                elements.append(EnhancedMarkdownElement(id: index, type: .heading(level: 1), content: content, formattedContent: createEnhancedAttributedString(content)))
            } else if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") || trimmedLine.hasPrefix("+ ") {
                let content = String(trimmedLine.dropFirst(2))
                elements.append(EnhancedMarkdownElement(id: index, type: .unorderedList, content: content, formattedContent: createEnhancedAttributedString(content)))
            } else if let match = trimmedLine.range(of: "^\\d+\\. ", options: .regularExpression) {
                let content = String(trimmedLine[match.upperBound...])
                elements.append(EnhancedMarkdownElement(id: index, type: .orderedList, content: content, formattedContent: createEnhancedAttributedString(content)))
            } else if trimmedLine.hasPrefix("> ") {
                let content = String(trimmedLine.dropFirst(2))
                elements.append(EnhancedMarkdownElement(id: index, type: .quote, content: content, formattedContent: createEnhancedAttributedString(content)))
            } else if trimmedLine == "---" || trimmedLine == "***" || trimmedLine == "___" {
                elements.append(EnhancedMarkdownElement(id: index, type: .horizontalRule, content: "", formattedContent: AttributedString("")))
            } else {
                elements.append(EnhancedMarkdownElement(id: index, type: .paragraph, content: trimmedLine, formattedContent: createEnhancedAttributedString(trimmedLine)))
            }
        }
        
        return elements
    }
    
    // 更完善的AttributedString创建
    private func createEnhancedAttributedString(_ text: String) -> AttributedString {
        // 使用完整的markdown语法支持
        do {
            let attributedString = try AttributedString(markdown: text, options: .init(interpretedSyntax: .full))
            return attributedString
        } catch {
            // 如果解析失败，返回原始文本
            return AttributedString(text)
        }
    }
    
    @ViewBuilder
    private func renderEnhancedElement(_ element: EnhancedMarkdownElement) -> some View {
        switch element.type {
        case .heading(let level):
            switch level {
            case 1:
                Text(element.formattedContent)
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
            case 2:
                Text(element.formattedContent)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.vertical, 12)
                    .padding(.bottom, 6)
            case 3:
                Text(element.formattedContent)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.vertical, 10)
                    .padding(.bottom, 4)
            case 4:
                Text(element.formattedContent)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.vertical, 8)
            case 5:
                Text(element.formattedContent)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.vertical, 6)
            default: // level 6
                Text(element.formattedContent)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.vertical, 4)
            }
        case .paragraph:
            Text(element.formattedContent)
                .font(.system(size: 16, weight: .regular))
                .lineSpacing(6)
                .foregroundColor(.primary)
                .padding(.vertical, 8)
        case .unorderedList:
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
        case .orderedList:
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
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
        case .horizontalRule:
            Divider()
                .overlay(Color.secondary)
                .padding(.vertical, 16)
        }
    }
}

// MARK: - 增强版Markdown数据结构
struct EnhancedMarkdownElement {
    let id: Int
    let type: EnhancedMarkdownElementType
    let content: String
    let formattedContent: AttributedString
}

enum EnhancedMarkdownElementType {
    case heading(level: Int)
    case paragraph
    case unorderedList
    case orderedList
    case quote
    case codeBlock(language: String)
    case horizontalRule
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
                                .onChange(of: scrollToTop) { _, newValue in
                                    if newValue {
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
        .confirmationDialog("保存到历史", isPresented: $viewModel.showSaveConfirmation, titleVisibility: .visible) {
            Button("确认保存") {
                viewModel.confirmSaveToHistory()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("是否将当前内容保存到历史记录？")
        }
        .confirmationDialog("删除内容", isPresented: $viewModel.showClearConfirmation, titleVisibility: .visible) {
            Button("确认删除", role: .destructive) {
                viewModel.confirmClearContent()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确认删除全部编辑器内容？此操作无法撤销。")
        }
        .confirmationDialog("从剪贴板粘贴", isPresented: $viewModel.showPasteConfirmation, titleVisibility: .visible) {
            Button("确认替换") {
                viewModel.confirmPasteFromClipboard()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("是否用剪贴板内容替换当前所有内容？")
        }
        .confirmationDialog("复制纯文本", isPresented: $viewModel.showCopyPlainTextConfirmation, titleVisibility: .visible) {
            Button("确认复制") {
                viewModel.confirmCopyPlainText()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("是否复制去除markdown格式的纯文本到剪贴板？")
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
        HStack {
            // 左侧项目信息按钮
            ModernButton(
                icon: "info.circle.fill",
                action: { 
                    showingProjectInfo.toggle()
                },
                isDarkMode: isDarkMode,
                isIPad: isIPad
            )
            
            Spacer()
            
            // iPad中心标题
            if isIPad {
                Text("Markdown Export Helper")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isDarkMode ? [.white, .gray] : [.primary, .secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
            }
            
            // 右侧功能按钮组
            HStack(spacing: isIPad ? 16 : 12) {
                ModernButton(
                    icon: "clock.fill",
                    action: { 
                        showingHistory.toggle()
                    },
                    isDarkMode: isDarkMode,
                    isIPad: isIPad
                )
                
                ModernButton(
                    icon: "square.and.arrow.up.fill",
                    action: { 
                        showingExportMenu.toggle()
                    },
                    isDarkMode: isDarkMode,
                    isIPad: isIPad
                )
                
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
                
                // 复制纯文本按钮
                SmallActionButton(
                    icon: "doc.on.doc.fill",
                    color: .purple,
                    action: { viewModel.copyPlainText() },
                    isIPad: isIPad
                )
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
                    ProfessionalMarkdownPreview(content: viewModel.markdownText)
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

// MARK: - Activity Item Providers
class PDFActivityItemProvider: UIActivityItemProvider, @unchecked Sendable {
    private let pdfData: Data
    private let fileName: String
    
    init(pdfData: Data) {
        self.pdfData = pdfData
        self.fileName = "Markdown_Export_\(Date().timeIntervalSince1970).pdf"
        super.init(placeholderItem: fileName)
    }
    
    override var item: Any {
        // 创建临时PDF文件用于分享
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error writing PDF file: \(error)")
            return pdfData
        }
    }
    
    override func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "Markdown Export - \(fileName)"
    }
    
    override func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "com.adobe.pdf"
    }
    
    override func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // 为不同的分享类型提供合适的数据格式
        return item // 使用文件URL
    }
    
    override func activityViewController(_ activityViewController: UIActivityViewController, thumbnailImageForActivityType activityType: UIActivity.ActivityType?, suggestedSize size: CGSize) -> UIImage? {
        // 为PDF提供缩略图
        return UIImage(systemName: "doc.fill")
    }
}

class TextActivityItemProvider: UIActivityItemProvider, @unchecked Sendable {
    private let text: String
    private let fileName: String
    private let mimeType: String
    private let fileData: Data
    
    init(text: String, fileName: String, mimeType: String) {
        self.text = text
        self.fileName = fileName
        self.mimeType = mimeType
        self.fileData = text.data(using: .utf8) ?? Data()
        super.init(placeholderItem: fileName)
    }
    
    override var item: Any {
        // 创建临时文件URL用于分享
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try fileData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error writing file: \(error)")
            return fileData
        }
    }
    
    override func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "Markdown Export - \(fileName)"
    }
    
    override func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        // 根据文件扩展名返回正确的UTI
        if fileName.hasSuffix(".html") {
            return "public.html"
        } else if fileName.hasSuffix(".md") {
            return "net.daringfireball.markdown"
        } else if fileName.hasSuffix(".doc") {
            return "com.microsoft.word.doc"
        }
        return "public.text"
    }
    
    override func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // 为不同的分享类型提供合适的数据格式
        if activityType == .copyToPasteboard {
            return text // 复制到剪贴板时使用文本
        } else {
            return item // 其他情况使用文件URL
        }
    }
    
    override func activityViewController(_ activityViewController: UIActivityViewController, thumbnailImageForActivityType activityType: UIActivity.ActivityType?, suggestedSize size: CGSize) -> UIImage? {
        // 根据文件类型提供缩略图
        if fileName.hasSuffix(".html") {
            return UIImage(systemName: "safari.fill")
        } else if fileName.hasSuffix(".md") {
            return UIImage(systemName: "m.square.fill")
        } else if fileName.hasSuffix(".doc") {
            return UIImage(systemName: "doc.text.fill")
        }
        return UIImage(systemName: "doc.fill")
    }
}

#Preview {
    ContentView()
}
