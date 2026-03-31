import Foundation
import Observation
import UIKit
import SwiftUI

@Observable
@MainActor
class UnifiedScreenshotManager {
    static let shared = UnifiedScreenshotManager()

    var screenshots: [CapturedScreenshot] = []
    var analysisStats: AnalysisStats = AnalysisStats()
    private let maxScreenshots: Int = 200
    private let visionCrop = VisionTextCropService.shared
    private let dedup = ScreenshotDedupService.shared
    private let logger = DebugLogger.shared
    private let captureService = ScreenshotCaptureService.shared

    struct AnalysisStats {
        var totalCaptured: Int = 0
        var totalAnalyzed: Int = 0
        var duplicatesSkipped: Int = 0
        var crucialDetections: Int = 0
        var smartCrops: Int = 0
        var outcomeBreakdown: [String: Int] = [:]
    }

    func addScreenshot(
        image: UIImage,
        sessionId: String,
        credentialEmail: String,
        site: String,
        step: ScreenshotStep,
        attemptNumber: Int,
        clickPriority: Int = 0,
        runVisionAnalysis: Bool = true,
        stepName: String = "",
        cardDisplayNumber: String = "",
        cardId: String = "",
        vin: String = "",
        note: String = "",
        password: String = "",
        url: String = "",
        autoDetectedResult: CapturedScreenshot.AutoDetectedResult = .unknown,
        croppedImage: UIImage? = nil
    ) async {
        analysisStats.totalCaptured += 1

        if dedup.isDuplicate(image) {
            analysisStats.duplicatesSkipped += 1
            logger.log("UnifiedScreenshots: duplicate skipped for \(credentialEmail) step=\(step.rawValue)", category: .screenshot, level: .trace)
            return
        }

        let compressedData = captureService.scaleAndCompress(image)
        let compressedImage = UIImage(data: compressedData) ?? image

        var analysis: VisionTextCropService.AnalysisResult?
        var croppedData: Data? = croppedImage.flatMap { captureService.compressed($0) }

        if runVisionAnalysis {
            analysisStats.totalAnalyzed += 1
            let analysisValue = await visionCrop.analyzeScreenshot(compressedImage)
            analysis = analysisValue

            if !analysisValue.crucialMatches.isEmpty {
                analysisStats.crucialDetections += 1
                let crop = await visionCrop.smartCrop(compressedImage, analysis: analysisValue)
                if crop.cropRect != .zero {
                    analysisStats.smartCrops += 1
                    croppedData = captureService.compressed(crop.croppedImage)
                }
            }

            let outcomeKey = analysisValue.detectedOutcome.rawValue
            analysisStats.outcomeBreakdown[outcomeKey, default: 0] += 1
        }

        let screenshot = CapturedScreenshot(
            sessionId: sessionId,
            credentialEmail: credentialEmail,
            site: site,
            step: step,
            attemptNumber: attemptNumber,
            clickPriority: clickPriority,
            fullImageData: compressedData,
            croppedImageData: croppedData,
            detectedOutcome: analysis?.detectedOutcome ?? .unknown,
            crucialKeywords: analysis?.crucialMatches ?? [],
            allDetectedText: analysis?.allText ?? "",
            visionConfidence: analysis?.confidence ?? 0,
            analysisTimeMs: analysis?.processingTimeMs ?? 0,
            stepName: stepName.isEmpty ? step.rawValue : stepName,
            cardDisplayNumber: cardDisplayNumber.isEmpty ? credentialEmail : cardDisplayNumber,
            cardId: cardId,
            vin: vin,
            note: note,
            password: password,
            url: url,
            autoDetectedResult: autoDetectedResult
        )

        screenshots.insert(screenshot, at: 0)

        if screenshots.count > maxScreenshots {
            let overflow = screenshots.count - maxScreenshots
            screenshots.removeLast(overflow)
        }

        let crucialInfo = analysis.flatMap { $0.crucialMatches.isEmpty ? nil : " CRUCIAL:\($0.crucialMatches.joined(separator: ","))" } ?? ""
        logger.log("UnifiedScreenshots: captured \(step.rawValue) for \(credentialEmail) site=\(site) attempt=\(attemptNumber)\(crucialInfo)", category: .screenshot, level: crucialInfo.isEmpty ? .debug : .info)
    }

    func screenshotsForSession(_ sessionId: String) -> [CapturedScreenshot] {
        screenshots.filter { $0.sessionId == sessionId }
    }

    func screenshotsForCredential(_ email: String) -> [CapturedScreenshot] {
        screenshots.filter { $0.credentialEmail == email }
    }

    func crucialScreenshots() -> [CapturedScreenshot] {
        screenshots.filter { !$0.crucialKeywords.isEmpty }
    }

