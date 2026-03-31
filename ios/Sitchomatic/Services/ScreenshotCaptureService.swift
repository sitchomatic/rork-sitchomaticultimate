import Foundation
import UIKit

/// Unified screenshot capture service that provides consistent quality, scaling and compression.
/// All captures are scaled to iPhone 17 Pro Max full-screen resolution (1320×2868) and
/// compressed to JPEG quality 0.15 (heavily compressed, small file size).
@MainActor
class ScreenshotCaptureService {
    static let shared = ScreenshotCaptureService()

    /// iPhone 17 Pro Max full-screen resolution at 3x scale
    static let proMaxSize = CGSize(width: 1320, height: 2868)
    /// Default JPEG compression quality (heavy compression, ~50-100KB per screenshot)
    static let defaultCompressionQuality: CGFloat = 0.15

    private let renderService = RenderStableScreenshotService.shared
    private let logger = DebugLogger.shared

    /// Capture a screenshot from any ScreenshotCapableSession, scale to Pro Max size, and compress.
    /// - Parameters:
    ///   - session: The session to capture from (LoginWebSession or BPointWebSession)
    ///   - cropRect: Optional crop rect for post-capture cropping
    ///   - useStableCapture: Whether to use RenderStableScreenshotService for stability detection
    /// - Returns: Tuple of (fullImageData, croppedImageData) as compressed JPEG Data, or nil if capture failed
    func captureScreenshot(
        from session: some ScreenshotCapableSession,
        cropRect: CGRect? = nil,
        useStableCapture: Bool = false
    ) async -> (fullData: Data, croppedData: Data?)? {
        let result = await session.captureScreenshotWithCrop(cropRect: cropRect)
        guard let fullImage = result.full else { return nil }

        let scaled = scaleToProMax(fullImage)
        let fullData = compressed(scaled)

        var croppedData: Data?
        if let cropped = result.cropped {
            croppedData = compressed(cropped)
        }

        return (fullData, croppedData)
    }

    /// Scale an image to Pro Max wallpaper size (1320×2868), preserving aspect ratio.
    func scaleToProMax(_ image: UIImage) -> UIImage {
        let targetSize = Self.proMaxSize
        let size = image.size

        // Skip if already at or near target size
        if abs(size.width - targetSize.width) < 2 && abs(size.height - targetSize.height) < 2 {
            return image
        }

        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let scale = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Compress an image to JPEG with heavy compression.
    func compressed(_ image: UIImage, quality: CGFloat = defaultCompressionQuality) -> Data {
        image.jpegData(compressionQuality: quality) ?? Data()
    }

    /// Convenience: scale and compress a UIImage, returning Data.
    func scaleAndCompress(_ image: UIImage) -> Data {
        let scaled = scaleToProMax(image)
        return compressed(scaled)
    }
}
