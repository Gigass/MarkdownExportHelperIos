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
    func renderAsImage() -> UIImage? {
        let controller = UIHostingController(rootView: self)
        
        // Get the size that fits the content
        let targetSize = controller.sizeThatFits(in: CGSize(width: 375, height: CGFloat.greatestFiniteMagnitude))
        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.backgroundColor = UIColor.systemBackground
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
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
    
    func renderAsLongImage(width: CGFloat = 750) -> UIImage? {
        let controller = UIHostingController(rootView: self)
        
        // 计算适合的高度
        let maxSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let targetSize = controller.sizeThatFits(in: maxSize)
        
        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.backgroundColor = UIColor.systemBackground
        controller.view.layoutIfNeeded()
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}
#endif 