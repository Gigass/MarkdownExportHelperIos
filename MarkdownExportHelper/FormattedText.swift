//
//  FormattedText.swift
//  MarkdownExportHelper
//
//  Created by Claude on 2025/8/4.
//

import SwiftUI

struct FormattedTextPart {
    let content: String
    let isBold: Bool
    let isItalic: Bool
    let isCode: Bool
}

// MARK: - Enhanced Markdown Rendering
extension MarkdownPreviewView {
    func createFormattedText(_ text: String) -> Text {
        let parts = parseInlineFormatting(text)
        var result = Text("")
        
        for part in parts {
            var textPart = Text(part.content)
            
            if part.isBold {
                textPart = textPart.bold()
            }
            if part.isItalic {
                textPart = textPart.italic()
            }
            if part.isCode {
                textPart = textPart
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.primary)
            }
            
            result = result + textPart
        }
        
        return result
    }
    
    private func parseInlineFormatting(_ text: String) -> [FormattedTextPart] {
        var parts: [FormattedTextPart] = []
        var processedText = text
        
        // Process bold **text** patterns
        while let boldRange = processedText.range(of: #"\*\*(.*?)\*\*"#, options: .regularExpression) {
            // Add text before bold
            if boldRange.lowerBound > processedText.startIndex {
                let beforeText = String(processedText[processedText.startIndex..<boldRange.lowerBound])
                if !beforeText.isEmpty {
                    parts.append(FormattedTextPart(content: beforeText, isBold: false, isItalic: false, isCode: false))
                }
            }
            
            // Extract and add bold content
            let boldText = String(processedText[boldRange])
            let content = boldText.replacingOccurrences(of: "**", with: "")
            parts.append(FormattedTextPart(content: content, isBold: true, isItalic: false, isCode: false))
            
            // Remove processed part
            processedText = String(processedText[boldRange.upperBound...])
        }
        
        // Add remaining text
        if !processedText.isEmpty {
            parts.append(FormattedTextPart(content: processedText, isBold: false, isItalic: false, isCode: false))
        }
        
        // If no formatting found, return original text
        if parts.isEmpty {
            parts.append(FormattedTextPart(content: text, isBold: false, isItalic: false, isCode: false))
        }
        
        return parts
    }
}