import UIKit

nonisolated final class ScreenshotImageCache: @unchecked Sendable {
    static let shared = ScreenshotImageCache()

    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 60
        cache.totalCostLimit = 120 * 1024 * 1024
    }

    func image(forKey key: String, data: Data) -> UIImage {
        let nsKey = key as NSString
        if let cached = cache.object(forKey: nsKey) { return cached }
        guard let img = UIImage(data: data) else { return UIImage() }
        let cost = Int(img.size.width * img.size.height * img.scale * img.scale * 4)
        cache.setObject(img, forKey: nsKey, cost: cost)
        return img
    }

    func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func clearAll() {
        cache.removeAllObjects()
    }
}