    func screenshotsBySite(_ site: String) -> [CapturedScreenshot] {
        screenshots.filter { $0.site == site }
    }

    func screenshotsForCard(_ cardId: String) -> [CapturedScreenshot] {
        screenshots.filter { $0.cardId == cardId }
    }

    func screenshotsForIds(_ ids: Set<String>) -> [CapturedScreenshot] {
        screenshots.filter { ids.contains($0.id) }
    }

    func clearAll() {
        let count = screenshots.count
        screenshots.removeAll()
        dedup.resetAll()
        analysisStats = AnalysisStats()
        logger.log("UnifiedScreenshots: cleared \(count) screenshots", category: .screenshot, level: .info)
    }

    func clearForSession(_ sessionId: String) {
        screenshots.removeAll { $0.sessionId == sessionId }
    }

    func smartReduceForClearResult(sessionId: String) {
        let sessionShots = screenshots.filter { $0.sessionId == sessionId }
        guard sessionShots.count > 2 else { return }

        let terminalSteps: Set<ScreenshotStep> = [.terminalState, .successDetected, .crucialResponse, .errorBanner, .smsDetected, .finalState]
        let terminalShots = sessionShots.filter { terminalSteps.contains($0.step) }

        var kept: [CapturedScreenshot] = []
        let joeFinal = terminalShots.first(where: { $0.site == "joe" }) ?? sessionShots.filter({ $0.site == "joe" }).last
        let ignFinal = terminalShots.first(where: { $0.site == "ignition" }) ?? sessionShots.filter({ $0.site == "ignition" }).last
        if let j = joeFinal { kept.append(j) }
        if let i = ignFinal { kept.append(i) }

        let keepIds = Set(kept.map(\.id))
        let before = screenshots.count
        screenshots.removeAll { $0.sessionId == sessionId && !keepIds.contains($0.id) }
        let removed = before - screenshots.count
        if removed > 0 {
            logger.log("UnifiedScreenshots: smart-reduced to \(kept.count) screenshots (1/site) for clear result — purged \(removed)", category: .screenshot, level: .info)
        }
    }

    func clearNonDisabledForSession(_ sessionId: String) {
        let disabledSteps: Set<ScreenshotStep> = [.terminalState, .crucialResponse]
        let hasDisabled = screenshots.contains { $0.sessionId == sessionId && disabledSteps.contains($0.step) }
        guard hasDisabled else { return }
        let before = screenshots.count
        screenshots.removeAll { $0.sessionId == sessionId && !disabledSteps.contains($0.step) }
        let removed = before - screenshots.count
        if removed > 0 {
            logger.log("UnifiedScreenshots: disabled override — purged \(removed) non-critical screenshots for session", category: .screenshot, level: .info)
        }
    }

    func pruneByPriority(sessionId: String, limit: Int) {
        let sessionShots = screenshots.filter { $0.sessionId == sessionId }
        guard sessionShots.count > limit, limit > 0 else { return }

        let sorted = sessionShots.sorted { $0.clickPriority < $1.clickPriority }
        let toKeepIds = Set(sorted.prefix(limit).map(\.id))
        let before = screenshots.count
        screenshots.removeAll { $0.sessionId == sessionId && !toKeepIds.contains($0.id) }
        let removed = before - screenshots.count
        if removed > 0 {
            logger.log("UnifiedScreenshots: priority pruned \(removed) screenshots (kept \(limit)) for session", category: .screenshot, level: .debug)
        }
    }

    func correctResult(for screenshot: CapturedScreenshot, override: UserResultOverride) {
        screenshot.userOverride = override
        let allRelated = screenshots.filter { $0.cardId == screenshot.cardId && !screenshot.cardId.isEmpty }
        for s in allRelated where s.id != screenshot.id {
            s.userOverride = override
        }
        logger.log("UnifiedScreenshots: user override \(override.displayLabel) applied to \(screenshot.cardDisplayNumber)", category: .screenshot, level: .info)
    }

    func resetScreenshotOverride(_ screenshot: CapturedScreenshot) {
        screenshot.userOverride = .none
        logger.log("UnifiedScreenshots: reset override for screenshot at \(screenshot.formattedTime)", category: .screenshot, level: .debug)
    }

    func handleMemoryPressure() {
        let keep = min(screenshots.count, 100)
        if screenshots.count > keep {
            screenshots = Array(screenshots.prefix(keep))
        }
        ScreenshotCache.shared.clearDecodedImages()
    }
}

// MARK: - Unified Screenshot Model (replaces PPSRDebugScreenshot, DualFindLiveScreenshot, and UnifiedScreenshot)

