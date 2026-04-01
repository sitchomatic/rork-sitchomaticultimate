import UIKit

/// Detects if a screenshot is effectively blank (single-color) by sampling pixels
/// and checking color uniformity against a configurable threshold.
enum BlankScreenshotDetector: Sendable {

    /// Default uniformity threshold: 97% of sampled pixels must match the dominant color.
    @inlinable
    static func isBlank(_ image: UIImage, threshold: Double = 0.97) -> Bool {
        guard let cgImage = image.cgImage else { return true }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return true }

        let sampleSize = 120
        let sampleW = min(sampleSize, width)
        let sampleH = min(sampleSize, height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = sampleW * bytesPerPixel
        let totalBytes = sampleW * sampleH * bytesPerPixel
        let pixelData = UnsafeMutablePointer<UInt8>.allocate(capacity: totalBytes)
        defer { pixelData.deallocate() }
        pixelData.initialize(repeating: 0, count: totalBytes)

        guard let context = CGContext(
            data: pixelData,
            width: sampleW,
            height: sampleH,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return true }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleW, height: sampleH))

        let totalPixels = sampleW * sampleH
        guard totalPixels > 0, totalBytes >= bytesPerPixel else { return true }

        let firstR = pixelData[0]
        let firstG = pixelData[1]
        let firstB = pixelData[2]

        let tolerance: UInt8 = 12
        var dominantCount = 0

        for i in 0..<totalPixels {
            let offset = i &* bytesPerPixel
            guard offset &+ 2 < totalBytes else { break }
            let r = pixelData[offset]
            let g = pixelData[offset &+ 1]
            let b = pixelData[offset &+ 2]

            let dr = r > firstR ? r &- firstR : firstR &- r
            let dg = g > firstG ? g &- firstG : firstG &- g
            let db = b > firstB ? b &- firstB : firstB &- b

            if dr <= tolerance && dg <= tolerance && db <= tolerance {
                dominantCount &+= 1
            }
        }

        let uniformity = Double(dominantCount) / Double(totalPixels)
        return uniformity >= threshold
    }
}
