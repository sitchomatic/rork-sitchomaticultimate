import Foundation
import UIKit

/// Thread-safe image decode cache using actor isolation
actor ImageDecodeCache {
    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 60
        cache.totalCostLimit = 120 * 1024 * 1024
    }

    func get(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, forKey key: String, cost: Int) {
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}

/// Unified screenshot cache that handles both in-memory and disk-based caching using Swift 6 concurrency.
/// Replaces both ScreenshotCacheService and ScreenshotImageCache with a single source of truth.
@MainActor
class ScreenshotCache {
    static let shared = ScreenshotCache()

    private let cacheDirectory: URL
    private let cachedBaseDirectory: URL
    private(set) var maxMemoryCacheCount: Int = 300
    private(set) var maxDiskCacheCount: Int = 1500
    private let maxDiskCacheSizeBytes: Int64 = 500 * 1024 * 1024
    private var memoryCache: [String: UIImage] = [:]
    private var accessOrder: [String] = []
    private let logger = DebugLogger.shared
    private var batchScreenshotCount: Int = 0
    private let autoOffloadThreshold: Int = 30
    private var recentStoreTimestamps: [Date] = []
    private var diskOnlyMode: Bool = false
    private var diskOnlyModeExpiry: Date = .distantPast

    /// Thread-safe actor-based image decoding cache
    private let imageDecodeCache = ImageDecodeCache()

    init() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        cacheDirectory = cachesDir.appendingPathComponent("ScreenshotCache", isDirectory: true)
        cachedBaseDirectory = cacheDirectory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Image Decode Cache (actor-based with sync fallback)

    /// Get a cached decoded image or decode from data. Synchronous version for backward compatibility.
    /// For high-performance async access, use decodedImageAsync instead.
    nonisolated func decodedImage(forKey key: String, data: Data) -> UIImage {
        // Fast synchronous path - just decode directly without actor overhead
        guard let img = UIImage(data: data) else { return UIImage() }
        return img
    }

    /// Get a cached decoded image or decode from data. Fully thread-safe using actor isolation.
    /// Preferred for new code - provides caching benefits.
    nonisolated func decodedImageAsync(forKey key: String, data: Data) async -> UIImage {
        if let cached = await imageDecodeCache.get(forKey: key) {
            return cached
        }
        guard let img = UIImage(data: data) else { return UIImage() }
        let cost = Int(img.size.width * img.size.height * img.scale * img.scale * 4)
        await imageDecodeCache.set(img, forKey: key, cost: cost)
        return img
    }

    /// Remove a decoded image from the fast cache. Thread-safe.
    nonisolated func removeDecodedImage(forKey key: String) async {
        await imageDecodeCache.remove(forKey: key)
    }

    /// Clear all decoded images from the fast cache. Thread-safe.
    nonisolated func clearDecodedImages() async {
        await imageDecodeCache.removeAll()
    }

    // MARK: - Disk + Memory Cache (replaces ScreenshotCacheService)

    func store(_ image: UIImage, forKey key: String) {
        let compressed = compressForMemory(image)
        let jpegData = compressed.jpegData(compressionQuality: 0.4) ?? Data()
        storeData(jpegData, forKey: key)
    }

    func storeData(_ data: Data, forKey key: String) {
        let now = Date()
        batchScreenshotCount += 1

        recentStoreTimestamps.append(now)
        recentStoreTimestamps = recentStoreTimestamps.filter { now.timeIntervalSince($0) < 1.0 }
        if recentStoreTimestamps.count > 5 && !diskOnlyMode {
            diskOnlyMode = true
            diskOnlyModeExpiry = now.addingTimeInterval(5)
            logger.log("ScreenshotCache: rate limit triggered (\(recentStoreTimestamps.count) in 1s) — disk-only mode for 5s", category: .screenshot, level: .warning)
        }
        if diskOnlyMode && now > diskOnlyModeExpiry {
            diskOnlyMode = false
        }

        let skipMemoryCache = diskOnlyMode || CrashProtectionService.shared.isMemoryCritical

        if !skipMemoryCache {
            if let img = UIImage(data: data) {
                memoryCache[key] = img
            }
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
            evictMemoryCacheIfNeeded()

            if batchScreenshotCount > autoOffloadThreshold && batchScreenshotCount % 10 == 0 {
                aggressiveMemoryEvict()
            }
        }

        let fileURL = fileURL(for: key)
        Task.detached(priority: .utility) {
            try? data.write(to: fileURL, options: .atomic)
            await MainActor.run { [weak self] in
                self?.evictDiskCacheIfNeeded()
            }
        }
    }

