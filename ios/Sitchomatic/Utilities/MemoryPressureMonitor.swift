import Foundation
import UIKit

@MainActor
final class MemoryPressureMonitor {
    static let shared = MemoryPressureMonitor()

    private var observers: [@MainActor @Sendable () -> Void] = []
    private var isRegistered: Bool = false
    private var lastTierTriggered: MemoryTier = .normal
    private var tierEscalationCount: Int = 0
    private var monitorTask: Task<Void, Never>?

    @frozen
    nonisolated enum MemoryTier: Int, Sendable, Comparable {
        case normal = 0
        case elevated = 1
        case warning = 2
        case critical = 3
        case severe = 4

        @inlinable
        nonisolated static func < (lhs: MemoryTier, rhs: MemoryTier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    func register() {
        guard !isRegistered else { return }
        isRegistered = true
        monitorTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: UIApplication.didReceiveMemoryWarningNotification
            )
            for await _ in notifications {
                guard !Task.isCancelled, let self else { break }
                self.handleMemoryWarning(tier: .critical)
            }
        }
    }

    func onMemoryWarning(_ handler: @escaping @MainActor @Sendable () -> Void) {
        observers.append(handler)
    }

    private func handleMemoryWarning(tier: MemoryTier) {
        let tierLabel: String
        switch tier {
        case .normal: return
        case .elevated: tierLabel = "ELEVATED"
        case .warning: tierLabel = "WARNING"
        case .critical: tierLabel = "CRITICAL"
        case .severe: tierLabel = "SEVERE"
        }

        if tier > lastTierTriggered {
            tierEscalationCount += 1
        }
        lastTierTriggered = tier

        DebugLogger.shared.log("MEMORY \(tierLabel) — triggering \(observers.count) cleanup handlers (escalations: \(tierEscalationCount))", category: .system, level: tier >= .critical ? .critical : .warning)

        for handler in observers {
            handler()
        }

        if tier >= .severe {
            DebugLogger.shared.log("MemoryMonitor: SEVERE tier — additional aggressive cleanup", category: .system, level: .critical)
            ScreenshotCache.shared.clearAll()
            URLCache.shared.removeAllCachedResponses()
            URLCache.shared.memoryCapacity = 0

            PersistentFileStorageService.shared.forceSave()
            LoginViewModel.shared.persistCredentialsNow()
            PPSRAutomationViewModel.shared.persistCardsNow()
        }
    }

}
