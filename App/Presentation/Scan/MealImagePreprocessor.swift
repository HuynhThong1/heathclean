import Foundation
import ImageIO
import UIKit

/// Normalizes every camera/library image before it crosses the network.
///
/// ImageIO builds a thumbnail without first decoding the full-resolution photo,
/// applies EXIF orientation, and UIKit emits a predictable JPEG. This fixes the
/// old mismatch where HEIC bytes could be uploaded while labelled image/jpeg.
enum MealImagePreprocessor {
    static let maxPixelSize = 1_600
    static let jpegQuality = 0.78

    static func prepare(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source, 0, options as CFDictionary
        ) else { return nil }

        return UIImage(cgImage: thumbnail).jpegData(compressionQuality: jpegQuality)
    }
}
