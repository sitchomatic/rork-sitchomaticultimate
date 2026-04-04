import Foundation
import UIKit
import Observation

@Observable
class EvidenceBundle: Identifiable {
    let id: UUID
    let credentialId: String
    let username: String
    let password: String
    let resultStatus: CredentialStatus
    let outcome: LoginOutcome
    let confidence: Double
    let signalBreakdown: [ConfidenceResultEngine.SignalContribution]
    let reasoning: String
    let testedURL: String
    let networkMode: String
    let vpnServer: String?
    let vpnIP: String?
    let vpnCountry: String?
    let screenshotIds: [String]
    let logs: [PPSRLogEntry]
    let replayLog: SessionReplayLog?
    let retryCount: Int
    let totalDurationMs: Int
    let startedAt: Date
    let completedAt: Date
    let createdAt: Date
    var isExported: Bool = false
    var exportedAt: Date?

    init(
        credentialId: String,
        username: String,
        password: String,
        resultStatus: CredentialStatus,
        outcome: LoginOutcome,
        confidence: Double,
        signalBreakdown: [ConfidenceResultEngine.SignalContribution],
        reasoning: String,
        testedURL: String,
        networkMode: String,
        vpnServer: String?,
        vpnIP: String?,
        vpnCountry: String?,
        screenshotIds: [String],
        logs: [PPSRLogEntry],
        replayLog: SessionReplayLog?,
        retryCount: Int,
        totalDurationMs: Int,
        startedAt: Date,
        completedAt: Date
    ) {
        self.id = UUID()
        self.credentialId = credentialId
        self.username = username
        self.password = password
        self.resultStatus = resultStatus
        self.outcome = outcome
        self.confidence = confidence
        self.signalBreakdown = signalBreakdown
        self.reasoning = reasoning
        self.testedURL = testedURL
        self.networkMode = networkMode
        self.vpnServer = vpnServer
        self.vpnIP = vpnIP
        self.vpnCountry = vpnCountry
        self.screenshotIds = screenshotIds
        self.logs = logs
        self.replayLog = replayLog
        self.retryCount = retryCount
        self.totalDurationMs = totalDurationMs
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.createdAt = Date()
    }

    var outcomeLabel: String {
        switch outcome {
        case .success: "Working"
        case .noAcc: "No Acc"
        case .tempDisabled: "Temp Disabled"
        case .permDisabled: "Perm Disabled"
        case .unsure: "Unsure"
        case .connectionFailure: "Connection Failure"
        case .timeout: "Timeout"
        case .cancelled: "Cancelled"
        case .smsDetected: "SMS Detected"
        }
    }

    var durationFormatted: String {
        if totalDurationMs < 1000 {
            return "\(totalDurationMs)ms"
        }
        return String(format: "%.1fs", Double(totalDurationMs) / 1000.0)
    }
}

struct EvidenceBundleExport: Codable, Sendable {
    let bundleId: String
    let exportedAt: String
    let credential: CredentialExport
    let result: ResultExport
    let network: NetworkExport
    let aiAnalysis: AIAnalysisExport
    let timeline: TimelineExport
    let logs: [LogExport]
    let replayEvents: [ReplayEventExport]?

    struct CredentialExport: Codable, Sendable {
        let username: String
        let password: String
        let credentialId: String
    }

    struct ResultExport: Codable, Sendable {
        let status: String
        let outcome: String
        let confidence: Double
        let reasoning: String
    }

    struct NetworkExport: Codable, Sendable {
        let mode: String
        let testedURL: String
        let vpnServer: String?
        let vpnIP: String?
        let vpnCountry: String?
    }

    struct AIAnalysisExport: Codable, Sendable {
        let signals: [SignalExport]
    }

    struct SignalExport: Codable, Sendable {
        let source: String
        let weight: Double
        let rawScore: Double
        let weightedScore: Double
        let detail: String
    }

    struct TimelineExport: Codable, Sendable {
        let startedAt: String
        let completedAt: String
        let totalDurationMs: Int
        let retryCount: Int
    }

    struct LogExport: Codable, Sendable {
        let timestamp: String
        let level: String
        let message: String
    }

    struct ReplayEventExport: Codable, Sendable {
        let elapsedMs: Int
        let action: String
        let detail: String
        let level: String
    }
}
