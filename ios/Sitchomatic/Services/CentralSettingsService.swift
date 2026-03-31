import Foundation
import Observation
import SwiftUI

/// Central source of truth for all developer and automation settings.
///
/// Consolidates the previously scattered settings persistence that was spread across
/// LoginSettingsManager, LoginViewModel, UnifiedSessionViewModel, DualFindViewModel,
/// TestDebugViewModel, DeveloperSettingsView, SettingsAndTestingView, and TimeoutResolver.
///
/// **UserDefaults keys managed:**
/// - `"automation_settings_v1"` — Login / global automation settings
/// - `"unified_automation_settings_v1"` — Unified session automation settings
/// - `"dual_find_automation_settings_v1"` — DualFind automation settings
/// - `"appearance_mode"` — Global appearance mode
@MainActor @Observable
final class CentralSettingsService {
    static let shared = CentralSettingsService()

    // MARK: - Automation Settings per Mode

    /// Login / global automation settings (key: `"automation_settings_v1"`)
    private(set) var loginAutomationSettings: AutomationSettings = AutomationSettings()

    /// Unified session automation settings (key: `"unified_automation_settings_v1"`)
    private(set) var unifiedAutomationSettings: AutomationSettings = AutomationSettings()

    /// DualFind automation settings (key: `"dual_find_automation_settings_v1"`)
    private(set) var dualFindAutomationSettings: AutomationSettings = AutomationSettings()

    // MARK: - Global Settings

    /// Global appearance mode (key: `"appearance_mode"`, default: `.dark`)
    var appearanceMode: AppAppearanceMode = .dark {
        didSet { persistAppearanceMode() }
    }

    /// Resolved color scheme for the current appearance mode.
    var effectiveColorScheme: ColorScheme? { appearanceMode.colorScheme }

    // MARK: - Keys

    private enum Keys {
        static let loginAutomation = "automation_settings_v1"
        static let unifiedAutomation = "unified_automation_settings_v1"
        static let dualFindAutomation = "dual_find_automation_settings_v1"
        static let appearanceMode = "appearance_mode"
        static let loginDefaultAutomation = "automation_default_login_v1"
        static let unifiedDefaultAutomation = "automation_default_unified_v1"
        static let dualFindDefaultAutomation = "automation_default_dual_find_v1"
    }

    // MARK: - Init

    private init() {
        loadAppearanceMode()
        loadLoginAutomationSettings()
        loadUnifiedAutomationSettings()
        loadDualFindAutomationSettings()
    }

    // MARK: - Automation Settings: Load

    /// Loads login/global automation settings from UserDefaults.
    func loadLoginAutomationSettings() {
        if let data = UserDefaults.standard.data(forKey: Keys.loginAutomation),
           let loaded = try? JSONDecoder().decode(AutomationSettings.self, from: data) {
            loginAutomationSettings = loaded.normalizedTimeouts()
        }
        PPSRStealthService.shared.applySettings(loginAutomationSettings)
        TimeoutResolver.invalidateCache()
    }

    /// Loads unified session automation settings from UserDefaults.
    func loadUnifiedAutomationSettings() {
        if let data = UserDefaults.standard.data(forKey: Keys.unifiedAutomation),
           let loaded = try? JSONDecoder().decode(AutomationSettings.self, from: data) {
            unifiedAutomationSettings = loaded.normalizedTimeouts()
        }
        PPSRStealthService.shared.applySettings(unifiedAutomationSettings)
    }

    /// Loads DualFind automation settings from UserDefaults, falling back to login/global if the
    /// DualFind-specific key has no data.
    func loadDualFindAutomationSettings() {
        if let data = UserDefaults.standard.data(forKey: Keys.dualFindAutomation),
           let loaded = try? JSONDecoder().decode(AutomationSettings.self, from: data) {
            dualFindAutomationSettings = loaded.normalizedTimeouts()
        } else if let data = UserDefaults.standard.data(forKey: Keys.loginAutomation),
                  let loaded = try? JSONDecoder().decode(AutomationSettings.self, from: data) {
            dualFindAutomationSettings = loaded.normalizedTimeouts()
        }
    }

