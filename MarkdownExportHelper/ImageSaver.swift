//
//  ImageSaver.swift
//  MarkdownExportHelper
//
//  Created by Gigass on 2025/7/26.
//

import UIKit
import Combine

class ImageSaver: NSObject, ObservableObject {
    var onSuccess: (() -> Void)?
    var onError: ((Error) -> Void)?

    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            onError?(error)
        } else {
            onSuccess?()
        }
    }
} 