import Foundation

/// Centralized timeout resolution with cached settings and adaptive timeout support.
/// All timeout values are guaranteed to meet minimum thresholds defined in `AutomationSettings`.
@MainActor
enum TimeoutResolver {
    private static var cachedSettings: AutomationSettings?
    /// Timestamp for cache expiry using monotonic clock. Initialized to far past
    /// so the first access always refreshes the cache.
    private static var cachedSettingsTimestamp: ContinuousClock.Instant = .now - .seconds(3600)
    private static let cacheTTL: Duration = .seconds(5)

    static var shared: AutomationSettings {
        let now = ContinuousClock.Instant.now
        if let cached = cachedSettings, now - cachedSettingsTimestamp < cacheTTL {
            return cached
        }
        let settings = CentralSettingsService.shared.loginAutomationSettings
        cachedSettings = settings
        cachedSettingsTimestamp = now
        return settings
    }

    /// Clears the cached automation settings. Call this when automation settings are
    /// updated (e.g., saved to UserDefaults) to ensure the next access retrieves fresh data.
    static func invalidateCache() {
        cachedSettings = nil
        cachedSettingsTimestamp = .now - .seconds(3600)
    }

    static var userTestTimeout: TimeInterval {
        if let data = UserDefaults.standard.data(forKey: "login_settings_v2"),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let t = dict["testTimeout"] as? TimeInterval {
            return max(t, AutomationSettings.minimumTimeoutSeconds)
        }
        return AutomationSettings.minimumTimeoutSeconds
    }

    @inlinable
    static func resolveRequestTimeout(_ hardcoded: TimeInterval) -> TimeInterval {
        let pageLoad = shared.pageLoadTimeout
        if pageLoad > 0 {
            return max(pageLoad, AutomationSettings.minimumTimeoutSeconds)
        }
        return max(hardcoded, AutomationSettings.minimumTimeoutSeconds)
    }

    @inlinable
    static func resolveResourceTimeout(_ hardcoded: TimeInterval) -> TimeInterval {
        let pageLoad = shared.pageLoadTimeout
        let base = pageLoad > 0 ? pageLoad : hardcoded
        return max(base, AutomationSettings.minimumTimeoutSeconds) + 30
    }

    @inlinable
    static func resolvePageLoadTimeout(_ hardcoded: TimeInterval) -> TimeInterval {
        let pageLoad = shared.pageLoadTimeout
        if pageLoad > 0 {
            return max(pageLoad, AutomationSettings.minimumTimeoutSeconds)
        }
        return max(hardcoded, AutomationSettings.minimumTimeoutSeconds)
    }

    @inlinable
    static func resolveHeartbeatTimeout(_ hardcoded: TimeInterval) -> TimeInterval {
        let pageLoad = shared.pageLoadTimeout
        let effective = pageLoad > 0 ? pageLoad : hardcoded
        return max(effective, AutomationSettings.minimumTimeoutSeconds) + 30
    }

    static func resolveTestTimeout(_ hardcoded: TimeInterval, userSetting: TimeInterval) -> TimeInterval {
        let minimum = AutomationSettings.minimumTimeoutSeconds
        if userSetting > 0 {
            return max(userSetting, minimum)
        }
        let pageLoad = shared.pageLoadTimeout
        if pageLoad > 0 {
            return max(max(hardcoded, pageLoad), minimum)
        }
        return max(hardcoded, minimum)
    }

    @inlinable
    static func resolveAutoHealCap(_ currentTimeout: TimeInterval) -> TimeInterval {
        let pageLoad = shared.pageLoadTimeout
        if pageLoad > 0 {
            return max(max(currentTimeout, pageLoad), AutomationSettings.minimumTimeoutSeconds)
        }
        return max(currentTimeout, AutomationSettings.minimumTimeoutSeconds)
    }

    @inlinable
    static func resolveAutomationTimeout(_ hardcoded: TimeInterval) -> TimeInterval {
        max(hardcoded, AutomationSettings.minimumTimeoutSeconds)
    }

    @inlinable
    static func resolveAutomationMilliseconds(_ hardcoded: Int) -> Int {
        max(hardcoded, AutomationSettings.minimumTimeoutMilliseconds)
    }

    static func resolveAdaptiveTimeout(sessionId: String, hardcoded: TimeInterval) -> TimeInterval {
        let activityMonitor = SessionActivityMonitor.shared
        let hasActivity = activityMonitor.hasActivity(sessionId: sessionId)
        if hasActivity {
            return max(SessionActivityMonitor.activeTimeoutSeconds, AutomationSettings.minimumTimeoutSeconds)
        }
        return max(hardcoded, AutomationSettings.minimumTimeoutSeconds)
    }

    @frozen
    nonisolated enum TimeoutReason: Sendable {
        case activeTimeout
        case idleTimeout(secondsIdle: TimeInterval)
        case hardTimeout
    }

    static func evaluateTimeoutReason(sessionId: String, elapsed: TimeInterval) -> TimeoutReason? {
        let activityMonitor = SessionActivityMonitor.shared
        let idleStatus = activityMonitor.checkIdleStatus(sessionId: sessionId)

        switch idleStatus {
        case .idle(let secondsIdle):
            if secondsIdle >= SessionActivityMonitor.idleThresholdSeconds {
                return .idleTimeout(secondsIdle: secondsIdle)
            }
        case .active:
            if elapsed >= SessionActivityMonitor.activeTimeoutSeconds {
                return .activeTimeout
            }
        case .noSession:
            if elapsed >= AutomationSettings.minimumTimeoutSeconds {
                return .hardTimeout
            }
        }
        return nil
    }
}
