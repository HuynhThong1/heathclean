import Domain
import Foundation
import ImageIO
import UIKit

/// The bytes behind `MealPhoto` (§32.4): the normalized photo, a small thumbnail
/// for the month grid, and the two cleanup paths that keep the filesystem
/// agreeing with the store.
///
/// An actor because it touches the filesystem and decodes images, and neither
/// belongs on the main actor — §32.6 asks specifically that the original is never
/// decoded there.
///
/// **Files are not in the SwiftData store, so nothing makes the two atomic.**
/// The order is therefore always bytes first, row second: a row pointing at a
/// file that does not exist would draw a broken day, while a file no row points at
/// is invisible and collectable. `deleteOrphans(keeping:)` is what collects it.
actor MealPhotoStore {
    /// 44pt cells at @3x need 132px; 240 leaves room for a larger tile and a
    /// bigger Dynamic Type step without re-encoding every photo in the library.
    static let thumbnailMaxPixel = 240
    /// The day sheet shows one photo at roughly screen width, so @3x of a 353pt
    /// card is about 1,060px — 900 is within a hair of that and a third of the
    /// bytes of the 1,600px original.
    static let previewMaxPixel = 900
    private static let jpegQuality = 0.8

    private let fullDirectory: URL
    private let thumbnailDirectory: URL
    private let fileManager = FileManager.default

    /// Thumbnail bytes, not images: `Data` is `Sendable` and a `UIImage` is not,
    /// so the decode of the *thumbnail* happens on the view side — 240px, which
    /// is what makes that acceptable — and the expensive downsample of the
    /// original happens here, once.
    private let cache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 240
        return cache
    }()

    /// Preview bytes are ~15× a thumbnail and only one day's worth is ever on
    /// screen, so this is deliberately small and, unlike the thumbnail, not
    /// written to disk — the original it is derived from is already there.
    private let previewCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 8
        return cache
    }()

    init(root: URL? = nil) {
        let base =
            root
            ?? URL.applicationSupportDirectory.appending(path: "MealPhotos", directoryHint: .isDirectory)
        fullDirectory = base.appending(path: "full", directoryHint: .isDirectory)
        thumbnailDirectory = base.appending(path: "thumb", directoryHint: .isDirectory)
    }

    // MARK: Writing

    /// Writes `data` and its thumbnail, then returns the metadata to store.
    ///
    /// `data` is expected to have been through `MealImagePreprocessor` already —
    /// EXIF applied, 1,600px, JPEG — so this neither re-orients nor re-encodes the
    /// original.
    func save(_ data: Data, capturedAt: Date) throws -> MealPhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let size = Self.pixelSize(of: source),
            let thumbnail = Self.thumbnailData(from: source)
        else { throw MealPhotoStoreError.unreadableImage }

        let id = UUID()
        try fileManager.createDirectory(at: fullDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)

        do {
            // `.atomic` *is* the temp-file-then-rename §32.4 asks for: Foundation
            // writes a sibling temp file and renames it into place, so a reader
            // never sees half a photo.
            try data.write(to: url(for: id, in: fullDirectory), options: .atomic)
            try thumbnail.write(to: url(for: id, in: thumbnailDirectory), options: .atomic)
        } catch {
            // A half-written pair would be an orphan the caller never learns
            // about, since it is about to be told the save failed.
            delete(ids: [id])
            throw error
        }

        cache.setObject(thumbnail as NSData, forKey: id.uuidString as NSString)
        return MealPhoto(
            id: id,
            capturedAt: capturedAt,
            pixelWidth: size.width,
            pixelHeight: size.height
        )
    }

    // MARK: Reading

    /// Thumbnail bytes for a grid cell, or `nil` when the file is gone.
    ///
    /// A missing file is not an error worth surfacing: §32.3 says the cell falls
    /// back to the nutrition tile rather than failing the screen, because the meal
    /// is still perfectly readable without its picture.
    func thumbnailData(for id: UUID) -> Data? {
        let key = id.uuidString as NSString
        if let cached = cache.object(forKey: key) { return cached as Data }

        guard let data = try? Data(contentsOf: url(for: id, in: thumbnailDirectory)) else {
            // The thumbnail can be missing while the original is not — a build
            // that wrote one but not the other, or a half-restored backup — so it
            // is rebuilt rather than treated as a lost photo.
            guard let rebuilt = rebuildThumbnail(for: id) else { return nil }
            return rebuilt
        }
        cache.setObject(data as NSData, forKey: key)
        return data
    }

    func imageData(for id: UUID) -> Data? {
        try? Data(contentsOf: url(for: id, in: fullDirectory))
    }

    /// The day sheet's copy of a photo: the original, downsampled here rather than
    /// handed over at 1,600px for the main actor to decode.
    ///
    /// `nil` when the file is gone, which the sheet draws as a neutral placeholder
    /// — a meal is still readable without its picture (§32.3).
    func previewData(for id: UUID) -> Data? {
        let key = "preview-\(id.uuidString)" as NSString
        if let cached = previewCache.object(forKey: key) { return cached as Data }

        guard let original = imageData(for: id),
            let source = CGImageSourceCreateWithData(original as CFData, nil),
            let data = Self.downsampled(source, maxPixel: Self.previewMaxPixel)
        else { return nil }

        previewCache.setObject(data as NSData, forKey: key)
        return data
    }

    // MARK: Deleting

    func delete(ids: [UUID]) {
        for id in ids {
            try? fileManager.removeItem(at: url(for: id, in: fullDirectory))
            try? fileManager.removeItem(at: url(for: id, in: thumbnailDirectory))
            cache.removeObject(forKey: id.uuidString as NSString)
        }
    }

    /// Removes every file no meal refers to any more.
    ///
    /// Runs once at launch, and it is the only thing that catches a file whose row
    /// vanished without this store hearing about it: a crash between the two
    /// writes, a delete that failed halfway, a store restored from an older
    /// backup than the photo directory.
    func deleteOrphans(keeping ids: Set<UUID>) {
        for directory in [fullDirectory, thumbnailDirectory] {
            let files =
                (try? fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: nil
                )) ?? []
            for file in files {
                guard let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent)
                else {
                    // Not ours, so not ours to delete.
                    continue
                }
                guard !ids.contains(id) else { continue }
                try? fileManager.removeItem(at: file)
                cache.removeObject(forKey: id.uuidString as NSString)
            }
        }
    }

    // MARK: Plumbing

    private func url(for id: UUID, in directory: URL) -> URL {
        directory.appending(path: "\(id.uuidString).jpg", directoryHint: .notDirectory)
    }

    private func rebuildThumbnail(for id: UUID) -> Data? {
        guard let original = imageData(for: id),
            let source = CGImageSourceCreateWithData(original as CFData, nil),
            let data = Self.thumbnailData(from: source)
        else { return nil }
        try? fileManager.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)
        try? data.write(to: url(for: id, in: thumbnailDirectory), options: .atomic)
        cache.setObject(data as NSData, forKey: id.uuidString as NSString)
        return data
    }

    /// Read from the image's properties, which does not decode it.
    private static func pixelSize(of source: CGImageSource) -> (width: Int, height: Int)? {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    private static func thumbnailData(from source: CGImageSource) -> Data? {
        downsampled(source, maxPixel: thumbnailMaxPixel)
    }

    /// ImageIO decodes straight to the requested size, so the full-resolution
    /// bitmap never exists — which is what keeps this cheap enough to do on
    /// demand.
    private static func downsampled(_ source: CGImageSource, maxPixel: Int) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: jpegQuality)
    }
}

enum MealPhotoStoreError: Error {
    /// The bytes are not an image ImageIO can read, so there is nothing to store.
    case unreadableImage
}
