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
                                    viewModel.restoreFromHistory(item)
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
                            viewModel.clearHistory()
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(timeFormatter.string(from: item.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { onAction(.restore) }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { onAction(.delete) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            
            Text(item.content)
                .font(.body)
                .lineLimit(3)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryView(viewModel: SimpleMarkdownViewModel())
}