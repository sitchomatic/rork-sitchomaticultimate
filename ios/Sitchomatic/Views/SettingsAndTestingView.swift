import SwiftUI
import UIKit

struct SettingsAndTestingView: View {
    @State private var vm = PPSRAutomationViewModel.shared
    @State private var showCopiedToast: Bool = false
    @State private var toastMessage: String = "Copied to clipboard"
    @State private var shareFileURL: URL?
    @State private var nordService = NordVPNService.shared
    @State private var showCompleteLogConfirm: Bool = false
    @State private var completeLogAction: (() -> Void)?
    private let proxyService = ProxyRotationService.shared

    var body: some View {
        NavigationStack {
            List {
                automationQuickControlsSection
                appearanceSection
                testingToolsSection
                networkAndVPNSection
                debugAndDiagnosticsSection
                dataManagementSection
                developerSettingsLinkSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .onDisappear {
                vm.persistSettings()
            }
        }
        .withMainMenuButton()
        .preferredColorScheme(CentralSettingsService.shared.effectiveColorScheme)
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                Text(toastMessage)
                    .font(.subheadline.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(.green.gradient, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: Binding(
            get: { shareFileURL != nil },
            set: { if !$0 { shareFileURL = nil } }
        )) {
            if let url = shareFileURL {
                ShareSheetView(items: [url])
            }
        }
        .alert("Export Contains Sensitive Data", isPresented: $showCompleteLogConfirm) {
            Button("Export Anyway", role: .destructive) {
                completeLogAction?()
                completeLogAction = nil
            }
            Button("Cancel", role: .cancel) {
                completeLogAction = nil
            }
        } message: {
            Text("The complete log includes credentials, proxy secrets, and other sensitive configuration. Do not share it publicly.")
        }
    }

    // MARK: - Automation Quick Controls

    private var automationQuickControlsSection: some View {
        Section {
            Toggle(isOn: $vm.stealthEnabled) {
                settingsRow(
                    icon: "eye.slash.fill",
                    title: "Ultra Stealth Mode",
                    subtitle: "Hide automation fingerprints",
                    color: .purple
                )
            }

            Toggle(isOn: $vm.debugMode) {
                settingsRow(
                    icon: "ladybug.fill",
                    title: "Debug Mode",
                    subtitle: "Verbose logging & screenshots",
                    color: .orange
                )
            }

            Toggle(isOn: $vm.autoRetryEnabled) {
                settingsRow(
                    icon: "arrow.triangle.2.circlepath.circle.fill",
                    title: "Auto-Retry Failed",
                    subtitle: "Automatically retry failed attempts",
                    color: .mint
                )
            }

            Picker("Max Sessions", selection: $vm.maxConcurrency) {
                ForEach(1...7, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
        } header: {
            Label("Automation Quick Controls", systemImage: "bolt.circle.fill")
        } footer: {
            Text("Quick toggles for the most commonly adjusted automation settings.")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            Picker(selection: Binding(
                get: { CentralSettingsService.shared.appearanceMode },
                set: { newMode in
                    CentralSettingsService.shared.appearanceMode = newMode
                    vm.appearanceMode = newMode
                }
            )) {
                ForEach(AppAppearanceMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            } label: {
                HStack(spacing: 10) { Image(systemName: "paintbrush.fill").foregroundStyle(.purple); Text("Appearance") }
            }
        } header: {
            Label("App Settings", systemImage: "gearshape.fill")
        }
    }

    // MARK: - Testing Tools

    private var testingToolsSection: some View {
        Section {
            NavigationLink {
                SuperTestView()
            } label: {
                settingsRow(
                    icon: "bolt.horizontal.circle.fill",
                    title: "Super Test",
                    subtitle: "Full infrastructure validation",
                    color: .purple
                )
            }

            NavigationLink {
                IPScoreTestView()
            } label: {
                settingsRow(
                    icon: "network.badge.shield.half.filled",
                    title: "IP Score Test",
                    subtitle: "8x concurrent IP quality analysis",
                    color: .indigo
                )
            }
        } header: {
            Label("Testing Tools", systemImage: "flask.fill")
        } footer: {
            Text("Run full infrastructure tests and IP quality checks.")
        }
    }

    // MARK: - Network & VPN

    private var networkAndVPNSection: some View {
        Section {
            NavigationLink {
                DeviceNetworkSettingsView()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "network.badge.shield.half.filled")
                            .font(.body)
                            .foregroundStyle(.blue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Device Network Settings").font(.subheadline.bold())
                        Text("Proxy, VPN, WireGuard, DNS — all modes")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(proxyService.unifiedConnectionMode.label)
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12)).clipShape(Capsule())
                }
            }

            NavigationLink {
                NordLynxConfigView()
            } label: {
                settingsRow(
                    icon: "shield.checkered",
                    title: "Nord Config",
                    subtitle: "WireGuard & OpenVPN generation",
                    color: Color(red: 0.0, green: 0.78, blue: 1.0)
                )
            }

            NavigationLink {
                NetworkRepairView()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.body)
                            .foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Repair Network").font(.subheadline.bold())
                        Text("Full restart of all network protocols")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if NetworkRepairService.shared.isRepairing {
                        ProgressView()
                            .controlSize(.mini)
                    } else if let result = NetworkRepairService.shared.lastRepairResult {
                        Image(systemName: result.overallSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.overallSuccess ? .green : .red)
                            .font(.caption)
                    }
                }
            }
        } header: {
            Label("Network & VPN", systemImage: "lock.shield.fill")
        } footer: {
            Text("Network configs are device-wide. Changes apply to Joe, Ignition & PPSR.")
        }
    }

