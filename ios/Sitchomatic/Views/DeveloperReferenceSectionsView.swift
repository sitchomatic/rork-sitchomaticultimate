import SwiftUI

struct DeveloperReferenceSectionsView: View {
    @Bindable var vm: PPSRAutomationViewModel
    let proxyService: ProxyRotationService
    @Bindable var nordService: NordVPNService

    var body: some View {
        Group {
            appModeSection
            appearanceSection
            conflictSummarySection
            allKeysReferenceSection
        }
    }

    // MARK: - App Mode & Global State

    private var appModeSection: some View {
        Section {
            LabeledContent("Product Mode") {
                Text(ProductMode.ppsr.title)
                    .foregroundStyle(.orange)
            }

            LabeledContent("App Version") {
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
            }

            LabeledContent("Build Number") {
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
            }

            LabeledContent("Color Scheme") {
                Text(vm.appearanceMode.rawValue)
                    .foregroundStyle(.purple)
            }

            LabeledContent("Connection Mode") {
                Text(proxyService.unifiedConnectionMode.label)
                    .foregroundStyle(.cyan)
            }

            LabeledContent("Network Region") {
                Text(proxyService.networkRegion.rawValue)
                    .foregroundStyle(.blue)
            }

            LabeledContent("Active Key Profile") {
                Text(nordService.hasSelectedProfile ? nordService.activeKeyProfile.rawValue : "Not Selected")
                    .foregroundStyle(nordService.activeKeyProfile == .nick ? .blue : .purple)
            }
        } header: {
            Label("App Mode & Global State", systemImage: "app.badge.fill")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            Picker("Global Appearance", selection: Binding(
                get: { CentralSettingsService.shared.appearanceMode },
                set: { mode in
                    CentralSettingsService.shared.appearanceMode = mode
                    vm.appearanceMode = mode
                }
            )) {
                ForEach(AppAppearanceMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }

            LabeledContent("PPSR VM Appearance") {
                Text(vm.appearanceMode.rawValue)
            }

            LabeledContent("Central Service Value") {
                Text(CentralSettingsService.shared.appearanceMode.rawValue)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("Appearance Mode (Unified)", systemImage: "paintbrush.fill")
        } footer: {
            Text("Sets the global default appearance via CentralSettingsService and PPSR VM mode. Default: Dark.")
        }
    }

    // MARK: - Conflict Summary

    private var conflictSummarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Timeout Normalization", systemImage: "clock.badge.checkmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                Text("All timeouts enforced via CentralSettingsService.normalizedTimeouts(). Minimum: \(Int(AutomationSettings.minimumTimeoutSeconds))s. UI pickers only offer values ≥ \(Int(AutomationSettings.minimumTimeoutSeconds))s.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Label("Appearance Defaults", systemImage: "paintbrush.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                Text("Unified via CentralSettingsService. All modes default to .dark. Single UserDefaults key: \"appearance_mode\".")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Label("Concurrency Defaults", systemImage: "arrow.triangle.branch")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                Text("Central constant: AutomationSettings.defaultMaxConcurrency=\(AutomationSettings.defaultMaxConcurrency). AutomationThrottler caps at 7.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Label("Screenshot Retention", systemImage: "photo.stack")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                Text("Default: \(AutomationSettings.defaultMaxScreenshotRetention). Memory pressure trims to 100.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Label("Settings Architecture", systemImage: "cpu.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
                Text("All automation settings persist/load via CentralSettingsService. Per-mode keys: login (automation_settings_v1), unified (unified_automation_settings_v1), dualFind (dual_find_automation_settings_v1).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Label("Settings Status (Consolidated)", systemImage: "checkmark.seal.fill")
        } footer: {
            Text("All previous conflicts have been resolved via CentralSettingsService. Settings are persisted centrally with normalized timeouts.")
        }
    }

    // MARK: - All Persist Keys Reference

    private var allKeysReferenceSection: some View {
        Section {
            Group {
                keyRow("activeAppMode", category: "App")
                keyRow("hasSelectedMode", category: "App")
                keyRow("productMode", category: "App")
                keyRow("default_settings_applied_v2", category: "App")
                keyRow("appearance_mode", category: "App")
            }
            Group {
                keyRow("login_app_settings_v1", category: "Login")
                keyRow("automation_settings_v1", category: "Login")
                keyRow("saved_login_credentials_v1", category: "Login")
                keyRow("login_view_mode_prefs_v1", category: "Login")
                keyRow("login_cred_sort_option", category: "Login")
                keyRow("login_cred_sort_ascending", category: "Login")
            }
            Group {
                keyRow("app_settings_v3", category: "PPSR")
                keyRow("saved_cards_v2", category: "PPSR")
                keyRow("ppsr_active_gateway", category: "PPSR")
                keyRow("ppsr_charge_tier", category: "PPSR")
                keyRow("ppsr_speed_multiplier", category: "PPSR")
            }
            Group {
                keyRow("unified_sessions_v1", category: "Unified")
                keyRow("unified_automation_settings_v1", category: "Unified")
                keyRow("dual_find_resume_v3", category: "DualFind")
                keyRow("dual_find_automation_settings_v1", category: "DualFind")
            }
            Group {
                keyRow("device_proxy_settings_v2", category: "Proxy")
                keyRow("proxy_health_monitor_v1", category: "Proxy")
                keyRow("connection_modes_v1", category: "Network")
                keyRow("unified_connection_mode_v1", category: "Network")
                keyRow("network_region_v1", category: "Network")
                keyRow("vpn_tunnel_settings_v2", category: "VPN")
            }
            Group {
                keyRow("dns_pool_managed_v3", category: "DNS")
                keyRow("dns_pool_region_pref", category: "DNS")
                keyRow("dns_pool_auto_disable", category: "DNS")
                keyRow("hybrid_networking_health_v2", category: "Hybrid")
                keyRow("nodemaven_config_v1", category: "NodeMaven")
            }
            Group {
                keyRow("nordvpn_key_profile_v1", category: "Nord")
                keyRow("nordvpn_nick_private_key_v1", category: "Nord")
                keyRow("nordvpn_poli_private_key_v1", category: "Nord")
                keyRow("nordvpn_server_cache_v1", category: "Nord")
                keyRow("profile_network_storage_seed_v2", category: "Nord")
            }
            Group {
                keyRow("blacklist_emails_v2", category: "Blacklist")
                keyRow("blacklist_settings_v1", category: "Blacklist")
                keyRow("email_csv_list_v1", category: "Email")
                keyRow("test_schedules_v1", category: "Schedule")
                keyRow("batch_presets_v1", category: "Preset")
                keyRow("proxy_manager_sets_v1", category: "ProxyMgr")
            }
        } header: {
            Label("All Persistence Keys", systemImage: "key.fill")
        } footer: {
            Text("Complete reference of all UserDefaults / persistence keys used across the app.")
        }
    }

    // MARK: - Helpers

    private func keyRow(_ key: String, category: String) -> some View {
        HStack {
            Text(key)
                .font(.system(.caption, design: .monospaced))
            Spacer()
            Text(category)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(categoryColor(category), in: Capsule())
        }
    }

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "App": return .blue
        case "Login": return .green
        case "PPSR": return .orange
        case "Unified": return .purple
        case "DualFind": return .indigo
        case "Proxy": return .teal
        case "Network": return .cyan
        case "VPN": return .mint
        case "DNS": return .yellow
        case "Hybrid": return .pink
        case "NodeMaven": return .red
        case "Nord": return Color(red: 0, green: 0.78, blue: 1)
        case "Blacklist": return .gray
        case "Email": return .orange
        case "Schedule": return .purple
        case "Preset": return .indigo
        case "ProxyMgr": return .teal
        default: return .secondary
        }
    }
}