    func compressForMemory(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 800
        let size = image.size
        if size.width <= maxDimension && size.height <= maxDimension {
            if let data = image.jpegData(compressionQuality: 0.3), let compressed = UIImage(data: data) {
                return compressed
            }
            return image
        }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        if let data = resized.jpegData(compressionQuality: 0.3), let compressed = UIImage(data: data) {
            return compressed
        }
        return resized
    }

    func compressScreenshotForStorage(_ image: UIImage) -> UIImage {
        return compressForMemory(image)
    }

    func resetBatchCounter() {
        batchScreenshotCount = 0
    }

    private func aggressiveMemoryEvict() {
        let targetCount = maxMemoryCacheCount / 2
        while memoryCache.count > targetCount, let oldest = accessOrder.first {
            memoryCache.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }
        logger.log("ScreenshotCache: aggressive evict to \(memoryCache.count) items (batch count: \(batchScreenshotCount))", category: .screenshot, level: .debug)
    }

    var estimatedMemoryUsageMB: Int {
        var total: Int = 0
        for (_, img) in memoryCache {
            let bytes = Int(img.size.width * img.size.height * img.scale * img.scale * 4)
            total += bytes
        }
        return total / (1024 * 1024)
    }

    func retrieve(forKey key: String) -> UIImage? {
        if let cached = memoryCache[key] {
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
            return cached
        }

        let fileURL = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: fileURL.path()),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        memoryCache[key] = image
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        evictMemoryCacheIfNeeded()
        return image
    }

    func clearAll() {
        memoryCache.removeAll()
        accessOrder.removeAll()
        Task {
            await clearDecodedImages()
        }
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    var diskCacheSizeBytes: Int64 {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for file in files {
            if let values = try? file.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    var diskCacheSize: String {
        ByteCountFormatter.string(fromByteCount: diskCacheSizeBytes, countStyle: .file)
    }

    func setMaxCacheCounts(memory: Int, disk: Int) {
        maxMemoryCacheCount = max(10, memory)
        maxDiskCacheCount = max(20, disk)
        evictMemoryCacheIfNeeded()
        evictDiskCacheIfNeeded()
    }

    private func evictMemoryCacheIfNeeded() {
        while memoryCache.count > maxMemoryCacheCount, let oldest = accessOrder.first {
            memoryCache.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }
    }

    private func evictDiskCacheIfNeeded() {
        let diskMax = maxDiskCacheCount
        let sizeMax = maxDiskCacheSizeBytes
        Task.detached(priority: .utility) {
            let fm = FileManager.default
            guard let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
            let dir = cachesDir.appendingPathComponent("ScreenshotCache", isDirectory: true)
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { return }

            let jpgFiles = files.filter { $0.pathExtension == "jpg" }

            let sorted = jpgFiles.sorted { a, b in
                let aDate = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let bDate = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return aDate < bDate
            }

            var removedByCount = 0
            if sorted.count > diskMax {
                let toRemove = sorted.prefix(sorted.count - diskMax)
                for file in toRemove {
                    try? fm.removeItem(at: file)
                    removedByCount += 1
                }
            }

            let remaining = sorted.dropFirst(removedByCount)
            var totalSize: Int64 = 0
            for file in remaining {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                totalSize += Int64(size)
            }

            if totalSize > sizeMax {
                let target = sizeMax * 3 / 4
                for file in remaining {
                    guard totalSize > target else { break }
                    let size = Int64((try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                    try? fm.removeItem(at: file)
                    totalSize -= size
                }
            }
        }
    }

    var memoryCacheCount: Int {
        memoryCache.count
    }

    var diskFileCount: Int {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return 0 }
        return files.filter { $0.pathExtension == "jpg" }.count
    }

    private nonisolated func fileURL(for key: String) -> URL {
        let safeKey = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return cachedBaseDirectory.appendingPathComponent("\(safeKey).jpg")
    }
}

// MARK: - Backward compatibility aliases
/// Type alias so existing code referencing ScreenshotCacheService compiles.
typealias ScreenshotCacheService = ScreenshotCache
/// Type alias so existing code referencing ScreenshotImageCache compiles.
typealias ScreenshotImageCache = ScreenshotCache