@Observable
class CapturedScreenshot: Identifiable {
    let id: String
    let timestamp: Date
    let sessionId: String
    let credentialEmail: String
    let site: String
    let step: ScreenshotStep
    let attemptNumber: Int
    let fullImageData: Data
    var croppedImageData: Data?
    let detectedOutcome: VisionTextCropService.DetectedOutcome
    let crucialKeywords: [String]
    let allDetectedText: String
    let visionConfidence: Double
    let analysisTimeMs: Int
    let clickPriority: Int
    var userOverride: UserResultOverride = .none

    // Fields from PPSRDebugScreenshot
    let stepName: String
    let cardDisplayNumber: String
    let cardId: String
    let vin: String
    var note: String
    var userNote: String = ""
    var correctionReason: String = ""

    // Fields from DualFindLiveScreenshot
    let password: String
    let url: String

    // Auto-detected result (from PPSRDebugScreenshot)
    var autoDetectedResult: AutoDetectedResult = .unknown

    nonisolated enum AutoDetectedResult: String, Sendable {
        case success
        case noAcc
        case permDisabled
        case tempDisabled
        case unsure
        case unknown

        var displayLabel: String {
            switch self {
            case .success: "Success"
            case .noAcc: "No Acc"
            case .permDisabled: "Perm Disabled"
            case .tempDisabled: "Temp Disabled"
            case .unsure: "Unsure"
            case .unknown: "Unknown"
            }
        }

        var toOverride: UserResultOverride {
            switch self {
            case .success: .success
            case .noAcc: .noAcc
            case .permDisabled: .permDisabled
            case .tempDisabled: .tempDisabled
            case .unsure: .unsure
            case .unknown: .none
            }
        }
    }

    // MARK: - Computed Properties

    var imageData: Data { fullImageData }

    var albumKey: String {
        "\(cardId.isEmpty ? cardDisplayNumber : cardId)"
    }

    var albumTitle: String {
        cardDisplayNumber
    }

    var effectiveResult: UserResultOverride {
        if userOverride != .none { return userOverride }
        return autoDetectedResult.toOverride
    }

    var image: UIImage {
        fullImage
    }

    var fullImage: UIImage {
        ScreenshotCache.shared.decodedImage(forKey: "\(id)_full", data: fullImageData)
    }

    var croppedImage: UIImage? {
        get {
            guard let data = croppedImageData else { return nil }
            return ScreenshotCache.shared.decodedImage(forKey: "\(id)_crop", data: data)
        }
        set {
            if let img = newValue {
                croppedImageData = img.jpegData(compressionQuality: 0.5)
                ScreenshotCache.shared.removeDecodedImage(forKey: "\(id)_crop")
            } else {
                croppedImageData = nil
                ScreenshotCache.shared.removeDecodedImage(forKey: "\(id)_crop")
            }
        }
    }

    var displayImage: UIImage {
        croppedImage ?? fullImage
    }

    var hasCrop: Bool {
        croppedImageData != nil
    }

    var isCrucial: Bool {
        !crucialKeywords.isEmpty
    }

    var isJoe: Bool { site.lowercased().contains("joe") }
    var isIgnition: Bool { site.lowercased().contains("ign") }
    var siteLabel: String { isJoe ? "JoePoint" : isIgnition ? "Ignition Lite" : "Unknown" }
    var siteIcon: String { isJoe ? "suit.spade.fill" : isIgnition ? "flame.fill" : "globe" }
    var siteColor: SwiftUI.Color { isJoe ? .green : isIgnition ? .orange : .gray }
    var platform: String { site }
    var email: String { credentialEmail }

    var outcomeColor: SwiftUI.Color {
        if userOverride != .none { return userOverride.color }
        switch detectedOutcome {
        case .success: .green
        case .incorrectPassword, .noAccount: .secondary
        case .permDisabled: .red
        case .tempDisabled: .orange
        case .smsVerification: .purple
        case .errorBanner: .red
        case .unknown: .gray
        }
    }

    var outcomeLabel: String {
        if userOverride != .none { return userOverride.displayLabel.uppercased() }
        switch detectedOutcome {
        case .success: "SUCCESS"
        case .incorrectPassword: "INCORRECT"
        case .noAccount: "NO ACC"
        case .permDisabled: "PERM DISABLED"
        case .tempDisabled: "TEMP DISABLED"
        case .smsVerification: "SMS"
        case .errorBanner: "ERROR"
        case .unknown: "UNKNOWN"
        }
    }

    var formattedTime: String {
        DateFormatters.timeOnly.string(from: timestamp)
    }

    var hasUserOverride: Bool {
        self.userOverride != .none
    }

    var overrideLabel: String {
        userOverride == .none ? "Auto" : "Override: \(userOverride.displayLabel)"
    }

