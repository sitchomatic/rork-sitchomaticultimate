import Foundation
import Combine
import UIKit

@MainActor
class DebugLogger {
    static let shared = DebugLogger()

    let didChange = PassthroughSubject<Void, Never>()
    let persistence = LogPersistenceService()
    private let sessionTracker = LogSessionTracker()

    private(set) var entries: [DebugLogEntry] = []
    var maxEntries: Int = 3000
    var minimumLevel: DebugLogLevel = .trace
    var enabledCategories: Set<DebugLogCategory> = Set(DebugLogCategory.allCases)
    var isRecording: Bool = true

    private(set) var errorHealingLog: [ErrorHealingEvent] = []
    private(set) var retryTracker: [String: RetryState] = [:]

    private var pendingEntries: [DebugLogEntry] = []
    private var flushTask: Task<Void, Never>?
    private var persistTask: Task<Void, Never>?
    private(set) var totalEntriesLogged: Int = 0
    private(set) var totalEntriesEvicted: Int = 0

    private(set) var cachedErrorCount: Int = 0
    private(set) var cachedWarningCount: Int = 0
    private(set) var cachedCriticalCount: Int = 0

    init() {
        startAutoPersist()
    }

    // MARK: - Computed Properties

    var filteredEntries: [DebugLogEntry] { entries }
    var entryCount: Int { entries.count }
    var errorCount: Int { cachedErrorCount }
    var warningCount: Int { cachedWarningCount }
    var criticalCount: Int { cachedCriticalCount }
    var persistedLogURL: URL { persistence.persistentLogURL }
    var archiveFileCount: Int { persistence.archiveFileCount }

    var healingSuccessRate: Double {
        guard !errorHealingLog.isEmpty else { return 1.0 }
        return Double(errorHealingLog.filter(\.succeeded).count) / Double(errorHealingLog.count)
    }

    var recentErrors: [DebugLogEntry] {
        Array(entries.filter { $0.level >= .error }.prefix(50))
    }

    var uniqueSessionIds: [String] {
        Array(Set(entries.compactMap(\.sessionId))).sorted()
    }

    var categoryBreakdown: [(category: DebugLogCategory, count: Int)] {
        var counts: [DebugLogCategory: Int] = [:]
        for entry in entries { counts[entry.category, default: 0] += 1 }
        return counts.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }

    var levelBreakdown: [(level: DebugLogLevel, count: Int)] {
        var counts: [DebugLogLevel: Int] = [:]
        for entry in entries { counts[entry.level, default: 0] += 1 }
        return counts.map { ($0.key, $0.value) }.sorted { $0.level < $1.level }
    }

    // MARK: - Core Logging

    func log(
        _ message: String,
        category: DebugLogCategory = .system,
        level: DebugLogLevel = .info,
        detail: String? = nil,
        sessionId: String? = nil,
        durationMs: Int? = nil,
        metadata: [String: String]? = nil
    ) {
        guard isRecording, level >= minimumLevel, enabledCategories.contains(category) else { return }

        let entry = DebugLogEntry(
            category: category, level: level, message: message,
            detail: detail, sessionId: sessionId, durationMs: durationMs, metadata: metadata
        )
        pendingEntries.append(entry)
        level >= .error ? flushPendingEntries() : scheduleFlush()
    }

    func networkLog(_ message: String, level: DebugLogLevel = .info) {
        log(message, category: .network, level: level)
    }

