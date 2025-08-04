//
//  HistoryView.swift
//  MarkdownExportHelper
//
//  Created by Gigass on 2025/8/4.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: SimpleMarkdownViewModel
    @Environment(\.presentationMode) var presentationMode
    let onScrollToTop: () -> Void
    
    init(viewModel: SimpleMarkdownViewModel, onScrollToTop: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onScrollToTop = onScrollToTop
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.history.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("暂无历史记录")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Text("开始编辑 Markdown 内容，系统会自动保存历史记录")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.history) { item in
                            HistoryItemRow(item: item) { action in
                                switch action {
                                case .restore:
                                    viewModel.restoreFromHistory(item) {
                                        onScrollToTop()
                                    }
                                    presentationMode.wrappedValue.dismiss()
                                case .delete:
                                    viewModel.deleteHistoryItem(item)
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("历史记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                if !viewModel.history.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("清空全部") {
                            viewModel.clearHistory {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

enum HistoryAction {
    case restore, delete
}

struct HistoryItemRow: View {
    let item: HistoryItem
    let onAction: (HistoryAction) -> Void
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        Button(action: { onAction(.restore) }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                        
                        Text(timeFormatter.string(from: item.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 删除按钮
                    Button(action: { onAction(.delete) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Text(item.content)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HistoryView(viewModel: SimpleMarkdownViewModel(), onScrollToTop: {})
}