    // MARK: - Debug & Diagnostics

    private var debugAndDiagnosticsSection: some View {
        Group {
            Section {
                NavigationLink {
                    DebugLogView()
                } label: {
                    settingsRow(
                        icon: "doc.text.magnifyingglass",
                        title: "Full Debug Log",
                        subtitle: "View all debug entries",
                        color: .purple
                    )
                }

                NavigationLink {
                    SettingsConsoleView()
                } label: {
                    settingsRow(
                        icon: "terminal.fill",
                        title: "Console",
                        subtitle: "Live log output",
                        color: .green
                    )
                }

                NavigationLink {
                    NoticesView()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.body)
                                .foregroundStyle(.orange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notices").font(.subheadline.bold())
                            Text("Failure log & auto-retry history")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        let count = NoticesService.shared.unreadCount
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(.caption2, design: .monospaced, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Color.orange, in: Capsule())
                        }
                    }
                }
            } header: {
                Label("Debug & Diagnostics", systemImage: "stethoscope")
            }

            Section {
                Button {
                    completeLogAction = {
                        let text = DebugLogger.shared.exportCompleteLog(
                            automationSettings: vm.automationSettings
                        )
                        UIPasteboard.general.string = text
                        toastMessage = "Copied to clipboard"
                        withAnimation(.spring(duration: 0.3)) { showCopiedToast = true }
                        Task { try? await Task.sleep(for: .seconds(1.5)); withAnimation { showCopiedToast = false } }
                    }
                    showCompleteLogConfirm = true
                } label: {
                    settingsRow(
                        icon: "doc.badge.gearshape",
                        title: "Export Complete Log",
                        subtitle: "Copy diagnostics + config (contains secrets)",
                        color: .indigo
                    )
                }

                Button {
                    completeLogAction = {
                        shareFileURL = DebugLogger.shared.exportCompleteLogToFile(
                            automationSettings: vm.automationSettings
                        )
                    }
                    showCompleteLogConfirm = true
                } label: {
                    settingsRow(
                        icon: "square.and.arrow.up",
                        title: "Share Complete Log File",
                        subtitle: "Full debug, diagnostics, and config (contains secrets)",
                        color: .purple
                    )
                }
            } header: {
                Label("Complete Log", systemImage: "doc.badge.gearshape")
            }
        }
    }

    // MARK: - Data Management

    private var dataManagementSection: some View {
        Section {
            Button {
                let currentSettings = CentralSettingsService.shared.loginAutomationSettings
                CentralSettingsService.shared.persistLoginAutomationSettings(currentSettings)
                CentralSettingsService.shared.persistUnifiedAutomationSettings(currentSettings)
                CentralSettingsService.shared.persistDualFindAutomationSettings(currentSettings)
                toastMessage = "Saved as new defaults"
                withAnimation(.spring(duration: 0.3)) { showCopiedToast = true }
                Task { try? await Task.sleep(for: .seconds(1.5)); withAnimation { showCopiedToast = false } }
            } label: {
                settingsRow(
                    icon: "square.and.arrow.down.on.square.fill",
                    title: "Save as New Defaults",
                    subtitle: "Save current settings as defaults for all modes",
                    color: .green
                )
            }

            Button {
                let json = AppDataExportService.shared.exportJSON()
                UIPasteboard.general.string = json
                toastMessage = "Copied to clipboard"
                withAnimation(.spring(duration: 0.3)) { showCopiedToast = true }
                Task { try? await Task.sleep(for: .seconds(1.5)); withAnimation { showCopiedToast = false } }
            } label: {
                settingsRow(
                    icon: "square.and.arrow.up.fill",
                    title: "Export All Settings",
                    subtitle: "Copy comprehensive settings JSON to clipboard",
                    color: .blue
                )
            }

            NavigationLink {
                ImportSettingsView()
            } label: {
                settingsRow(
                    icon: "square.and.arrow.down.fill",
                    title: "Import Settings",
                    subtitle: "Restore settings from JSON backup",
                    color: .purple
                )
            }

            NavigationLink {
                ConsolidatedImportExportView()
            } label: {
                settingsRow(
                    icon: "arrow.up.arrow.down.circle.fill",
                    title: "Advanced Import / Export",
                    subtitle: "Full backup & restore with preview",
                    color: .cyan
                )
            }

            NavigationLink {
                StorageFileBrowserView()
            } label: {
                settingsRow(
                    icon: "externaldrive.fill",
                    title: "Vault",
                    subtitle: "Browse persistent file storage",
                    color: .teal
                )
            }
        } header: {
            Label("Data Management", systemImage: "tray.2.fill")
        } footer: {
            Text("Save as New Defaults copies your current automation settings to all modes. Export All Settings includes everything: settings, credentials, cards, URLs, proxies, VPN/WG, DNS, blacklist, emails, flows, and button configs.")
        }
    }

    // MARK: - Developer Settings Link

    private var developerSettingsLinkSection: some View {
        Section {
            NavigationLink {
                DeveloperSettingsView()
            } label: {
                settingsRow(
                    icon: "wrench.and.screwdriver.fill",
                    title: "Developer Settings",
                    subtitle: "All configurable values & conflict resolution",
                    color: .red
                )
            }
        } header: {
            Label("Developer", systemImage: "hammer.fill")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
            LabeledContent("Profile") {
                Text(nordService.hasSelectedProfile ? nordService.activeKeyProfile.rawValue : "Not Selected")
                    .foregroundStyle(nordService.activeKeyProfile == .nick ? .blue : .purple)
            }
            LabeledContent("Engine", value: "WKWebView Live")
            LabeledContent("Storage", value: "Unlimited · Local + iCloud")
            LabeledContent("Connection") {
                Text(proxyService.unifiedConnectionMode.label)
                    .foregroundStyle(proxyService.unifiedConnectionMode == .proxy ? .blue : .cyan)
            }
            LabeledContent("Mode") { Text("Live — Real Transactions").foregroundStyle(.orange) }
        } header: {
            Text("About")
        }
    }

    // MARK: - Helpers

    private func settingsRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
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
        }
    }
}

struct SettingsConsoleView: View {
    @State private var logs: [DebugLogEntry] = []

    var body: some View {
        List {
            if logs.isEmpty {
                Text("No log entries").foregroundStyle(.tertiary)
            } else {
                ForEach(logs) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        Text(entry.formattedTime)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: 80, alignment: .leading)
                        Text(entry.level.emoji)
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .frame(width: 20)
                        Text(entry.message)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Console")
        .onAppear {
            logs = Array(DebugLogger.shared.entries.suffix(100).reversed())
        }
        .refreshable {
            logs = Array(DebugLogger.shared.entries.suffix(100).reversed())
        }
    }
}
