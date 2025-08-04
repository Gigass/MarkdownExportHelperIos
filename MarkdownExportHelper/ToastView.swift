//
//  ToastView.swift
//  MarkdownExportHelper
//
//  Created by Gigass on 2025/8/4.
//

import SwiftUI

enum ToastType {
    case success, error, warning, info
}

struct ToastView: View {
    let message: String
    let type: ToastType
    
    init(_ message: String, type: ToastType = .info) {
        self.message = message
        self.type = type
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.system(size: 16, weight: .semibold))
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    private var iconName: String {
        switch type {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .success:
            return .green
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }
    
    private var backgroundColor: Color {
        Color(.systemBackground)
    }
    
    private var borderColor: Color {
        switch type {
        case .success:
            return .green.opacity(0.3)
        case .error:
            return .red.opacity(0.3)
        case .warning:
            return .orange.opacity(0.3)
        case .info:
            return .blue.opacity(0.3)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ToastView("操作成功完成", type: .success)
        ToastView("发生了一个错误", type: .error)
        ToastView("这是一个警告", type: .warning)
        ToastView("这是一条信息", type: .info)
    }
    .padding()
}