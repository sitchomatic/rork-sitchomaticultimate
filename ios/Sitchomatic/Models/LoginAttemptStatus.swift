import Foundation

/// Swift 6.2 optimized login attempt status with frozen enum and performance attributes
@frozen
nonisolated enum LoginAttemptStatus: String, Sendable, CaseIterable, Identifiable, Codable {
    case queued = "Queued"
    case loadingPage = "Loading Page"
    case fillingCredentials = "Filling Credentials"
    case submitting = "Submitting Login"
    case evaluatingResult = "Evaluating Result"
    case completed = "Completed"
    case failed = "Failed"

    var id: String { rawValue }

    @inline(__always)
    var icon: String {
        switch self {
        case .queued: "clock"
        case .loadingPage: "globe"
        case .fillingCredentials: "text.cursor"
        case .submitting: "arrow.right.circle"
        case .evaluatingResult: "doc.text.magnifyingglass"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    @inline(__always)
    var isTerminal: Bool {
        self == .completed || self == .failed
    }

    @inline(__always)
    var progress: Double {
        switch self {
        case .queued: 0.0
        case .loadingPage: 0.2
        case .fillingCredentials: 0.4
        case .submitting: 0.6
        case .evaluatingResult: 0.8
        case .completed: 1.0
        case .failed: 0.0
        }
    }
}
