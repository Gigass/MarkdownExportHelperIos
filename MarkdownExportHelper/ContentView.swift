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
    @Published var markdownText: String = "" {
        didSet {
            saveToHistory()
        }
    }
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var history: [HistoryItem] = []
    
    private let maxHistoryItems = 20
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
        
        // Don't save if it's the same as the last item
        if let lastItem = history.first, lastItem.content == markdownText {
            return
        }
        
        let historyItem = HistoryItem(content: markdownText)
        history.insert(historyItem, at: 0)
        
        // Keep only the latest items
        if history.count > maxHistoryItems {
            history = Array(history.prefix(maxHistoryItems))
        }
        
        saveHistory()
        userDefaults.set(markdownText, forKey: lastContentKey)
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
    
    func restoreFromHistory(_ item: HistoryItem) {
        markdownText = item.content
        showToast(message: "已恢复历史内容")
    }
    
    func deleteHistoryItem(_ item: HistoryItem) {
        history.removeAll { $0.id == item.id }
        saveHistory()
        showToast(message: "已删除历史记录")
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
        showToast(message: "已清空所有历史记录")
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
        showToast(message: "PNG 导出功能开发中...")
    }
    
    func exportAsPDF() {
        showToast(message: "PDF 导出功能开发中...")
    }
    
    func exportAsHTML() {
        showToast(message: "HTML 导出功能开发中...")
    }
    
    func exportAsMarkdown() {
        showToast(message: "Markdown 导出功能开发中...")
    }
    
    func exportAsWord() {
        showToast(message: "Word 导出功能开发中...")
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
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Unified background
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Custom top toolbar - unified with background  
                        modernToolbar
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemGroupedBackground))
                        
                        if geometry.size.width > geometry.size.height {
                            // Landscape: Side by side with cards
                            HStack(spacing: 12) {
                                modernEditorCard
                                    .frame(width: geometry.size.width * 0.5 - 26)
                                
                                modernPreviewCard
                                    .frame(width: geometry.size.width * 0.5 - 26)
                            }
                            .padding(.horizontal, 16)
                        } else {
                            // Portrait: Custom tab view with cards
                            VStack(spacing: 0) {
                                // Custom tab selector - more compact
                                modernTabSelector
                                    .padding(.horizontal, 16)
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
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        Spacer(minLength: 0)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $showingExportMenu) {
            ModernExportSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView(viewModel: viewModel)
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
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    
    private var modernToolbar: some View {
        HStack {
            // Empty space for balance
            Spacer()
            
            // Center title with premium styling
            Text("Markdown Editor")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: isDarkMode ? [.white, .gray] : [.primary, .secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Spacer()
            
            // Action buttons with glassmorphism
            HStack(spacing: 12) {
                ModernButton(
                    icon: "clock.fill",
                    action: { showingHistory.toggle() },
                    isDarkMode: isDarkMode
                )
                
                ModernButton(
                    icon: "square.and.arrow.up.fill",
                    action: { showingExportMenu.toggle() },
                    isDarkMode: isDarkMode
                )
                
                ModernButton(
                    icon: isDarkMode ? "sun.max.fill" : "moon.fill",
                    action: { 
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isDarkMode.toggle()
                            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
                        }
                    },
                    isDarkMode: isDarkMode
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
                HStack(spacing: 6) {
                    SmallActionButton(
                        icon: "trash.fill",
                        color: .red,
                        action: { viewModel.clearContent() }
                    )
                    
                    SmallActionButton(
                        icon: "doc.on.clipboard.fill",
                        color: .blue,
                        action: { viewModel.pasteFromClipboard() }
                    )
                    
                    SmallActionButton(
                        icon: "keyboard.chevron.compact.down",
                        color: .gray,
                        action: { hideKeyboard() }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            
            // Text editor - simplified
            TextEditor(text: $viewModel.markdownText)
                .font(.system(size: 15, design: .monospaced))
                .padding(12)
                .background(Color(.systemBackground))
                .scrollContentBackground(.hidden)
                .onTapGesture(count: 2) {
                    hideKeyboard()
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
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
                        .padding(16)
                }
            }
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Modern UI Components
struct ModernButton: View {
    let icon: String
    let action: () -> Void
    let isDarkMode: Bool
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDarkMode)
    }
}

struct SmallActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(color.opacity(0.12))
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.15), lineWidth: 0.5)
                        )
                )
        }
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: color)
    }
}

struct ModernExportSheet: View {
    let viewModel: SimpleMarkdownViewModel
    @Environment(\.presentationMode) var presentationMode
    
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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    ExportOptionCard(
                        icon: "photo.fill",
                        title: "长图",
                        subtitle: "PNG 格式",
                        color: .green,
                        action: {
                            viewModel.exportAsPNG()
                            presentationMode.wrappedValue.dismiss()
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
                        subtitle: "DOCX 格式",
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

#Preview {
    ContentView()
}