    var outcome: String {
        outcomeLabel
    }

    init(
        sessionId: String = "",
        credentialEmail: String = "",
        site: String = "",
        step: ScreenshotStep = .postAttempt,
        attemptNumber: Int = 0,
        clickPriority: Int = 0,
        fullImageData: Data,
        croppedImageData: Data? = nil,
        detectedOutcome: VisionTextCropService.DetectedOutcome = .unknown,
        crucialKeywords: [String] = [],
        allDetectedText: String = "",
        visionConfidence: Double = 0,
        analysisTimeMs: Int = 0,
        stepName: String = "",
        cardDisplayNumber: String = "",
        cardId: String = "",
        vin: String = "",
        note: String = "",
        password: String = "",
        url: String = "",
        autoDetectedResult: AutoDetectedResult = .unknown
    ) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.sessionId = sessionId
        self.credentialEmail = credentialEmail
        self.site = site
        self.step = step
        self.attemptNumber = attemptNumber
        self.clickPriority = clickPriority
        self.fullImageData = fullImageData
        self.croppedImageData = croppedImageData
        self.detectedOutcome = detectedOutcome
        self.crucialKeywords = crucialKeywords
        self.allDetectedText = allDetectedText
        self.visionConfidence = visionConfidence
        self.analysisTimeMs = analysisTimeMs
        self.stepName = stepName.isEmpty ? step.rawValue : stepName
        self.cardDisplayNumber = cardDisplayNumber.isEmpty ? credentialEmail : cardDisplayNumber
        self.cardId = cardId
        self.vin = vin
        self.note = note
        self.password = password
        self.url = url
        self.autoDetectedResult = autoDetectedResult
    }

    /// Convenience initializer matching PPSRDebugScreenshot's original init
    convenience init(
        stepName: String,
        cardDisplayNumber: String,
        cardId: String = "",
        vin: String,
        email: String = "",
        image: UIImage,
        croppedImage: UIImage? = nil,
        note: String = "",
        site: String = "",
        autoDetectedResult: AutoDetectedResult = .unknown
    ) {
        let fullData = ScreenshotCaptureService.shared.scaleAndCompress(image)
        let croppedData = croppedImage.flatMap { ScreenshotCaptureService.shared.compressed($0) }
        self.init(
            credentialEmail: email,
            site: site,
            fullImageData: fullData,
            croppedImageData: croppedData,
            stepName: stepName,
            cardDisplayNumber: cardDisplayNumber,
            cardId: cardId,
            vin: vin,
            note: note,
            autoDetectedResult: autoDetectedResult
        )
    }
}

// MARK: - Backward compatibility type aliases
typealias UnifiedScreenshot = CapturedScreenshot
typealias PPSRDebugScreenshot = CapturedScreenshot
typealias DualFindLiveScreenshot = CapturedScreenshot

nonisolated enum ScreenshotStep: String, Sendable {
    case pageLoad = "page_load"
    case fieldsDetected = "fields_detected"
    case preTyping = "pre_typing"
    case postTyping = "post_typing"
    case preClick = "pre_click"
    case postClick = "post_click"
    case loadingState = "loading_state"
    case settlementWait = "settlement_wait"
    case responseDetected = "response_detected"
    case crucialResponse = "crucial_response"
    case terminalState = "terminal_state"
    case successDetected = "success_detected"
    case errorBanner = "error_banner"
    case smsDetected = "sms_detected"
    case postAttempt = "post_attempt"
    case finalState = "final_state"
    case recoveryAttempt = "recovery_attempt"
    case blankPage = "blank_page"

    var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").uppercased()
    }

    var icon: String {
        switch self {
        case .pageLoad: "globe"
        case .fieldsDetected: "text.cursor"
        case .preTyping: "keyboard"
        case .postTyping: "checkmark.rectangle"
        case .preClick: "hand.tap"
        case .postClick: "hand.tap.fill"
        case .loadingState: "hourglass"
        case .settlementWait: "clock.arrow.circlepath"
        case .responseDetected: "text.magnifyingglass"
        case .crucialResponse: "exclamationmark.triangle.fill"
        case .terminalState: "stop.circle.fill"
        case .successDetected: "checkmark.circle.fill"
        case .errorBanner: "exclamationmark.octagon.fill"
        case .smsDetected: "message.fill"
        case .postAttempt: "arrow.clockwise"
        case .finalState: "flag.checkered"
        case .recoveryAttempt: "arrow.triangle.2.circlepath"
        case .blankPage: "rectangle.dashed"
        }
    }

    var isCritical: Bool {
        switch self {
        case .crucialResponse, .terminalState, .successDetected, .errorBanner, .smsDetected: true
        default: false
        }
    }
}
