import UIKit

nonisolated final class ScreenshotImageCache: @unchecked Sendable {
    static let shared = ScreenshotImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()

    init() {
        cache.countLimit = 60
        cache.totalCostLimit = 120 * 1024 * 1024
    }

    func image(forKey key: String, data: Data) -> UIImage {
        let nsKey = key as NSString
        lock.lock()
        if let cached = cache.object(forKey: nsKey) {
            lock.unlock()
            return cached
        }
        lock.unlock()
        guard let img = UIImage(data: data) else { return UIImage() }
        let cost = Int(img.size.width * img.size.height * img.scale * img.scale * 4)
        lock.lock()
        cache.setObject(img, forKey: nsKey, cost: cost)
        lock.unlock()
        return img
    }

    func removeImage(forKey key: String) {
        lock.lock()
        cache.removeObject(forKey: key as NSString)
        lock.unlock()
    }

    func clearAll() {
        lock.lock()
        cache.removeAllObjects()
        lock.unlock()
    }
}
