import UIKit

// This file is intentionally left minimal.
// ScreenshotImageCache is now a type alias for ScreenshotCache defined in ScreenshotCache.swift.
// The ScreenshotCache.shared singleton provides the decodedImage(forKey:data:) method
// that replaces the old image(forKey:data:) method.

extension ScreenshotCache {
    /// Backward-compatible method matching the old ScreenshotImageCache API.
    nonisolated func image(forKey key: String, data: Data) -> UIImage {
        decodedImage(forKey: key, data: data)
    }
}

