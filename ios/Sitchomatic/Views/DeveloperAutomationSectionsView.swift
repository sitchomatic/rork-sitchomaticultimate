import SwiftUI

struct DeveloperAutomationSectionsView: View {
    @Bindable var vm: PPSRAutomationViewModel
    @Bindable var unifiedVM: UnifiedSessionViewModel
    @Bindable var dualFindVM: DualFindViewModel
    @Binding var showSyncToast: Bool

    var body: some View {
        Group {
            syncAllModesSection
            automationSettingsLinkSection
            loginSettingsLinkSection
            ppsrSettingsLinkSection
            unifiedSessionLinkSection
            dualFindLinkSection
        }
    }

    // MARK: - Sync All Modes

    private var syncAllModesSection: some View {
        Section {
            Button {
                let source = vm.automationSettings
                let central = CentralSettingsService.shared
                central.persistLoginAutomationSettings(source)
                central.persistUnifiedAutomationSettings(source)
                central.persistDualFindAutomationSettings(source)
                withAnimation(.spring(duration: 0.3)) { showSyncToast = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation { showSyncToast = false }
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.green.opacity(0.3), .cyan.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.body.bold())
                            .foregroundStyle(.green)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync All Modes")
                            .font(.subheadline.bold())
                        Text("Push PPSR settings → Login, Unified & DualFind")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Button {
                let source = unifiedVM.automationSettings
                let central = CentralSettingsService.shared
                central.persistLoginAutomationSettings(source)
                central.persistUnifiedAutomationSettings(source)
                central.persistDualFindAutomationSettings(source)
                vm.automationSettings = central.loginAutomationSettings
                vm.persistSettings()
                withAnimation(.spring(duration: 0.3)) { showSyncToast = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation { showSyncToast = false }
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.cyan.opacity(0.3), .green.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.body.bold())
                            .foregroundStyle(.cyan)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync from Unified")
                            .font(.subheadline.bold())
                        Text("Push Unified settings → PPSR, Login & DualFind")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Button {
                let source = dualFindVM.automationSettings
                let central = CentralSettingsService.shared
                central.persistLoginAutomationSettings(source)
                central.persistUnifiedAutomationSettings(source)
                central.persistDualFindAutomationSettings(source)
                vm.automationSettings = central.loginAutomationSettings
                vm.persistSettings()
                withAnimation(.spring(duration: 0.3)) { showSyncToast = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation { showSyncToast = false }
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.purple.opacity(0.3), .pink.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.body.bold())
                            .foregroundStyle(.purple)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync from DualFind")
                            .font(.subheadline.bold())
                        Text("Push DualFind settings → PPSR, Login & Unified")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Label("Cross-Mode Sync", systemImage: "arrow.triangle.2.circlepath.circle.fill")
        } footer: {
            Text("Copies all automation settings from one mode to all others. Each mode persists independently.")
        }
    }

    // MARK: - Automation Settings Link

    private var automationSettingsLinkSection: some View {
        Section {
            NavigationLink {
                DeveloperAutomationSettingsView(settings: Binding(
                    get: { vm.automationSettings },
                    set: { newSettings in
                        vm.automationSettings = newSettings
                        vm.persistSettings()
                        CentralSettingsService.shared.persistLoginAutomationSettings(newSettings)
                    }
                ))
            } label: {
                devRow(
                    icon: "gearshape.2.fill",
                    title: "All Automation Settings",
                    subtitle: "\(automationPropertyCount) configurable properties",
                    color: .indigo,
                    badge: "\(automationPropertyCount)"
                )
            }
        } header: {
            Label("Automation Engine", systemImage: "cpu.fill")
        } footer: {
            Text("Master config object controlling page loading, field detection, credential entry, patterns, fallbacks, submit behavior, stealth, MFA, CAPTCHA, sessions, WebView, delays, and more.")
        }
    }

    private var automationPropertyCount: Int { 180 }

    // MARK: - Login Settings Link

    private var loginSettingsLinkSection: some View {
        Section {
            LabeledContent("Max Concurrency") {
                Text("\(AutomationSettings.defaultMaxConcurrency)")
            }
            LabeledContent("Debug Mode Default") {
                Text("true").foregroundStyle(.green)
            }
            LabeledContent("Stealth Default") {
                Text("true").foregroundStyle(.green)
            }
            LabeledContent("Target Site Default") {
                Text("Joe Fortune").foregroundStyle(.orange)
            }
            LabeledContent("Test Timeout Default") {
                Text("90s (min \(Int(AutomationSettings.minimumTimeoutSeconds))s)")
            }
            LabeledContent("Auto Retry Default") {
                Text("true / 3 attempts").foregroundStyle(.green)
            }
            LabeledContent("Save Debounce") {
                Text("Credentials: 500ms / Settings: 300ms")
                    .font(.caption2)
            }
        } header: {
            Label("Login Defaults", systemImage: "person.crop.circle.fill")
        }
    }

    // MARK: - PPSR Settings Link

    private var ppsrSettingsLinkSection: some View {
        Section {
            LabeledContent("Test Email") {
                Text(vm.testEmail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Max Concurrency") {
                Text("\(vm.maxConcurrency)")
            }
            LabeledContent("Debug Mode") {
                Image(systemName: vm.debugMode ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(vm.debugMode ? .green : .red)
            }
            LabeledContent("Email Rotation") {
                Image(systemName: vm.useEmailRotation ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(vm.useEmailRotation ? .green : .red)
            }
            LabeledContent("Stealth Enabled") {
                Image(systemName: vm.stealthEnabled ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(vm.stealthEnabled ? .green : .red)
            }
            LabeledContent("Retry Submit on Fail") {
                Image(systemName: vm.retrySubmitOnFail ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(vm.retrySubmitOnFail ? .green : .red)
            }
            LabeledContent("Test Timeout") {
                Text("\(Int(vm.testTimeout))s")
            }
            LabeledContent("Speed Multiplier") {
                Text(vm.speedMultiplier.rawValue)
                    .foregroundStyle(.orange)
            }
            LabeledContent("Active Gateway") {
                Text(vm.activeGateway.rawValue)
            }
            LabeledContent("Auto Retry") {
                Text(vm.autoRetryEnabled ? "Enabled" : "Disabled")
                    .foregroundStyle(vm.autoRetryEnabled ? .green : .red)
            }
        } header: {
            Label("PPSR Automation Defaults", systemImage: "creditcard.fill")
        }
    }

    // MARK: - Unified Session Link

    private var unifiedSessionLinkSection: some View {
        Section {
            NavigationLink {
                UnifiedSessionSettingsView(vm: unifiedVM)
            } label: {
                devRow(
                    icon: "rectangle.stack.fill",
                    title: "Unified Session Settings",
                    subtitle: "V\(unifiedVM.config.systemVersion) dual-site session config",
                    color: .cyan
                )
            }

            LabeledContent("System Version") {
                Text("V\(unifiedVM.config.systemVersion)")
                    .foregroundStyle(.cyan)
            }
            LabeledContent("Concurrency") {
                Text("\(unifiedVM.automationSettings.maxConcurrency)")
            }
            LabeledContent("Max Attempts Per Site") {
                Text("\(unifiedVM.config.maxAttemptsPerSite)")
            }
            LabeledContent("Typing Speed") {
                Text("\(unifiedVM.automationSettings.typingSpeedMinMs)–\(unifiedVM.automationSettings.typingSpeedMaxMs)ms")
            }
            LabeledContent("Click Jitter") {
                Text("\(unifiedVM.automationSettings.v42ClickJitterPx)px")
            }
            LabeledContent("Stealth") {
                Image(systemName: unifiedVM.stealthEnabled ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(unifiedVM.stealthEnabled ? .green : .red)
            }
            LabeledContent("Settlement Gate") {
                Image(systemName: unifiedVM.automationSettings.v42SettlementGateEnabled ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(unifiedVM.automationSettings.v42SettlementGateEnabled ? .green : .red)
            }
            LabeledContent("Strategy") {
                Text(unifiedVM.automationSettings.concurrencyStrategy.label)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        } header: {
            Label("Unified Session Config", systemImage: "rectangle.stack.fill")
        } footer: {
            Text("Live values from UnifiedSessionViewModel. Tap to configure. Persist key: unified_automation_settings_v1")
        }
    }

    // MARK: - DualFind Link

    private var dualFindLinkSection: some View {
        Section {
            NavigationLink {
                DualFindSettingsView(vm: dualFindVM)
            } label: {
                devRow(
                    icon: "person.2.fill",
                    title: "DualFind Settings",
                    subtitle: "V5.2 email × password dual-site scan",
                    color: .purple
                )
            }

            LabeledContent("Auto Advance") {
                Image(systemName: dualFindVM.autoAdvanceEnabled ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(dualFindVM.autoAdvanceEnabled ? .green : .red)
            }
            LabeledContent("Session Count") {
                Text(dualFindVM.sessionCount.label)
            }
            LabeledContent("Screenshot Count") {
                Text(dualFindVM.screenshotCount.label)
            }
            LabeledContent("Stealth") {
                Image(systemName: dualFindVM.stealthEnabled ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(dualFindVM.stealthEnabled ? .green : .red)
            }
            LabeledContent("Debug Mode") {
                Image(systemName: dualFindVM.debugMode ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(dualFindVM.debugMode ? .green : .red)
            }
            LabeledContent("Timeout") {
                Text("\(Int(dualFindVM.testTimeout))s")
            }
            LabeledContent("Max Concurrency") {
                Text("\(dualFindVM.automationSettings.maxConcurrency)")
            }
            LabeledContent("Strategy") {
                Text(dualFindVM.automationSettings.concurrencyStrategy.label)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        } header: {
            Label("DualFind Config", systemImage: "person.2.fill")
        } footer: {
            Text("Live values from DualFindViewModel. Tap to configure. Persist key: dual_find_automation_settings_v1")
        }
    }

    // MARK: - Helpers

    func devRow(icon: String, title: String, subtitle: String, color: Color, badge: String? = nil) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if let badge = badge {
                Text(badge)
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(color, in: Capsule())
            }
        }
    }
}
