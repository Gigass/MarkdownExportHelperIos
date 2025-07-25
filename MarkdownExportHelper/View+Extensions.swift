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
        let controller = UIHostingController(rootView: self.edgesIgnoringSafeArea(.all))
        let view = controller.view

        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}
#endif 