//
//  View+Extensions.swift
//  MarkdownExportHelper
//
//  Created by Gigass on 2025/7/25.
//

import SwiftUI

#if os(macOS)
extension View {
    func renderAsImage() -> NSImage? {
        let view = NoInsetHostingView(rootView: self)
        view.setFrameSize(view.fittingSize)
        
        guard let bitmapRep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return nil
        }
        
        view.cacheDisplay(in: view.bounds, to: bitmapRep)
        
        let image = NSImage(size: bitmapRep.size)
        image.addRepresentation(bitmapRep)
        
        return image
    }
}

private class NoInsetHostingView<V: View>: NSHostingView<V> {
    override var safeAreaInsets: NSEdgeInsets {
        return .init()
    }
}
#endif

#if os(iOS)
import UIKit


extension View {
    @MainActor
    func renderAsImage() -> UIImage? {
        // 使用 iOS 16+ 的 ImageRenderer API
        print("renderAsImage: 使用 iOS 16+ ImageRenderer API...")
        
        let renderer = ImageRenderer(content: self)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: 375, height: nil)
        
        let image = renderer.uiImage
        
        if let image = image {
            print("renderAsImage: ImageRenderer 渲染成功: \(image.size)")
            return image
        } else {
            print("renderAsImage: ImageRenderer 渲染失败")
            return nil
        }
    }
    
    func renderAsPDF() -> Data? {
        let controller = UIHostingController(rootView: self)
        let targetSize = controller.sizeThatFits(in: CGSize(width: 612, height: CGFloat.greatestFiniteMagnitude)) // Letter width
        
        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.backgroundColor = UIColor.systemBackground
        controller.view.layoutIfNeeded()
        
        // 使用正确的PDF生成方法
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(origin: .zero, size: targetSize), nil)
        UIGraphicsBeginPDFPage()
        
        guard let pdfContext = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndPDFContext()
            return nil
        }
        
        controller.view.layer.render(in: pdfContext)
        UIGraphicsEndPDFContext()
        
        return pdfData as Data
    }
}

extension View {
    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view

        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
    
    @MainActor
    func renderAsLongImage(width: CGFloat = 750) -> UIImage? {
        // 使用 iOS 16+ 的 ImageRenderer API - 专门为 SwiftUI 设计
        print("使用 iOS 16+ ImageRenderer API 渲染长图...")
        
        // 检查尺寸限制
        let maxWidth: CGFloat = 2048
        let maxHeight: CGFloat = 16384
        let clampedWidth = min(width, maxWidth)
        
        // 创建 ImageRenderer
        let renderer = ImageRenderer(content: self)
        
        // 设置渲染参数
        renderer.scale = UIScreen.main.scale // 使用设备的原生分辨率
        renderer.proposedSize = ProposedViewSize(width: clampedWidth, height: nil) // 让高度自适应
        
        print("ImageRenderer 配置完成，开始渲染...")
        
        // 渲染图像
        let image = renderer.uiImage
        
        if let image = image {
            let finalSize = image.size
            print("ImageRenderer 渲染成功: \(finalSize)")
            
            // 检查高度限制
            if finalSize.height > maxHeight {
                print("警告: 图片高度超限 (\(finalSize.height)px)，需要缩放")
                // 如果需要，可以在这里添加缩放逻辑
            }
            
            return image
        } else {
            print("ImageRenderer 渲染失败")
            return nil
        }
    }
    
    /// 智能等待视图渲染完成
    private func waitForViewToCompleteRendering(controller: UIHostingController<some View>, timeout: TimeInterval) -> Bool {
        let startTime = Date()
        let maxTimeout = timeout
        var lastViewState = ViewRenderingState(controller: controller)
        var stableCheckCount = 0
        let requiredStableChecks = 3 // 需要连续3次检查稳定
        let checkInterval: TimeInterval = 0.1 // 检查间隔
        
        print("Starting intelligent rendering wait for view with bounds: \(controller.view.bounds)")
        
        // 初始布局
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        
        while Date().timeIntervalSince(startTime) < maxTimeout {
            // 等待一个检查间隔
            RunLoop.current.run(until: Date(timeIntervalSinceNow: checkInterval))
            
            // 再次强制布局
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            
            // 检查当前视图状态
            let currentViewState = ViewRenderingState(controller: controller)
            
            if currentViewState.isStableComparedTo(lastViewState) {
                stableCheckCount += 1
                print("Stable check \(stableCheckCount)/\(requiredStableChecks) - views: \(currentViewState.subviewCount)")
                
                if stableCheckCount >= requiredStableChecks {
                    let duration = Date().timeIntervalSince(startTime)
                    print("Rendering completed after \(String(format: "%.2f", duration))s - final subview count: \(currentViewState.subviewCount)")
                    return true
                }
            } else {
                stableCheckCount = 0 // 重置稳定计数
                print("View still changing - subviews: \(lastViewState.subviewCount) -> \(currentViewState.subviewCount)")
            }
            
            lastViewState = currentViewState
        }
        
        print("Rendering timeout after \(timeout)s - final subview count: \(lastViewState.subviewCount)")
        return false
    }
    
    /// 计算视图层次结构的复杂度（用于判断渲染是否稳定）
    private func countViewHierarchy(view: UIView) -> Int {
        var count = 1
        for subview in view.subviews {
            count += countViewHierarchy(view: subview)
        }
        return count
    }
}

/// 视图渲染状态跟踪
private struct ViewRenderingState {
    let subviewCount: Int
    let bounds: CGRect
    let hasContent: Bool
    
    init(controller: UIHostingController<some View>) {
        self.subviewCount = Self.countSubviews(in: controller.view)
        self.bounds = controller.view.bounds
        self.hasContent = Self.checkHasContent(in: controller.view)
    }
    
    func isStableComparedTo(_ other: ViewRenderingState) -> Bool {
        // 视图稳定的条件：
        // 1. 子视图数量相同
        // 2. 边界尺寸相同
        // 3. 都有内容或都没有内容
        return subviewCount == other.subviewCount &&
               bounds == other.bounds &&
               hasContent == other.hasContent
    }
    
    private static func countSubviews(in view: UIView) -> Int {
        var count = view.subviews.count
        for subview in view.subviews {
            count += countSubviews(in: subview)
        }
        return count
    }
    
    private static func checkHasContent(in view: UIView) -> Bool {
        // 检查是否有可见内容（简单检查）
        if !view.subviews.isEmpty {
            return true
        }
        
        // 检查是否有绘制内容
        if view.layer.sublayers?.isEmpty == false {
            return true
        }
        
        return false
    }
}

#endif 