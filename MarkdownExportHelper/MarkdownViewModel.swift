//
//  MarkdownViewModel.swift
//  MarkdownExportHelper
//
//  Created by Gigass on 2025/8/4.
//

import SwiftUI
import Combine

// Placeholder MarkdownViewModel for future full implementation
class MarkdownViewModel: ObservableObject {
    @Published var markdownText: String = ""
    @Published var history: [String] = []
    
    func restoreFromHistory(_ item: String) {
        markdownText = item
    }
    
    func deleteHistoryItem(_ item: String) {
        history.removeAll { $0 == item }
    }
    
    func clearHistory() {
        history.removeAll()
    }
}