    func logError(
        _ message: String, error: Error,
        category: DebugLogCategory = .system,
        sessionId: String? = nil, metadata: [String: String]? = nil
    ) {
        let nsError = error as NSError
        let detail = "[\(nsError.domain):\(nsError.code)] \(nsError.localizedDescription)"
        var enrichedMeta = metadata ?? [:]
        enrichedMeta["errorDomain"] = nsError.domain
        enrichedMeta["errorCode"] = "\(nsError.code)"
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            enrichedMeta["underlyingError"] = "[\(underlying.domain):\(underlying.code)] \(underlying.localizedDescription)"
        }
        if let urlError = error as? URLError {
            enrichedMeta["urlErrorCode"] = "\(urlError.code.rawValue)"
            enrichedMeta["failingURL"] = urlError.failureURLString ?? "N/A"
        }
        log(message, category: category, level: .error, detail: detail, sessionId: sessionId, metadata: enrichedMeta)
    }

    // MARK: - Healing & Retry

    func logHealing(
        category: DebugLogCategory, originalError: String, healingAction: String,
        succeeded: Bool, attemptNumber: Int = 1, durationMs: Int? = nil, sessionId: String? = nil
    ) {
        let event = ErrorHealingEvent(
            timestamp: Date(), category: category, originalError: originalError,
            healingAction: healingAction, succeeded: succeeded,
            attemptNumber: attemptNumber, durationMs: durationMs
        )
        errorHealingLog.insert(event, at: 0)
        if errorHealingLog.count > 500 { errorHealingLog = Array(errorHealingLog.prefix(500)) }
        log("HEAL [\(succeeded ? "OK" : "FAIL")] attempt #\(attemptNumber): \(healingAction)",
            category: category, level: succeeded ? .success : .warning,
            detail: "Original error: \(originalError)", sessionId: sessionId, durationMs: durationMs)
    }

    func getRetryState(for key: String, maxAttempts: Int = 3) -> RetryState {
        if retryTracker[key] == nil { retryTracker[key] = RetryState(maxAttempts: maxAttempts) }
        return retryTracker[key] ?? RetryState(maxAttempts: maxAttempts)
    }

    func recordRetryAttempt(for key: String, error: String?) {
        if retryTracker[key] == nil { retryTracker[key] = RetryState() }
        retryTracker[key]?.recordAttempt(error: error)
    }

    func resetRetryState(for key: String) { retryTracker[key]?.reset() }

    func shouldRetry(key: String) -> (shouldRetry: Bool, backoffMs: Int) {
        let state = getRetryState(for: key)
        return state.isExhausted ? (false, 0) : (true, state.backoffMs)
    }

    // MARK: - Session & Timer (delegated)

    func startTimer(key: String) { sessionTracker.startTimer(key: key) }
    func stopTimer(key: String) -> Int? { sessionTracker.stopTimer(key: key) }

    func startSession(_ sessionId: String, category: DebugLogCategory, message: String) {
        sessionTracker.startSession(sessionId)
        log(message, category: category, level: .info, sessionId: sessionId)
    }

    func endSession(_ sessionId: String, category: DebugLogCategory, message: String, level: DebugLogLevel = .info) {
        let durationMs = sessionTracker.endSession(sessionId)
        log(message, category: category, level: level, sessionId: sessionId, durationMs: durationMs)
    }

    func entriesForSession(_ sessionId: String) -> [DebugLogEntry] {
        entries.filter { $0.sessionId == sessionId }
    }

    // MARK: - Entry Management

    func clearAll() {
        entries.removeAll()
        sessionTracker.reset()
        errorHealingLog.removeAll()
        retryTracker.removeAll()
        cachedErrorCount = 0; cachedWarningCount = 0; cachedCriticalCount = 0
        didChange.send()
    }

    func trimEntries(to count: Int) {
        guard entries.count > count else { return }
        let evicted = Array(entries.suffix(from: count))
        updateCachedCounts(removing: evicted)
        totalEntriesEvicted += evicted.count
        entries.removeLast(entries.count - count)
    }

    func handleMemoryPressure() {
        let beforeCount = entries.count
        let keepCount = min(1000, maxEntries / 5)
        guard entries.count > keepCount else { return }
        let evicted = Array(entries.suffix(from: keepCount))
        updateCachedCounts(removing: evicted)
        persistence.scheduleDiskFlush(entries: evicted)
        entries.removeLast(entries.count - keepCount)
        log("Memory pressure: evicted \(beforeCount - keepCount) log entries to disk", category: .system, level: .warning)
    }

    // MARK: - Export & Persistence Delegation

    func persistLatestLog() {
        persistence.persistLatestLog(entries: entries, totalLogged: totalEntriesLogged, errorCount: cachedErrorCount, warningCount: cachedWarningCount)
    }

    func loadPersistedLatestLog() -> String { persistence.loadPersistedLatestLog() }
    func loadPersistedCriticalLogs() -> [DebugLogEntry] { persistence.loadPersistedCriticalLogs() }
    func loadArchivedLogFiles() -> [URL] { persistence.loadArchivedLogFiles() }
    func loadArchivedEntries(from url: URL, limit: Int = 500) -> String { persistence.loadArchivedEntries(from: url, limit: limit) }

    func flushAllToDisk() {
        flushPendingEntries()
        persistence.flushAllToDisk(entries: entries, totalLogged: totalEntriesLogged, errorCount: cachedErrorCount, warningCount: cachedWarningCount)
        persistLatestLog()
    }

    func exportLogToFile() -> URL? {
        persistence.exportLogToFile(content: exportFullLog())
    }

    func exportDiagnosticReportToFile(credentials: [LoginCredential] = [], automationSettings: AutomationSettings? = nil) -> URL? {
        persistence.exportDiagnosticReportToFile(content: exportDiagnosticReport(credentials: credentials, automationSettings: automationSettings))
    }

    func exportFullLog() -> String {
        let header = """
        === DEBUG LOG EXPORT ===
        Exported: \(DebugLogEntry(category: .system, level: .info, message: "").fullTimestamp)
        Total Entries: \(entries.count)
        Errors: \(errorCount)
        Warnings: \(warningCount)
        Critical: \(criticalCount)
        Healing Events: \(errorHealingLog.count) (\(String(format: "%.0f%%", healingSuccessRate * 100)) success)
        ========================
        
        """
        return header + entries.reversed().map(\.exportLine).joined(separator: "\n")
    }

    func exportFilteredLog(
        categories: Set<DebugLogCategory>? = nil, minLevel: DebugLogLevel? = nil,
        sessionId: String? = nil, since: Date? = nil
    ) -> String {
        var filtered = entries.reversed() as [DebugLogEntry]
        if let cats = categories { filtered = filtered.filter { cats.contains($0.category) } }
        if let lvl = minLevel { filtered = filtered.filter { $0.level >= lvl } }
        if let sid = sessionId { filtered = filtered.filter { $0.sessionId == sid } }
        if let date = since { filtered = filtered.filter { $0.timestamp >= date } }
        return filtered.map(\.exportLine).joined(separator: "\n")
    }

    func exportHealingLog() -> String {
        let header = "=== ERROR HEALING LOG (\(errorHealingLog.count) events, \(String(format: "%.0f%%", healingSuccessRate * 100)) success) ===\n"
        let lines = errorHealingLog.map { event in
            let status = event.succeeded ? "OK" : "FAIL"
            let dur = event.durationMs.map { " [\($0)ms]" } ?? ""
            return "[\(DateFormatters.timeWithMillis.string(from: event.timestamp))] [\(status)] [\(event.category.rawValue)] #\(event.attemptNumber)\(dur) \(event.healingAction) | Error: \(event.originalError)"
        }.joined(separator: "\n")
        return header + lines
    }

    func exportDiagnosticReport(credentials: [LoginCredential] = [], automationSettings: AutomationSettings? = nil) -> String {
        let now = DateFormatters.fullTimestamp.string(from: Date())
        var report = """
        ========================================
        DIAGNOSTIC REPORT FOR RORK MAX
        Generated: \(now)
        ========================================

        SYSTEM INFO:
        - iOS Version: \(UIDevice.current.systemVersion)
        - Device: \(UIDevice.current.model)
        - App Entries: \(entries.count)
        - Errors: \(errorCount)
        - Warnings: \(warningCount)
        - Critical: \(criticalCount)
        - Healing Success Rate: \(String(format: "%.0f%%", healingSuccessRate * 100))

        CREDENTIAL SUMMARY:
        - Total: \(credentials.count)
        - Working: \(credentials.filter { $0.status == .working }.count)
        - No Acc: \(credentials.filter { $0.status == .noAcc }.count)
        - Perm Disabled: \(credentials.filter { $0.status == .permDisabled }.count)
        - Temp Disabled: \(credentials.filter { $0.status == .tempDisabled }.count)
        - Unsure: \(credentials.filter { $0.status == .unsure }.count)
        - Untested: \(credentials.filter { $0.status == .untested }.count)

        DEBUG LOGIN BUTTON CONFIGS:
        \(debugButtonConfigSummary())

        CALIBRATION DATA:
        \(calibrationSummary())

        """

        if let settings = automationSettings {
            report += """
            AUTOMATION SETTINGS:
            - Login Button Mode: \(settings.loginButtonDetectionMode.rawValue)
            - Click Method: \(settings.loginButtonClickMethod.rawValue)
            - Max Concurrency: \(settings.maxConcurrency)
            - Stealth JS: \(settings.stealthJSInjection)
            - Fingerprint Spoof: \(settings.fingerprintSpoofing)
            - Session Isolation: \(settings.sessionIsolation.rawValue)
            - Page Load Timeout: \(Int(settings.pageLoadTimeout))s
            - Submit Retries: \(settings.submitRetryCount)
            - Max Submit Cycles: \(settings.maxSubmitCycles)
            - Pattern Learning: \(settings.patternLearningEnabled)
            - URL Flow Assignments: \(settings.urlFlowAssignments.count)

            """
        }

        report += """
        CATEGORY BREAKDOWN:
        \(categoryBreakdown.map { "  - \($0.category.rawValue): \($0.count)" }.joined(separator: "\n"))

        LEVEL BREAKDOWN:
        \(levelBreakdown.map { "  - \($0.level.rawValue): \($0.count)" }.joined(separator: "\n"))

        ========================================
        ERROR LOG (last 100):
        ========================================
        \(entries.filter { $0.level >= .error }.prefix(100).map(\.exportLine).joined(separator: "\n"))

        ========================================
        WARNING LOG (last 50):
        ========================================
        \(entries.filter { $0.level == .warning }.prefix(50).map(\.exportLine).joined(separator: "\n"))

        ========================================
        FULL LOG (last 500):
        ========================================
        \(entries.prefix(500).map(\.exportLine).joined(separator: "\n"))

        ========================================
        HEALING LOG:
        ========================================
        \(exportHealingLog())

        ========================================
        END OF DIAGNOSTIC REPORT
        ========================================
        """

        return report
    }

    func exportCompleteLog(credentials: [LoginCredential] = [], cards: [PPSRCard] = []) -> String {
        let now = DateFormatters.fullTimestamp.string(from: Date())
        let appDataService = AppDataExportService.shared
        let urlService = LoginURLRotationService.shared
        let proxyService = ProxyRotationService.shared
        let dnsService = PPSRDoHService.shared
        let blacklistService = BlacklistService.shared
        let emailService = PPSREmailRotationService.shared
        let flowService = FlowPersistenceService.shared
        let debugButtonService = DebugLoginButtonService.shared
        let centralSettings = CentralSettingsService.shared

        var report = """
        ========================================
        COMPLETE DIAGNOSTIC & DATA EXPORT LOG
        Generated: \(now)
        ========================================

        DEVICE & SYSTEM INFO:
        - iOS Version: \(UIDevice.current.systemVersion)
        - Device Model: \(UIDevice.current.model)
        - Device Name: \(UIDevice.current.name)
        - System Name: \(UIDevice.current.systemName)
        - App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        - Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")

        DEBUG LOG STATISTICS:
        - Total Log Entries: \(entries.count)
        - Total Logged (Session): \(totalEntriesLogged)
        - Total Evicted: \(totalEntriesEvicted)
        - Errors: \(errorCount)
        - Warnings: \(warningCount)
        - Critical: \(criticalCount)
        - Healing Events: \(errorHealingLog.count)
        - Healing Success Rate: \(String(format: "%.1f%%", healingSuccessRate * 100))
        - Active Sessions: \(uniqueSessionIds.count)

        DATA SUMMARY:
        - Total Credentials: \(credentials.count)
        - Working Credentials: \(credentials.filter { $0.status == .working }.count)
        - Total Cards: \(cards.count)
        - Working Cards: \(cards.filter { $0.status == .working }.count)
        - Joe URLs: \(urlService.joeURLs.count)
        - Ignition URLs: \(urlService.ignitionURLs.count)
        - Joe Proxies: \(proxyService.savedProxies.count)
        - Ignition Proxies: \(proxyService.ignitionProxies.count)
        - PPSR Proxies: \(proxyService.ppsrProxies.count)
        - Joe VPN Configs: \(proxyService.joeVPNConfigs.count)
        - Ignition VPN Configs: \(proxyService.ignitionVPNConfigs.count)
        - PPSR VPN Configs: \(proxyService.ppsrVPNConfigs.count)
        - Joe WireGuard Configs: \(proxyService.joeWGConfigs.count)
        - Ignition WireGuard Configs: \(proxyService.ignitionWGConfigs.count)
        - PPSR WireGuard Configs: \(proxyService.ppsrWGConfigs.count)
        - DNS Servers: \(dnsService.managedProviders.count)
        - Blacklist Entries: \(blacklistService.blacklistedEmails.count)
        - Email Rotation List: \(emailService.emails.count)
        - Recorded Flows: \(flowService.loadFlows().count)
        - Debug Button Configs: \(debugButtonService.configs.count)

        ========================================
        AUTOMATION SETTINGS (ALL MODES)
        ========================================

        LOGIN/GLOBAL MODE:
        \(formatAutomationSettings(centralSettings.loginAutomationSettings))

        UNIFIED SESSION MODE:
        \(formatAutomationSettings(centralSettings.unifiedAutomationSettings))

        DUALFIND MODE:
        \(formatAutomationSettings(centralSettings.dualFindAutomationSettings))

        ========================================
        NETWORK CONFIGURATION
        ========================================

        CONNECTION MODES:
        - Joe: \(proxyService.joeConnectionMode.label)
        - Ignition: \(proxyService.ignitionConnectionMode.label)
        - PPSR: \(proxyService.ppsrConnectionMode.label)
        - Unified: \(proxyService.unifiedConnectionMode.label)

        NETWORK REGION: \(proxyService.networkRegion.label)

        IP ROUTING:
        - Mode: \(DeviceProxyService.shared.ipRoutingMode.label)
        - Rotation Interval: \(DeviceProxyService.shared.rotationInterval.rawValue)
        - Rotate on Batch Start: \(DeviceProxyService.shared.rotateOnBatchStart)
        - Rotate on Fingerprint Detection: \(DeviceProxyService.shared.rotateOnFingerprintDetection)
        - Local Proxy Enabled: \(DeviceProxyService.shared.localProxyEnabled)
        - Auto Failover: \(DeviceProxyService.shared.autoFailoverEnabled)
        - Health Check Interval: \(DeviceProxyService.shared.healthCheckInterval)s
        - Max Failures Before Rotation: \(DeviceProxyService.shared.maxFailuresBeforeRotation)

        ========================================
        URL PERFORMANCE DATA
        ========================================

        \(appDataService.exportURLHistory())

        ========================================
        CREDENTIAL DETAILS
        ========================================

        \(exportCredentialDetails(credentials))

        ========================================
        CARD DETAILS
        ========================================

        \(exportCardDetails(cards))

        ========================================
        PROXY STATUS
        ========================================

        \(appDataService.exportProxyState())

        ========================================
        VPN & WIREGUARD STATUS
        ========================================

        \(appDataService.exportVPNState())

        ========================================
        DNS CONFIGURATION
        ========================================

        \(appDataService.exportDNSState())

        ========================================
        BLACKLIST
        ========================================

        \(appDataService.exportBlacklistState())

        ========================================
        DEBUG BUTTON CONFIGURATIONS
        ========================================

        \(debugButtonConfigSummary())

        ========================================
        CALIBRATION DATA
        ========================================

        \(calibrationSummary())

        ========================================
        LOG CATEGORY BREAKDOWN
        ========================================

        \(categoryBreakdown.map { "  - \($0.category.rawValue): \($0.count)" }.joined(separator: "\n"))

        ========================================
        LOG LEVEL BREAKDOWN
        ========================================

        \(levelBreakdown.map { "  - \($0.level.rawValue): \($0.count)" }.joined(separator: "\n"))

        ========================================
        ERROR LOG (last 200)
        ========================================

        \(entries.filter { $0.level >= .error }.prefix(200).map(\.exportLine).joined(separator: "\n"))

        ========================================
        WARNING LOG (last 100)
        ========================================

        \(entries.filter { $0.level == .warning }.prefix(100).map(\.exportLine).joined(separator: "\n"))

        ========================================
        HEALING LOG (all events)
        ========================================

        \(exportHealingLog())

        ========================================
        FULL DEBUG LOG (last 1000)
        ========================================

        \(entries.prefix(1000).map(\.exportLine).joined(separator: "\n"))

        ========================================
        END OF COMPLETE LOG
        ========================================
        """

        return report
    }

    func exportCompleteLogToFile(credentials: [LoginCredential] = [], cards: [PPSRCard] = []) -> URL? {
        persistence.exportCompleteLogToFile(content: exportCompleteLog(credentials: credentials, cards: cards))
    }

    private func formatAutomationSettings(_ settings: AutomationSettings) -> String {
        """
        - Max Concurrency: \(settings.maxConcurrency)
        - Detection Mode: \(settings.loginButtonDetectionMode.rawValue)
        - Click Method: \(settings.loginButtonClickMethod.rawValue)
        - Session Isolation: \(settings.sessionIsolation.rawValue)
        - Stealth JS: \(settings.stealthJSInjection)
        - Fingerprint Spoofing: \(settings.fingerprintSpoofing)
        - User Agent Rotation: \(settings.userAgentRotation)
        - Viewport Randomization: \(settings.viewportRandomization)
        - Human Mouse Movement: \(settings.humanMouseMovement)
        - Human Scroll Jitter: \(settings.humanScrollJitter)
        - Typing Speed: \(settings.typingSpeedMinMs)-\(settings.typingSpeedMaxMs)ms
        - Typing Jitter: \(settings.typingJitterEnabled)
        - Page Load Timeout: \(Int(settings.pageLoadTimeout))s
        - Field Verification Timeout: \(Int(settings.fieldVerificationTimeout))s
        - Wait For Response: \(settings.waitForResponseSeconds)s
        - Submit Retry Count: \(settings.submitRetryCount)
        - Max Submit Cycles: \(settings.maxSubmitCycles)
        - Max Requeue Count: \(settings.maxRequeueCount)
        - Pattern Learning: \(settings.patternLearningEnabled)
        - Auto Calibration: \(settings.autoCalibrationEnabled)
        - Field Verification: \(settings.fieldVerificationEnabled)
        - Clear Cookies: \(settings.clearCookiesBetweenAttempts)
        - Fresh WebView Per Attempt: \(settings.freshWebViewPerAttempt)
        """
    }

    private func exportCredentialDetails(_ credentials: [LoginCredential]) -> String {
        guard !credentials.isEmpty else { return "No credentials to export" }

        var lines: [String] = []
        for cred in credentials {
            lines.append("Username: \(cred.username)")
            lines.append("  Status: \(cred.status.rawValue)")
            lines.append("  Added: \(DateFormatters.exportTimestamp.string(from: cred.addedAt))")
            lines.append("  Total Tests: \(cred.totalTests)")
            lines.append("  Success Count: \(cred.successCount)")
            lines.append("  Success Rate: \(cred.successRateFormatted)")
            if !cred.notes.isEmpty {
                lines.append("  Notes: \(cred.notes)")
            }
            if !cred.testResults.isEmpty {
                lines.append("  Recent Tests:")
                for result in cred.testResults.prefix(5) {
                    let icon = result.success ? "✓" : "✗"
                    let detail = result.responseDetail ?? result.errorMessage ?? "N/A"
                    lines.append("    \(icon) \(DateFormatters.exportTimestamp.string(from: result.timestamp)) | \(result.formattedDuration) | \(detail)")
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func exportCardDetails(_ cards: [PPSRCard]) -> String {
        guard !cards.isEmpty else { return "No cards to export" }

        var lines: [String] = []
        for card in cards {
            lines.append("Card: ****\(card.number.suffix(4))")
            lines.append("  Brand: \(card.brand.rawValue)")
            lines.append("  Status: \(card.status.rawValue)")
            lines.append("  Expiry: \(card.expiryMonth)/\(card.expiryYear)")
            lines.append("  Added: \(DateFormatters.exportTimestamp.string(from: card.addedAt))")
            lines.append("  Total Tests: \(card.totalTests)")
            lines.append("  Success Count: \(card.successCount)")
            if let binData = card.binData, binData.isLoaded {
                lines.append("  BIN Info: \(binData.issuer) (\(binData.country))")
                lines.append("  Card Type: \(binData.type) / \(binData.category)")
            }
            if !card.testResults.isEmpty {
                lines.append("  Recent Tests:")
                for result in card.testResults.prefix(5) {
                    let icon = result.success ? "✓" : "✗"
                    lines.append("    \(icon) \(DateFormatters.exportTimestamp.string(from: result.timestamp)) | VIN: \(result.vin) | \(result.formattedDuration)")
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    func classifyNetworkError(_ error: Error) -> (code: Int, domain: String, userMessage: String, isRetryable: Bool) {
        let nsError = error as NSError
        let retryableCodes: Set<Int> = [
            NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet, NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed,
            NSURLErrorSecureConnectionFailed
        ]
        let isRetryable = nsError.domain == NSURLErrorDomain && retryableCodes.contains(nsError.code)
        let userMessage: String
        switch nsError.code {
        case NSURLErrorTimedOut: userMessage = "Connection timed out"
        case NSURLErrorNotConnectedToInternet: userMessage = "No internet connection"
        case NSURLErrorCannotFindHost: userMessage = "DNS resolution failed"
        case NSURLErrorCannotConnectToHost: userMessage = "Cannot connect to server"
        case NSURLErrorNetworkConnectionLost: userMessage = "Network connection lost"
        case NSURLErrorDNSLookupFailed: userMessage = "DNS lookup failed"
        case NSURLErrorSecureConnectionFailed: userMessage = "SSL/TLS handshake failed"
        default: userMessage = nsError.localizedDescription
        }
        return (nsError.code, nsError.domain, userMessage, isRetryable)
    }

    // MARK: - Nonisolated Background Logging Bridge

    nonisolated static func logBackground(
        _ message: String,
        category: DebugLogCategory = .system,
        level: DebugLogLevel = .info,
        detail: String? = nil,
        sessionId: String? = nil,
        durationMs: Int? = nil,
        metadata: [String: String]? = nil
    ) {
        Task { @MainActor in
            DebugLogger.shared.log(message, category: category, level: level, detail: detail, sessionId: sessionId, durationMs: durationMs, metadata: metadata)
        }
    }

    // MARK: - Private

    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.flushPendingEntries()
        }
    }

    private func flushPendingEntries() {
        flushTask?.cancel()
        flushTask = nil
        guard !pendingEntries.isEmpty else { return }
        let batch = pendingEntries
        pendingEntries.removeAll()

        for entry in batch {
            if entry.level >= .error { cachedErrorCount += 1 }
            if entry.level == .warning { cachedWarningCount += 1 }
            if entry.level >= .critical { cachedCriticalCount += 1 }
        }

        entries.insert(contentsOf: batch.reversed(), at: 0)
        totalEntriesLogged += batch.count

        if entries.count > maxEntries {
            let overflow = Array(entries.suffix(from: maxEntries))
            updateCachedCounts(removing: overflow)
            totalEntriesEvicted += overflow.count
            persistence.scheduleDiskFlush(entries: overflow)
            entries.removeLast(entries.count - maxEntries)
        }

        if batch.contains(where: { $0.level >= .critical }) { schedulePersistCritical() }
        if batch.contains(where: { $0.level >= .error }) { scheduleAutoPersist() }
        didChange.send()
    }

    private func updateCachedCounts(removing evicted: [DebugLogEntry]) {
        for entry in evicted {
            if entry.level >= .error { cachedErrorCount = max(0, cachedErrorCount - 1) }
            if entry.level == .warning { cachedWarningCount = max(0, cachedWarningCount - 1) }
            if entry.level >= .critical { cachedCriticalCount = max(0, cachedCriticalCount - 1) }
        }
    }

    private func scheduleAutoPersist() {
        guard persistTask == nil || persistTask?.isCancelled == true else { return }
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            self?.persistLatestLog()
        }
    }

    private func schedulePersistCritical() {
        guard persistTask == nil else { return }
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.persistence.persistCriticalEntries(entries: self?.entries ?? [])
            self?.persistTask = nil
        }
    }

    private func startAutoPersist() {
        let task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                self?.persistLatestLog()
            }
        }
        _ = task
    }

    private func debugButtonConfigSummary() -> String {
        let configs = DebugLoginButtonService.shared.configs
        if configs.isEmpty { return "  No saved debug login button configs" }
        return configs.map { host, config in
            let method = config.successfulMethod?.methodName ?? "none"
            let confirmed = config.userConfirmed ? "USER" : "AUTO"
            return "  - \(host): \(method) [\(confirmed)] attempts=\(config.totalAttempts)"
        }.joined(separator: "\n")
    }

    private func calibrationSummary() -> String {
        let cals = LoginCalibrationService.shared.calibrations
        if cals.isEmpty { return "  No calibration data" }
        return cals.map { host, cal in
            let email = cal.emailField?.cssSelector ?? "none"
            let pass = cal.passwordField?.cssSelector ?? "none"
            let btn = cal.loginButton?.cssSelector ?? "none"
            return "  - \(host): email=\(email) pass=\(pass) btn=\(btn) confidence=\(String(format: "%.0f%%", cal.confidence * 100)) success=\(cal.successCount) fail=\(cal.failCount)"
        }.joined(separator: "\n")
    }
}