    // MARK: - Automation Settings: Persist

    /// Persists login/global automation settings to UserDefaults, normalises timeouts, and applies stealth.
    func persistLoginAutomationSettings(_ settings: AutomationSettings) {
        loginAutomationSettings = settings.normalizedTimeouts()
        PPSRStealthService.shared.applySettings(loginAutomationSettings)
        encodeAndSave(loginAutomationSettings, forKey: Keys.loginAutomation)
        TimeoutResolver.invalidateCache()
    }

    /// Persists unified session automation settings to UserDefaults.
    func persistUnifiedAutomationSettings(_ settings: AutomationSettings) {
        unifiedAutomationSettings = settings.normalizedTimeouts()
        PPSRStealthService.shared.applySettings(unifiedAutomationSettings)
        encodeAndSave(unifiedAutomationSettings, forKey: Keys.unifiedAutomation)
    }

    /// Persists DualFind automation settings to UserDefaults.
    func persistDualFindAutomationSettings(_ settings: AutomationSettings) {
        dualFindAutomationSettings = settings.normalizedTimeouts()
        encodeAndSave(dualFindAutomationSettings, forKey: Keys.dualFindAutomation)
    }

    // MARK: - Appearance Mode

    /// Loads appearance mode from UserDefaults. Default is `.dark` (consistent across all VMs).
    private func loadAppearanceMode() {
        if let raw = UserDefaults.standard.string(forKey: Keys.appearanceMode),
           let mode = AppAppearanceMode(rawValue: raw) {
            appearanceMode = mode
        }
    }

    private func persistAppearanceMode() {
        UserDefaults.standard.set(appearanceMode.rawValue, forKey: Keys.appearanceMode)
    }

    // MARK: - Convenience

    /// Returns the automation settings for the specified mode, reading from the cached in-memory value.
    func automationSettings(for mode: SettingsMode) -> AutomationSettings {
        switch mode {
        case .login: return loginAutomationSettings
        case .unified: return unifiedAutomationSettings
        case .dualFind: return dualFindAutomationSettings
        }
    }

    /// Persists the automation settings for the specified mode.
    func persistAutomationSettings(_ settings: AutomationSettings, for mode: SettingsMode) {
        switch mode {
        case .login: persistLoginAutomationSettings(settings)
        case .unified: persistUnifiedAutomationSettings(settings)
        case .dualFind: persistDualFindAutomationSettings(settings)
        }
    }

    /// Returns the default automation settings for the specified mode, honoring any saved override.
    func defaultAutomationSettings(for mode: SettingsMode) -> AutomationSettings {
        if let override = loadDefaultOverride(for: mode) {
            return override.normalizedTimeouts()
        }
        return AutomationSettings()
    }

    /// Saves the provided settings as the new defaults for the specified mode.
    func saveDefaultAutomationSettings(_ settings: AutomationSettings, for mode: SettingsMode) {
        let normalized = settings.normalizedTimeouts()
        encodeAndSave(normalized, forKey: defaultKey(for: mode))
    }

    /// Clears any saved default override for the specified mode.
    func clearDefaultAutomationSettings(for mode: SettingsMode) {
        UserDefaults.standard.removeObject(forKey: defaultKey(for: mode))
    }

    // MARK: - Private Helpers

    private func encodeAndSave(_ settings: AutomationSettings, forKey key: String) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadDefaultOverride(for mode: SettingsMode) -> AutomationSettings? {
        let key = defaultKey(for: mode)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AutomationSettings.self, from: data)
    }

    private func defaultKey(for mode: SettingsMode) -> String {
        switch mode {
        case .login: return Keys.loginDefaultAutomation
        case .unified: return Keys.unifiedDefaultAutomation
        case .dualFind: return Keys.dualFindDefaultAutomation
        }
    }

    // MARK: - Nested Types

    @frozen enum SettingsMode: String, CaseIterable, Sendable {
        case login
        case unified
        case dualFind
    }
}
