import SwiftUI

struct DeveloperSettingsView: View {
    @State private var vm = PPSRAutomationViewModel.shared
    @State private var proxyHealth = ProxyHealthMonitor.shared
    @State private var deviceProxy = DeviceProxyService.shared
    @State private var nordService = NordVPNService.shared
    @State private var nodeMaven = NodeMavenService.shared
    @State private var blacklist = BlacklistService.shared
    @State private var liveDebug = LiveWebViewDebugService.shared
    private let proxyService = ProxyRotationService.shared
    private let dnsPool = DNSPoolService.shared
    private let urlRotation = LoginURLRotationService.shared
    private let grokStats = GrokUsageStats.shared
    private let screenshotManager = UnifiedScreenshotManager.shared

    var body: some View {
        List {
            conflictSummarySection
            appModeSection
            appearanceSection
            automationSettingsLinkSection
            loginSettingsLinkSection
            ppsrSettingsLinkSection
            unifiedSessionLinkSection
            dualFindLinkSection
            urlRotationSection
            screenshotSection
            networkProxySection
            proxyHealthSection
            vpnTunnelSection
            dnsPoolSection
            hybridNetworkingSection
            nodeMavenSection
            nordVPNSection
            aiGrokSection
            liveWebViewSection
            blacklistSection
            allKeysReferenceSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Developer Settings")
    }

    // MARK: - Conflict Summary

    private var conflictSummarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Timeout Normalization", systemImage: "clock.badge.exclamationmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                Text("UI pickers may show 60/90/120s but runtime enforces minimum \(Int(AutomationSettings.minimumTimeoutSeconds))s via normalizedTimeouts().")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Label("Appearance Defaults", systemImage: "paintbrush.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.purple)
                Text("LoginVM, PPSR VM, DualFind VM all default to .dark. AdvancedSettings uses \"System\" fallback. Persistence services use \"Dark\". This section unifies them.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Label("Concurrency Defaults", systemImage: "arrow.triangle.branch")
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
                Text("ViewModels default to 4, AutomationSettings.maxConcurrency=7, persistence fallback=8, presets vary 2/4/8. Central constant: AutomationSettings.defaultMaxConcurrency=\(AutomationSettings.defaultMaxConcurrency).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Label("Screenshot Retention", systemImage: "photo.stack")
                    .font(.subheadline.bold())
                    .foregroundStyle(.teal)
                Text("UnifiedScreenshotManager=200, AutomationSettings.maxScreenshotRetention=\(vm.automationSettings.maxScreenshotRetention), defaultMaxScreenshotRetention=\(AutomationSettings.defaultMaxScreenshotRetention). Memory pressure trims to 100.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Label("Known Conflicts & Inconsistencies", systemImage: "exclamationmark.triangle.fill")
        } footer: {
            Text("These are areas where defaults differ across subsystems. Review and reconcile as needed.")
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
                get: { AppAppearanceMode(rawValue: UserDefaults.standard.string(forKey: "appearance_mode") ?? "Dark") ?? .dark },
                set: { mode in
                    UserDefaults.standard.set(mode.rawValue, forKey: "appearance_mode")
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

            LabeledContent("UserDefaults Value") {
                Text(UserDefaults.standard.string(forKey: "appearance_mode") ?? "Not Set")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("Appearance Mode (Unified)", systemImage: "paintbrush.fill")
        } footer: {
            Text("Central appearance control. Changes propagate to all view models. Default: Dark.")
        }
    }

    // MARK: - Automation Settings Link

    private var automationSettingsLinkSection: some View {
        Section {
            NavigationLink {
                DeveloperAutomationSettingsView(settings: Binding(
                    get: { vm.automationSettings },
                    set: { vm.automationSettings = $0; vm.persistSettings() }
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
            LabeledContent("System Version") {
                Text("4.2")
            }
            LabeledContent("Concurrency Limit") {
                Text("4")
            }
            LabeledContent("Max Attempts Per Site") {
                Text("4")
            }
            LabeledContent("Typing Speed Range") {
                Text("60–150 WPM")
            }
            LabeledContent("Click Jitter") {
                Text("3px")
            }
            LabeledContent("Post Error Delay") {
                Text("400–700ms")
            }
            LabeledContent("Pause Duration") {
                Text("60s")
            }
            LabeledContent("Force-Stop Timeout") {
                Text("30s")
            }
            LabeledContent("Session Save Debounce") {
                Text("500ms")
            }
        } header: {
            Label("Unified Session Config", systemImage: "rectangle.stack.fill")
        }
    }

    // MARK: - DualFind Link

    private var dualFindLinkSection: some View {
        Section {
            LabeledContent("Auto Advance") {
                Text("true").foregroundStyle(.green)
            }
            LabeledContent("Session Count Default") {
                Text("3")
            }
            LabeledContent("Screenshot Count Default") {
                Text("3")
            }
            LabeledContent("Show Live Feed") {
                Text("false").foregroundStyle(.red)
            }
            LabeledContent("Max Live Screenshots") {
                Text("200")
            }
            LabeledContent("Stealth Default") {
                Text("true").foregroundStyle(.green)
            }
            LabeledContent("Debug Mode Default") {
                Text("true").foregroundStyle(.green)
            }
            LabeledContent("Timeout Default") {
                Text("90s")
            }
            LabeledContent("Max Concurrency") {
                Text("\(AutomationSettings.defaultMaxConcurrency)")
            }
            LabeledContent("Password Chunk Size") {
                Text("3")
            }
        } header: {
            Label("DualFind Defaults", systemImage: "person.2.fill")
        }
    }

    // MARK: - URL Rotation

    private var urlRotationSection: some View {
        Section {
            LabeledContent("Mode") {
                Text(urlRotation.isIgnitionMode ? "Ignition" : "Joe Fortune")
                    .foregroundStyle(.orange)
            }

            LabeledContent("Use Mirrors") {
                Image(systemName: urlRotation.useMirrors ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(urlRotation.useMirrors ? .green : .red)
            }

            LabeledContent("Auto-Disable URLs (Direct DNS)") {
                Image(systemName: urlRotation.dontAutoDisableURLsForDirectDNS ? "xmark.circle" : "checkmark.circle.fill")
                    .foregroundStyle(urlRotation.dontAutoDisableURLsForDirectDNS ? .red : .green)
            }

            LabeledContent("Joe Default URL") {
                Text("joefortunepokies.win/login")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Ignition Default URL") {
                Text("ignitioncasino.ooo")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Joe Mirror Count") {
                Text("\(LoginURLRotationService.mirrorJoeURLStrings.count)")
            }

            LabeledContent("Ignition Mirror Count") {
                Text("\(LoginURLRotationService.mirrorIgnitionURLStrings.count)")
            }

            LabeledContent("Ping Timeout") {
                Text("8s")
            }

            LabeledContent("Speed Scoring") {
                Text("<3s=1.0, <6s=0.7, <10s=0.4, else=0.1")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Score Weighting") {
                Text("Success 60% / Speed 40%")
                    .font(.caption2)
            }
        } header: {
            Label("URL Rotation Config", systemImage: "link.circle.fill")
        } footer: {
            Text("URL rotation, mirror pools, health scoring and ping configuration.")
        }
    }

    // MARK: - Screenshot

    private var screenshotSection: some View {
        Section {
            LabeledContent("Target Resolution") {
                Text("1320 × 2868")
            }
            LabeledContent("JPEG Quality") {
                Text("0.15")
            }
            LabeledContent("Manager Max Screenshots") {
                Text("\(AutomationSettings.defaultMaxScreenshotRetention)")
            }
            LabeledContent("Automation Max Retention") {
                Text("\(vm.automationSettings.maxScreenshotRetention)")
            }
            LabeledContent("Memory Pressure Trim") {
                Text("100")
            }
            LabeledContent("Screenshots Per Attempt") {
                Text(vm.automationSettings.screenshotsPerAttempt.rawValue)
            }
            LabeledContent("Unified Per Attempt") {
                Text(vm.automationSettings.unifiedScreenshotsPerAttempt.label)
            }
            LabeledContent("Post-Submit Timings") {
                Text(vm.automationSettings.postSubmitScreenshotTimings)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Disabled Override") {
                Image(systemName: vm.automationSettings.unifiedScreenshotDisabledOverride ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(vm.automationSettings.unifiedScreenshotDisabledOverride ? .green : .red)
            }
        } header: {
            Label("Screenshot System", systemImage: "camera.fill")
        }
    }

    // MARK: - Network & Proxy

    private var networkProxySection: some View {
        Section {
            Picker("Connection Mode", selection: Binding(
                get: { proxyService.unifiedConnectionMode },
                set: { proxyService.setUnifiedConnectionMode($0) }
            )) {
                ForEach(ConnectionMode.allCases, id: \.self) { mode in
                    Label(mode.label, systemImage: mode.icon).tag(mode)
                }
            }

            Picker("Network Region", selection: Binding(
                get: { proxyService.networkRegion },
                set: { proxyService.networkRegion = $0 }
            )) {
                ForEach(NetworkRegion.allCases, id: \.self) { region in
                    Label(region.label, systemImage: region.icon).tag(region)
                }
            }

            Picker("IP Routing Mode", selection: $deviceProxy.ipRoutingMode) {
                ForEach(IPRoutingMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            Picker("Rotation Interval", selection: $deviceProxy.rotationInterval) {
                ForEach(RotationInterval.allCases, id: \.self) { interval in
                    Text(interval.label).tag(interval)
                }
            }

            Toggle("Local Proxy Enabled", isOn: $deviceProxy.localProxyEnabled)
            Toggle("Rotate on Batch Start", isOn: $deviceProxy.rotateOnBatchStart)
            Toggle("Rotate on Fingerprint Detection", isOn: $deviceProxy.rotateOnFingerprintDetection)
            Toggle("Auto Failover", isOn: $deviceProxy.autoFailoverEnabled)

            HStack {
                Text("Health Check Interval")
                Spacer()
                Text("\(Int(deviceProxy.healthCheckInterval))s")
                    .foregroundStyle(.secondary)
                Stepper("", value: $deviceProxy.healthCheckInterval, in: 10...120, step: 5)
                    .labelsHidden()
            }

            HStack {
                Text("Max Failures Before Rotation")
                Spacer()
                Text("\(deviceProxy.maxFailuresBeforeRotation)")
                    .foregroundStyle(.secondary)
                Stepper("", value: $deviceProxy.maxFailuresBeforeRotation, in: 1...10)
                    .labelsHidden()
            }
        } header: {
            Label("Network & Proxy Settings", systemImage: "network")
        } footer: {
            Text("Device-wide proxy settings. Persist key: device_proxy_settings_v2")
        }
    }

    // MARK: - Proxy Health Monitor

    private var proxyHealthSection: some View {
        Section {
            HStack {
                Text("Check Interval")
                Spacer()
                Text("\(Int(proxyHealth.checkIntervalSeconds))s")
                    .foregroundStyle(.secondary)
                Stepper("", value: $proxyHealth.checkIntervalSeconds, in: 10...120, step: 5)
                    .labelsHidden()
            }

            HStack {
                Text("Max Consecutive Failures")
                Spacer()
                Text("\(proxyHealth.maxConsecutiveFailures)")
                    .foregroundStyle(.secondary)
                Stepper("", value: $proxyHealth.maxConsecutiveFailures, in: 1...10)
                    .labelsHidden()
            }

            HStack {
                Text("Health Check Timeout")
                Spacer()
                Text("\(Int(proxyHealth.healthCheckTimeoutSeconds))s")
                    .foregroundStyle(.secondary)
                Stepper("", value: $proxyHealth.healthCheckTimeoutSeconds, in: 5...60, step: 5)
                    .labelsHidden()
            }

            Toggle("Auto Failover", isOn: $proxyHealth.autoFailoverEnabled)

            LabeledContent("Monitoring Active") {
                Image(systemName: proxyHealth.isMonitoring ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(proxyHealth.isMonitoring ? .green : .red)
            }

            if let latency = proxyHealth.averageLatencyMs {
                LabeledContent("Avg Latency") {
                    Text("\(latency)ms")
                        .foregroundStyle(latency < 200 ? .green : latency < 500 ? .orange : .red)
                }
            }

            LabeledContent("Success Rate") {
                Text(String(format: "%.1f%%", proxyHealth.successRate * 100))
                    .foregroundStyle(proxyHealth.successRate > 0.8 ? .green : .orange)
            }
        } header: {
            Label("Proxy Health Monitor", systemImage: "heart.text.square.fill")
        } footer: {
            Text("Persist key: proxy_health_monitor_v1")
        }
    }

    // MARK: - VPN Tunnel

    private var vpnTunnelSection: some View {
        Section {
            LabeledContent("Auto Reconnect") {
                Text("true").foregroundStyle(.green)
            }
            LabeledContent("VPN Enabled Default") {
                Text("false").foregroundStyle(.red)
            }
            LabeledContent("Reconnect Delay") {
                Text("2s")
            }
            LabeledContent("Max Reconnect Attempts") {
                Text("3")
            }
            LabeledContent("Kill Switch Default") {
                Text("false").foregroundStyle(.red)
            }
            LabeledContent("On-Demand Default") {
                Text("false").foregroundStyle(.red)
            }
            LabeledContent("Include All Networks") {
                Text("true").foregroundStyle(.green)
            }
            LabeledContent("Exclude Local Networks") {
                Text("true").foregroundStyle(.green)
            }
            LabeledContent("WireGuard MTU Fallback") {
                Text("1420")
            }
            LabeledContent("Disconnect on Sleep") {
                Text("false").foregroundStyle(.red)
            }
        } header: {
            Label("VPN Tunnel Settings", systemImage: "lock.shield.fill")
        } footer: {
            Text("Persist key: vpn_tunnel_settings_v2. Simulator support: false.")
        }
    }

    // MARK: - DNS Pool

    private var dnsPoolSection: some View {
        Section {
            LabeledContent("Region Preference") {
                Text(dnsPool.regionPreference.rawValue)
                    .foregroundStyle(.cyan)
            }

            LabeledContent("Auto-Disable Enabled") {
                Image(systemName: dnsPool.autoDisableEnabled ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(dnsPool.autoDisableEnabled ? .green : .red)
            }

            LabeledContent("Auto-Disable Threshold") {
                Text("3 failures")
            }

            LabeledContent("Cache TTL") {
                Text("120s")
            }

            LabeledContent("Max Rotation Attempts") {
                Text("min(sorted, 6)")
                    .font(.caption2)
            }

            LabeledContent("Default Servers") {
                Text("8 (CF, Google, Quad9, Seby AU, NextDNS×2, Mullvad, CleanBrowsing)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Fallback Provider") {
                Text("Cloudflare DoH")
                    .foregroundStyle(.orange)
            }
        } header: {
            Label("DNS Pool Config", systemImage: "globe.badge.chevron.backward")
        } footer: {
            Text("Persist key: dns_pool_managed_v3. Protocols: DoH and DoT.")
        }
    }

    // MARK: - Hybrid Networking

    private var hybridNetworkingSection: some View {
        Section {
            LabeledContent("Circuit Breaker Threshold") {
                Text("5 failures")
            }
            LabeledContent("Circuit Breaker Cooldown") {
                Text("60s")
            }
            LabeledContent("Half-Open Max Probes") {
                Text("2")
            }
            LabeledContent("Rerank Threshold") {
                Text("3")
            }
            LabeledContent("Sticky Decay") {
                Text("600s")
            }
            LabeledContent("Health Decay Interval") {
                Text("300s")
            }
            LabeledContent("Health Decay Factor") {
                Text("0.92")
            }
            LabeledContent("Method Priority") {
                Text("WireProxy → NodeMaven → OpenVPN → SOCKS5 → HTTPS/DoH")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Fail-Closed Proxy") {
                Text("127.0.0.1:9")
                    .font(.caption2)
            }
        } header: {
            Label("Hybrid Networking", systemImage: "rectangle.3.group.fill")
        } footer: {
            Text("Persist key: hybrid_networking_health_v2")
        }
    }

    // MARK: - NodeMaven

    private var nodeMavenSection: some View {
        Section {
            LabeledContent("Gateway Host") {
                Text("gate.nodemaven.com")
                    .font(.caption2)
            }
            LabeledContent("SOCKS5 Port") {
                Text("1080")
            }
            LabeledContent("HTTP Port") {
                Text("8080")
            }

            HStack {
                Text("API Key")
                Spacer()
                SecureField("API Key", text: $nodeMaven.apiKey)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 200)
            }

            HStack {
                Text("Username")
                Spacer()
                TextField("Username", text: $nodeMaven.proxyUsername)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 200)
            }

            HStack {
                Text("Password")
                Spacer()
                SecureField("Password", text: $nodeMaven.proxyPassword)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 200)
            }

            Picker("Country", selection: $nodeMaven.country) {
                ForEach(NodeMavenCountry.allCases, id: \.self) { c in
                    Text(c.rawValue.uppercased()).tag(c)
                }
            }

            Picker("Proxy Type", selection: $nodeMaven.proxyType) {
                ForEach(NodeMavenProxyType.allCases, id: \.self) { t in
                    Text(t.label).tag(t)
                }
            }

            Picker("Filter", selection: $nodeMaven.filter) {
                ForEach(NodeMavenFilter.allCases, id: \.self) { f in
                    Text(f.rawValue.capitalized).tag(f)
                }
            }

            Picker("Session Mode", selection: $nodeMaven.sessionMode) {
                ForEach(NodeMavenSessionMode.allCases, id: \.self) { m in
                    Text(m.rawValue.capitalized).tag(m)
                }
            }

            LabeledContent("Enabled") {
                Image(systemName: nodeMaven.isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(nodeMaven.isEnabled ? .green : .red)
            }

            if let result = nodeMaven.lastTestResult {
                LabeledContent("Last Test") {
                    Text(result)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let ip = nodeMaven.lastTestIP {
                LabeledContent("Last Test IP") {
                    Text(ip)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("NodeMaven Proxy", systemImage: "cloud.fill")
        } footer: {
            Text("Persist key: nodemaven_config_v1. ⚠️ Hardcoded defaults exist for mobile/residential usernames and password.")
        }
    }

    // MARK: - NordVPN

    private var nordVPNSection: some View {
        Section {
            LabeledContent("Active Profile") {
                Text(nordService.activeKeyProfile.rawValue)
                    .foregroundStyle(nordService.activeKeyProfile == .nick ? .blue : .purple)
            }
            LabeledContent("Profile Selected") {
                Image(systemName: nordService.hasSelectedProfile ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(nordService.hasSelectedProfile ? .green : .red)
            }
            LabeledContent("Has Service Credentials") {
                Image(systemName: nordService.hasServiceCredentials ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(nordService.hasServiceCredentials ? .green : .red)
            }
            LabeledContent("Server Cache Max Age") {
                Text("3600s")
            }
            LabeledContent("Max Retry Attempts") {
                Text("3")
            }
            LabeledContent("Retry Base Delay") {
                Text("2s")
            }
            LabeledContent("Expected WireGuard Configs") {
                Text("24")
            }
            LabeledContent("Expected OpenVPN Configs") {
                Text("10")
            }
            LabeledContent("Token Min Length") {
                Text("32")
            }
            if let error = nordService.lastError {
                LabeledContent("Last Error") {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Label("NordVPN Config", systemImage: "shield.checkered")
        } footer: {
            Text("Keys stored per-profile: nordvpn_nick_private_key_v1, nordvpn_poli_private_key_v1.")
        }
    }

    // MARK: - AI / Grok

    private var aiGrokSection: some View {
        Section {
            LabeledContent("AI Configured") {
                Image(systemName: GrokAISetup.isConfigured ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(GrokAISetup.isConfigured ? .green : .red)
            }
            LabeledContent("Standard Model") {
                Text("grok-3-fast")
                    .font(.caption2)
            }
            LabeledContent("Mini Model") {
                Text("grok-3-mini-fast")
                    .font(.caption2)
            }
            LabeledContent("Vision Model") {
                Text("grok-2-vision-latest")
                    .font(.caption2)
            }
            LabeledContent("Base URL") {
                Text("api.x.ai")
                    .font(.caption2)
            }
            LabeledContent("Max Retries") {
                Text("3")
            }
            LabeledContent("Vision Max Bytes") {
                Text("4 MB")
            }
            LabeledContent("Default Temperature") {
                Text("0.3")
            }
            LabeledContent("Fast Temperature") {
                Text("0.1")
            }
            LabeledContent("HTTP Timeout") {
                Text("45s")
            }
            LabeledContent("Current Model") {
                Text(grokStats.currentModel)
                    .font(.caption2)
                    .foregroundStyle(.cyan)
            }
            LabeledContent("Total Calls") {
                Text("\(grokStats.totalCalls)")
            }
            LabeledContent("Success Rate") {
                Text(String(format: "%.1f%%", grokStats.successRate * 100))
                    .foregroundStyle(grokStats.successRate > 0.8 ? .green : .orange)
            }
            LabeledContent("Total Tokens Used") {
                Text("\(grokStats.totalTokensUsed)")
            }
            if let lastError = grokStats.lastError {
                LabeledContent("Last Error") {
                    Text(lastError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            LabeledContent("AI Telemetry") {
                Image(systemName: vm.automationSettings.aiTelemetryEnabled ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(vm.automationSettings.aiTelemetryEnabled ? .green : .red)
            }
        } header: {
            Label("AI / Grok Config", systemImage: "brain.head.profile.fill")
        }
    }

    // MARK: - Live WebView Debug

    private var liveWebViewSection: some View {
        Section {
            LabeledContent("Full Screen") {
                Image(systemName: liveDebug.isFullScreen ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(liveDebug.isFullScreen ? .green : .red)
            }
            LabeledContent("Auto Observe") {
                Image(systemName: liveDebug.autoObserve ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(liveDebug.autoObserve ? .green : .red)
            }
            LabeledContent("Interactive") {
                Image(systemName: liveDebug.isInteractive ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(liveDebug.isInteractive ? .green : .red)
            }
            LabeledContent("Show Console") {
                Image(systemName: liveDebug.showConsole ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(liveDebug.showConsole ? .green : .red)
            }
            LabeledContent("Screenshot Toast") {
                Image(systemName: liveDebug.screenshotToast ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(liveDebug.screenshotToast ? .green : .red)
            }
            LabeledContent("Console Entries Max") {
                Text("200")
            }
            LabeledContent("Toast Auto-Dismiss") {
                Text("2s")
            }
            LabeledContent("Current URL") {
                Text(liveDebug.currentURL.isEmpty ? "None" : liveDebug.currentURL)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            LabeledContent("Console Entries") {
                Text("\(liveDebug.consoleEntries.count)")
            }
        } header: {
            Label("Live WebView Debug", systemImage: "eye.fill")
        }
    }

    // MARK: - Blacklist

    private var blacklistSection: some View {
        Section {
            Toggle("Auto-Exclude Blacklisted", isOn: $blacklist.autoExcludeBlacklist)
            Toggle("Auto-Blacklist No Account", isOn: $blacklist.autoBlacklistNoAcc)

            LabeledContent("Blacklisted Emails") {
                Text("\(blacklist.blacklistedEmails.count)")
            }
        } header: {
            Label("Blacklist Settings", systemImage: "hand.raised.fill")
        } footer: {
            Text("Persist keys: blacklist_emails_v2, blacklist_settings_v1")
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

    private func devRow(icon: String, title: String, subtitle: String, color: Color, badge: String? = nil) -> some View {
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

// MARK: - Developer Automation Settings Detail View

struct DeveloperAutomationSettingsView: View {
    @Binding var settings: AutomationSettings

    var body: some View {
        List {
            pageLoadingSection
            fieldDetectionSection
            cookieConsentSection
            credentialEntrySection
            patternStrategySection
            fallbackChainSection
            submitBehaviorSection
            postSubmitEvaluationSection
            retryRequeueSection
            stealthSection
            screenshotDebugSection
            concurrencySection
            networkPerModeSection
            urlRotationSection
            blacklistAutoSection
            humanSimulationSection
            loginButtonSection
            timeDelaysSection
            mfaHandlingSection
            smsDetectionSection
            captchaHandlingSection
            sessionManagementSection
            webViewConfigSection
            blankPageRecoverySection
            errorClassificationSection
            formInteractionSection
            viewportSection
            v42SettlementSection
            aiTelemetrySection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Automation Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Page Loading

    private var pageLoadingSection: some View {
        Section {
            stepperRow("Page Load Timeout", value: $settings.pageLoadTimeout, range: 30...300, step: 10, unit: "s")
            stepperRow("Page Load Retries", intValue: $settings.pageLoadRetries, range: 1...10)
            stepperDouble("Retry Backoff Multiplier", value: $settings.retryBackoffMultiplier, range: 1.0...5.0, step: 0.5)
            stepperRow("Wait for JS Render", intValue: $settings.waitForJSRenderMs, range: 1000...15000, step: 500, unit: "ms")
            Toggle("Full Session Reset on Final Retry", isOn: $settings.fullSessionResetOnFinalRetry)
        } header: {
            Label("Page Loading", systemImage: "globe")
        } footer: {
            Text("Min enforced: \(Int(AutomationSettings.minimumTimeoutSeconds))s for pageLoadTimeout")
        }
    }

    // MARK: - Field Detection

    private var fieldDetectionSection: some View {
        Section {
            Toggle("Field Verification", isOn: $settings.fieldVerificationEnabled)
            stepperRow("Field Verification Timeout", value: $settings.fieldVerificationTimeout, range: 30...300, step: 10, unit: "s")
            Toggle("Auto Calibration", isOn: $settings.autoCalibrationEnabled)
            Toggle("Vision ML Calibration Fallback", isOn: $settings.visionMLCalibrationFallback)
            stepperDouble("Calibration Confidence", value: $settings.calibrationConfidenceThreshold, range: 0.1...1.0, step: 0.1)
        } header: {
            Label("Field Detection", systemImage: "text.cursor")
        }
    }

    // MARK: - Cookie / Consent

    private var cookieConsentSection: some View {
        Section {
            Toggle("Dismiss Cookie Notices", isOn: $settings.dismissCookieNotices)
            stepperRow("Cookie Dismiss Delay", intValue: $settings.cookieDismissDelayMs, range: 100...2000, step: 100, unit: "ms")
        } header: {
            Label("Cookie / Consent", systemImage: "shield.checkered")
        }
    }

    // MARK: - Credential Entry

    private var credentialEntrySection: some View {
        Section {
            stepperRow("Typing Speed Min", intValue: $settings.typingSpeedMinMs, range: 20...300, step: 10, unit: "ms")
            stepperRow("Typing Speed Max", intValue: $settings.typingSpeedMaxMs, range: 50...500, step: 10, unit: "ms")
            Toggle("Typing Jitter", isOn: $settings.typingJitterEnabled)
            Toggle("Occasional Backspace", isOn: $settings.occasionalBackspaceEnabled)
            stepperDouble("Backspace Probability", value: $settings.backspaceProbability, range: 0.0...0.2, step: 0.01)
            stepperRow("Field Focus Delay", intValue: $settings.fieldFocusDelayMs, range: 50...2000, step: 50, unit: "ms")
            stepperRow("Inter-Field Delay", intValue: $settings.interFieldDelayMs, range: 100...2000, step: 50, unit: "ms")
            stepperRow("Pre-Fill Pause Min", intValue: $settings.preFillPauseMinMs, range: 50...1000, step: 50, unit: "ms")
            stepperRow("Pre-Fill Pause Max", intValue: $settings.preFillPauseMaxMs, range: 100...2000, step: 50, unit: "ms")
        } header: {
            Label("Credential Entry", systemImage: "keyboard")
        }
    }

    // MARK: - Pattern Strategy

    private var patternStrategySection: some View {
        Section {
            stepperRow("Max Submit Cycles", intValue: $settings.maxSubmitCycles, range: 1...20)
            Toggle("Prefer Calibrated First", isOn: $settings.preferCalibratedPatternsFirst)
            Toggle("Pattern Learning", isOn: $settings.patternLearningEnabled)
            LabeledContent("Enabled Patterns") {
                Text("\(settings.enabledPatterns.count)")
            }
        } header: {
            Label("Pattern Strategy", systemImage: "list.bullet.rectangle")
        }
    }

    // MARK: - Fallback Chain

    private var fallbackChainSection: some View {
        Section {
            Toggle("Legacy Fill Fallback", isOn: $settings.fallbackToLegacyFill)
            Toggle("OCR Click Fallback", isOn: $settings.fallbackToOCRClick)
            Toggle("Vision ML Click Fallback", isOn: $settings.fallbackToVisionMLClick)
            Toggle("Coordinate Click Fallback", isOn: $settings.fallbackToCoordinateClick)
        } header: {
            Label("Fallback Chain", systemImage: "arrow.triangle.branch")
        }
    }

    // MARK: - Submit Behavior

    private var submitBehaviorSection: some View {
        Section {
            stepperRow("Submit Retry Count", intValue: $settings.submitRetryCount, range: 1...20)
            stepperDouble("Wait for Response", value: $settings.waitForResponseSeconds, range: 30...300, step: 10)
            Toggle("Rapid Poll", isOn: $settings.rapidPollEnabled)
            stepperRow("Rapid Poll Interval", intValue: $settings.rapidPollIntervalMs, range: 50...2000, step: 50, unit: "ms")
        } header: {
            Label("Submit Behavior", systemImage: "paperplane.fill")
        }
    }

    // MARK: - Post-Submit Evaluation

    private var postSubmitEvaluationSection: some View {
        Section {
            Toggle("Redirect Detection", isOn: $settings.redirectDetection)
            Toggle("Error Banner Detection", isOn: $settings.errorBannerDetection)
            Toggle("Content Change Detection", isOn: $settings.contentChangeDetection)
            Picker("Evaluation Strictness", selection: $settings.evaluationStrictness) {
                ForEach(AutomationSettings.EvaluationStrictness.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            Toggle("Capture Page Content", isOn: $settings.capturePageContent)
        } header: {
            Label("Post-Submit Evaluation", systemImage: "checkmark.rectangle")
        }
    }

    // MARK: - Retry / Requeue

    private var retryRequeueSection: some View {
        Section {
            Toggle("Requeue on Timeout", isOn: $settings.requeueOnTimeout)
            Toggle("Requeue on Connection Failure", isOn: $settings.requeueOnConnectionFailure)
            Toggle("Requeue on Unsure", isOn: $settings.requeueOnUnsure)
            Toggle("Requeue on Red Banner", isOn: $settings.requeueOnRedBanner)
            stepperRow("Max Requeue Count", intValue: $settings.maxRequeueCount, range: 0...10)
            stepperRow("Min Attempts Before NoAcc", intValue: $settings.minAttemptsBeforeNoAcc, range: 1...10)
            stepperRow("Cycle Pause Min", intValue: $settings.cyclePauseMinMs, range: 100...5000, step: 100, unit: "ms")
            stepperRow("Cycle Pause Max", intValue: $settings.cyclePauseMaxMs, range: 200...10000, step: 100, unit: "ms")
        } header: {
            Label("Retry / Requeue", systemImage: "arrow.counterclockwise")
        }
    }

    // MARK: - Stealth / Anti-Detection

    private var stealthSection: some View {
        Section {
            Toggle("Stealth JS Injection", isOn: $settings.stealthJSInjection)
            Toggle("Fingerprint Validation", isOn: $settings.fingerprintValidationEnabled)
            Toggle("Host Fingerprint Learning", isOn: $settings.hostFingerprintLearningEnabled)
            Toggle("Fingerprint Spoofing", isOn: $settings.fingerprintSpoofing)
            Toggle("User Agent Rotation", isOn: $settings.userAgentRotation)
            Toggle("Viewport Randomization", isOn: $settings.viewportRandomization)
            Toggle("WebGL Noise", isOn: $settings.webGLNoise)
            Toggle("Canvas Noise", isOn: $settings.canvasNoise)
            Toggle("Audio Context Noise", isOn: $settings.audioContextNoise)
            Toggle("Timezone Spoof", isOn: $settings.timezoneSpoof)
            Toggle("Language Spoof", isOn: $settings.languageSpoof)
        } header: {
            Label("Stealth / Anti-Detection", systemImage: "eye.slash.fill")
        }
    }

    // MARK: - Screenshot / Debug

    private var screenshotDebugSection: some View {
        Section {
            Toggle("Slow Debug Mode", isOn: $settings.slowDebugMode)
            Toggle("Screenshot on Every Eval", isOn: $settings.screenshotOnEveryEval)
            Toggle("Screenshot on Failure", isOn: $settings.screenshotOnFailure)
            Toggle("Screenshot on Success", isOn: $settings.screenshotOnSuccess)
            stepperRow("Max Screenshot Retention", intValue: $settings.maxScreenshotRetention, range: 50...2000, step: 50)
            Picker("Per Attempt", selection: $settings.screenshotsPerAttempt) {
                ForEach(AutomationSettings.ScreenshotsPerAttempt.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            Picker("Unified Per Attempt", selection: $settings.unifiedScreenshotsPerAttempt) {
                ForEach(AutomationSettings.UnifiedScreenshotCount.allCases, id: \.self) { s in
                    Text(s.label).tag(s)
                }
            }
            stepperRow("Post-Click Delay", intValue: $settings.unifiedScreenshotPostClickDelayMs, range: 500...5000, step: 250, unit: "ms")
            Toggle("Disabled Override", isOn: $settings.unifiedScreenshotDisabledOverride)
            Toggle("Post-Submit Only", isOn: $settings.postSubmitScreenshotsOnly)
        } header: {
            Label("Screenshot / Debug", systemImage: "camera.viewfinder")
        }
    }

    // MARK: - Concurrency

    private var concurrencySection: some View {
        Section {
            stepperRow("Max Concurrency", intValue: $settings.maxConcurrency, range: 1...20)
            Picker("Concurrency Strategy", selection: $settings.concurrencyStrategy) {
                ForEach(ConcurrencyStrategy.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            stepperRow("Fixed Pair Count", intValue: $settings.fixedPairCount, range: 1...10)
            stepperRow("Live User Pair Count", intValue: $settings.liveUserPairCount, range: 1...10)
            stepperRow("Batch Delay Between Starts", intValue: $settings.batchDelayBetweenStartsMs, range: 0...5000, step: 250, unit: "ms")
            Toggle("Connection Test Before Batch", isOn: $settings.connectionTestBeforeBatch)
        } header: {
            Label("Concurrency", systemImage: "square.stack.3d.up.fill")
        }
    }

    // MARK: - Network Per Mode

    private var networkPerModeSection: some View {
        Section {
            Toggle("Use Assigned Network", isOn: $settings.useAssignedNetworkForTests)
            Toggle("Proxy Rotate on Disabled", isOn: $settings.proxyRotateOnDisabled)
            Toggle("Proxy Rotate on Failure", isOn: $settings.proxyRotateOnFailure)
            Toggle("DNS Rotate Per Request", isOn: $settings.dnsRotatePerRequest)
            Toggle("VPN Config Rotation", isOn: $settings.vpnConfigRotation)
        } header: {
            Label("Network Per Mode", systemImage: "antenna.radiowaves.left.and.right")
        }
    }

    // MARK: - URL Rotation

    private var urlRotationSection: some View {
        Section {
            Toggle("URL Rotation", isOn: $settings.urlRotationEnabled)
            stepperRow("Re-Enable URL After", intValue: $settings.reEnableURLAfterSeconds, range: 0...3600, step: 60, unit: "s")
            Toggle("Prefer Fastest URL", isOn: $settings.preferFastestURL)
            Toggle("Smart URL Selection", isOn: $settings.smartURLSelection)
        } header: {
            Label("URL Rotation", systemImage: "arrow.2.squarepath")
        }
    }

    // MARK: - Blacklist Auto

    private var blacklistAutoSection: some View {
        Section {
            Toggle("Auto-Blacklist No Account", isOn: $settings.autoBlacklistNoAcc)
            Toggle("Auto-Blacklist Perm Disabled", isOn: $settings.autoBlacklistPermDisabled)
            Toggle("Auto-Exclude Blacklisted", isOn: $settings.autoExcludeBlacklist)
        } header: {
            Label("Blacklist Automation", systemImage: "hand.raised.fill")
        }
    }

    // MARK: - Human Simulation

    private var humanSimulationSection: some View {
        Section {
            Toggle("Human Mouse Movement", isOn: $settings.humanMouseMovement)
            Toggle("Human Scroll Jitter", isOn: $settings.humanScrollJitter)
            Toggle("Random Pre-Action Pause", isOn: $settings.randomPreActionPause)
            stepperRow("Pre-Action Pause Min", intValue: $settings.preActionPauseMinMs, range: 20...1000, step: 10, unit: "ms")
            stepperRow("Pre-Action Pause Max", intValue: $settings.preActionPauseMaxMs, range: 50...2000, step: 10, unit: "ms")
            Toggle("Gaussian Timing Distribution", isOn: $settings.gaussianTimingDistribution)
        } header: {
            Label("Human Simulation", systemImage: "figure.walk")
        }
    }

    // MARK: - Login Button

    private var loginButtonSection: some View {
        Section {
            Picker("Detection Mode", selection: $settings.loginButtonDetectionMode) {
                ForEach(AutomationSettings.ButtonDetectionMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            Picker("Click Method", selection: $settings.loginButtonClickMethod) {
                ForEach(AutomationSettings.ButtonClickMethod.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            stepperRow("Pre-Click Delay", intValue: $settings.loginButtonPreClickDelayMs, range: 0...2000, step: 50, unit: "ms")
            stepperRow("Post-Click Delay", intValue: $settings.loginButtonPostClickDelayMs, range: 0...2000, step: 50, unit: "ms")
            Toggle("Double Click Guard", isOn: $settings.loginButtonDoubleClickGuard)
            stepperRow("Double Click Window", intValue: $settings.loginButtonDoubleClickWindowMs, range: 500...5000, step: 250, unit: "ms")
            Toggle("Scroll Into View", isOn: $settings.loginButtonScrollIntoView)
            Toggle("Wait for Enabled", isOn: $settings.loginButtonWaitForEnabled)
            stepperRow("Wait for Enabled Timeout", intValue: $settings.loginButtonWaitForEnabledTimeoutMs, range: 5000...180000, step: 5000, unit: "ms")
            stepperRow("Page Load Extra Delay", intValue: $settings.pageLoadExtraDelayMs, range: 0...10000, step: 500, unit: "ms")
            stepperRow("Submit Wait Delay", intValue: $settings.submitButtonWaitDelayMs, range: 0...10000, step: 500, unit: "ms")
            Toggle("Visibility Check", isOn: $settings.loginButtonVisibilityCheck)
            Toggle("Focus Before Click", isOn: $settings.loginButtonFocusBeforeClick)
            Toggle("Hover Before Click", isOn: $settings.loginButtonHoverBeforeClick)
            stepperRow("Hover Duration", intValue: $settings.loginButtonHoverDurationMs, range: 50...2000, step: 50, unit: "ms")
            Toggle("Click Offset Jitter", isOn: $settings.loginButtonClickOffsetJitter)
            stepperRow("Click Offset Max", intValue: $settings.loginButtonClickOffsetMaxPx, range: 1...20, unit: "px")
            stepperRow("Min Size", intValue: $settings.loginButtonMinSizePx, range: 5...100, unit: "px")
            stepperRow("Max Candidates", intValue: $settings.loginButtonMaxCandidates, range: 1...20)
            stepperDouble("Confidence Threshold", value: $settings.loginButtonConfidenceThreshold, range: 0.1...1.0, step: 0.1)
        } header: {
            Label("Login Button Behavior", systemImage: "hand.tap.fill")
        }
    }

    // MARK: - Time Delays

    private var timeDelaysSection: some View {
        Section {
            Group {
                stepperRow("Global Pre-Action", intValue: $settings.globalPreActionDelayMs, range: 0...5000, step: 100, unit: "ms")
                stepperRow("Global Post-Action", intValue: $settings.globalPostActionDelayMs, range: 0...5000, step: 100, unit: "ms")
                stepperRow("Pre-Navigation", intValue: $settings.preNavigationDelayMs, range: 0...5000, step: 100, unit: "ms")
                stepperRow("Post-Navigation", intValue: $settings.postNavigationDelayMs, range: 0...5000, step: 100, unit: "ms")
                stepperRow("Pre-Typing", intValue: $settings.preTypingDelayMs, range: 0...5000, step: 50, unit: "ms")
                stepperRow("Post-Typing", intValue: $settings.postTypingDelayMs, range: 0...5000, step: 50, unit: "ms")
                stepperRow("Pre-Submit", intValue: $settings.preSubmitDelayMs, range: 0...5000, step: 50, unit: "ms")
                stepperRow("Post-Submit", intValue: $settings.postSubmitDelayMs, range: 0...5000, step: 100, unit: "ms")
                stepperRow("Between Attempts", intValue: $settings.betweenAttemptsDelayMs, range: 0...10000, step: 100, unit: "ms")
                stepperRow("Between Credentials", intValue: $settings.betweenCredentialsDelayMs, range: 0...10000, step: 100, unit: "ms")
            }
            Group {
                stepperRow("Page Stabilization", intValue: $settings.pageStabilizationDelayMs, range: 0...5000, step: 100, unit: "ms")
                stepperRow("AJAX Settle", intValue: $settings.ajaxSettleDelayMs, range: 0...5000, step: 100, unit: "ms")
                stepperRow("DOM Mutation Settle", intValue: $settings.domMutationSettleMs, range: 0...5000, step: 100, unit: "ms")
                stepperRow("Animation Settle", intValue: $settings.animationSettleDelayMs, range: 0...5000, step: 100, unit: "ms")
                stepperRow("Redirect Follow", intValue: $settings.redirectFollowDelayMs, range: 0...5000, step: 100, unit: "ms")
                stepperRow("CAPTCHA Detection", intValue: $settings.captchaDetectionDelayMs, range: 0...5000, step: 100, unit: "ms")
                stepperRow("Error Recovery", intValue: $settings.errorRecoveryDelayMs, range: 0...5000, step: 100, unit: "ms")
                stepperRow("Session Cooldown", intValue: $settings.sessionCooldownDelayMs, range: 0...5000, step: 100, unit: "ms")
                stepperRow("Proxy Rotation", intValue: $settings.proxyRotationDelayMs, range: 0...5000, step: 100, unit: "ms")
                stepperRow("VPN Reconnect", intValue: $settings.vpnReconnectDelayMs, range: 0...10000, step: 100, unit: "ms")
            }
            Group {
                Toggle("Auto Fallback WG→OVPN", isOn: $settings.autoFallbackWGtoOVPN)
                Toggle("Auto Fallback OVPN→SOCKS5", isOn: $settings.autoFallbackOVPNtoSOCKS5)
                Toggle("Delay Randomization", isOn: $settings.delayRandomizationEnabled)
                stepperRow("Randomization %", intValue: $settings.delayRandomizationPercent, range: 0...100, step: 5, unit: "%")
                stepperRow("Misc Delay", intValue: $settings.miscellaneousDelayMs, range: 0...5000, step: 100, unit: "ms")
                Toggle("Misc Delay Enabled", isOn: $settings.miscellaneousDelayEnabled)
            }
        } header: {
            Label("Time Delays", systemImage: "timer")
        }
    }

    // MARK: - MFA Handling

    private var mfaHandlingSection: some View {
        Section {
            Toggle("MFA Detection", isOn: $settings.mfaDetectionEnabled)
            stepperRow("MFA Wait Timeout", intValue: $settings.mfaWaitTimeoutSeconds, range: 30...300, step: 10, unit: "s")
            Toggle("MFA Auto Skip", isOn: $settings.mfaAutoSkip)
            Toggle("MFA Mark as Temp Disabled", isOn: $settings.mfaMarkAsTempDisabled)
        } header: {
            Label("MFA Handling", systemImage: "lock.rotation")
        }
    }

    // MARK: - SMS Detection

    private var smsDetectionSection: some View {
        Section {
            Toggle("SMS Detection", isOn: $settings.smsDetectionEnabled)
            Toggle("SMS Burn Session", isOn: $settings.smsBurnSession)
        } header: {
            Label("SMS Detection", systemImage: "message.fill")
        }
    }

    // MARK: - CAPTCHA Handling

    private var captchaHandlingSection: some View {
        Section {
            Toggle("CAPTCHA Detection", isOn: $settings.captchaDetectionEnabled)
            Toggle("CAPTCHA Auto Skip", isOn: $settings.captchaAutoSkip)
            Toggle("CAPTCHA Mark as Failed", isOn: $settings.captchaMarkAsFailed)
            stepperRow("CAPTCHA Wait Timeout", intValue: $settings.captchaWaitTimeoutSeconds, range: 30...300, step: 10, unit: "s")
            Toggle("CAPTCHA iFrame Detection", isOn: $settings.captchaIframeDetection)
            Toggle("CAPTCHA Image Detection", isOn: $settings.captchaImageDetection)
        } header: {
            Label("CAPTCHA Handling", systemImage: "checkmark.shield")
        }
    }

    // MARK: - Session Management

    private var sessionManagementSection: some View {
        Section {
            Picker("Session Isolation", selection: $settings.sessionIsolation) {
                ForEach(AutomationSettings.SessionIsolationMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            Toggle("Clear Cookies Between", isOn: $settings.clearCookiesBetweenAttempts)
            Toggle("Clear LocalStorage Between", isOn: $settings.clearLocalStorageBetweenAttempts)
            Toggle("Clear SessionStorage Between", isOn: $settings.clearSessionStorageBetweenAttempts)
            Toggle("Clear Cache Between", isOn: $settings.clearCacheBetweenAttempts)
            Toggle("Clear IndexedDB Between", isOn: $settings.clearIndexedDBBetweenAttempts)
            Toggle("Fresh WebView Per Attempt", isOn: $settings.freshWebViewPerAttempt)
        } header: {
            Label("Session Management", systemImage: "rectangle.stack.badge.minus")
        }
    }

    // MARK: - WebView Config

    private var webViewConfigSection: some View {
        Section {
            stepperRow("Memory Limit", intValue: $settings.webViewMemoryLimitMB, range: 512...8192, step: 256, unit: "MB")
            Toggle("JS Enabled", isOn: $settings.webViewJSEnabled)
            Toggle("Image Loading", isOn: $settings.webViewImageLoadingEnabled)
            Toggle("Plugins", isOn: $settings.webViewPluginsEnabled)
        } header: {
            Label("WebView Config", systemImage: "safari.fill")
        }
    }

    // MARK: - Blank Page Recovery

    private var blankPageRecoverySection: some View {
        Section {
            Toggle("Blank Page Recovery", isOn: $settings.blankPageRecoveryEnabled)
            stepperRow("Blank Page Timeout", intValue: $settings.blankPageTimeoutSeconds, range: 5...60, step: 5, unit: "s")
            stepperRow("Blank Page Wait Threshold", intValue: $settings.blankPageWaitThresholdSeconds, range: 30...180, step: 10, unit: "s")
            Toggle("Fallback 1: Wait & Recheck", isOn: $settings.blankPageFallback1_WaitAndRecheck)
            Toggle("Fallback 2: Change URL", isOn: $settings.blankPageFallback2_ChangeURL)
            Toggle("Fallback 3: Change DNS", isOn: $settings.blankPageFallback3_ChangeDNS)
            Toggle("Fallback 4: Change Fingerprint", isOn: $settings.blankPageFallback4_ChangeFingerprint)
            Toggle("Fallback 5: Full Session Reset", isOn: $settings.blankPageFallback5_FullSessionReset)
            stepperRow("Max Fallback Attempts", intValue: $settings.blankPageMaxFallbackAttempts, range: 1...10)
            stepperRow("Recheck Interval", intValue: $settings.blankPageRecheckIntervalMs, range: 1000...10000, step: 500, unit: "ms")
        } header: {
            Label("Blank Page Recovery", systemImage: "doc.questionmark")
        }
    }

    // MARK: - Error Classification

    private var errorClassificationSection: some View {
        Section {
            Toggle("Network Error Auto Retry", isOn: $settings.networkErrorAutoRetry)
            Toggle("SSL Error Auto Retry", isOn: $settings.sslErrorAutoRetry)
            Toggle("HTTP 403 Mark Blocked", isOn: $settings.http403MarkAsBlocked)
            stepperRow("HTTP 429 Retry After", intValue: $settings.http429RetryAfterSeconds, range: 30...300, step: 10, unit: "s")
            Toggle("HTTP 5xx Auto Retry", isOn: $settings.http5xxAutoRetry)
            Toggle("Connection Reset Auto Retry", isOn: $settings.connectionResetAutoRetry)
            Toggle("DNS Failure Auto Retry", isOn: $settings.dnsFailureAutoRetry)
            Toggle("Classify Unknown as Unsure", isOn: $settings.classifyUnknownAsUnsure)
        } header: {
            Label("Error Classification", systemImage: "exclamationmark.triangle")
        }
    }

    // MARK: - Form Interaction Advanced

    private var formInteractionSection: some View {
        Section {
            Toggle("Clear Fields Before Typing", isOn: $settings.clearFieldsBeforeTyping)
            Picker("Clear Field Method", selection: $settings.clearFieldMethod) {
                ForEach(AutomationSettings.FieldClearMethod.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            Toggle("Tab Between Fields", isOn: $settings.tabBetweenFields)
            Toggle("Click Field Before Typing", isOn: $settings.clickFieldBeforeTyping)
            Toggle("Verify After Typing", isOn: $settings.verifyFieldValueAfterTyping)
            Toggle("Retype on Verification Failure", isOn: $settings.retypeOnVerificationFailure)
            stepperRow("Max Retype Attempts", intValue: $settings.maxRetypeAttempts, range: 0...5)
            Toggle("Password Unmask Check", isOn: $settings.passwordFieldUnmaskCheck)
            Toggle("Auto Detect Remember Me", isOn: $settings.autoDetectRememberMe)
            Toggle("Uncheck Remember Me", isOn: $settings.uncheckRememberMe)
            Toggle("Dismiss Autofill Suggestions", isOn: $settings.dismissAutofillSuggestions)
            Toggle("Handle Password Managers", isOn: $settings.handlePasswordManagers)
        } header: {
            Label("Form Interaction", systemImage: "doc.text.fill")
        }
    }

    // MARK: - Viewport / Window

    private var viewportSection: some View {
        Section {
            stepperRow("Viewport Width", intValue: $settings.viewportWidth, range: 320...1920, step: 10, unit: "px")
            stepperRow("Viewport Height", intValue: $settings.viewportHeight, range: 568...2436, step: 10, unit: "px")
            Toggle("Smart Fingerprint Reuse", isOn: $settings.smartFingerprintReuse)
            Toggle("Randomize Viewport Size", isOn: $settings.randomizeViewportSize)
            stepperRow("Viewport Variance", intValue: $settings.viewportSizeVariancePx, range: 0...200, step: 10, unit: "px")
            Toggle("Mobile Viewport Emulation", isOn: $settings.mobileViewportEmulation)
            stepperRow("Mobile Width", intValue: $settings.mobileViewportWidth, range: 320...1920, step: 10, unit: "px")
            stepperRow("Mobile Height", intValue: $settings.mobileViewportHeight, range: 568...2436, step: 10, unit: "px")
            stepperDouble("Device Scale Factor", value: $settings.deviceScaleFactor, range: 1.0...4.0, step: 0.5)
        } header: {
            Label("Viewport / Window", systemImage: "rectangle.dashed")
        }
    }

    // MARK: - V4.2 Settlement Gate

    private var v42SettlementSection: some View {
        Section {
            Toggle("V4.2 Settlement Gate", isOn: $settings.v42SettlementGateEnabled)
            stepperRow("Max Timeout", intValue: $settings.v42SettlementMaxTimeoutMs, range: 5000...60000, step: 1000, unit: "ms")
            stepperRow("Button Stability", intValue: $settings.v42ButtonStabilityMs, range: 100...2000, step: 50, unit: "ms")
            stepperRow("Hover Dwell", intValue: $settings.v42HoverDwellMs, range: 100...2000, step: 50, unit: "ms")
            stepperRow("Click Jitter", intValue: $settings.v42ClickJitterPx, range: 0...20, unit: "px")
            stepperDouble("Inter-Attempt Min", value: $settings.v42InterAttemptDelayMinSec, range: 0.5...10, step: 0.5)
            stepperDouble("Inter-Attempt Max", value: $settings.v42InterAttemptDelayMaxSec, range: 1.0...20, step: 0.5)
            stepperRow("Human Variance Min", intValue: $settings.v42HumanVarianceMinMs, range: 100...2000, step: 50, unit: "ms")
            stepperRow("Human Variance Max", intValue: $settings.v42HumanVarianceMaxMs, range: 200...5000, step: 50, unit: "ms")
            Toggle("Strict Classification", isOn: $settings.v42StrictClassification)
            Toggle("Coordinate Interaction Only", isOn: $settings.v42CoordinateInteractionOnly)
            stepperDouble("Typo Chance", value: $settings.v42TypoChance, range: 0.0...0.1, step: 0.01)
        } header: {
            Label("V4.2 Settlement Gate", systemImage: "bolt.badge.clock")
        }
    }

    // MARK: - AI Telemetry

    private var aiTelemetrySection: some View {
        Section {
            Toggle("AI Telemetry", isOn: $settings.aiTelemetryEnabled)
            LabeledContent("URL Flow Assignments") {
                Text("\(settings.urlFlowAssignments.count)")
            }
        } header: {
            Label("AI Telemetry & Flow Overrides", systemImage: "brain")
        }
    }

    // MARK: - Helper Views

    private func stepperRow(_ label: String, value: Binding<TimeInterval>, range: ClosedRange<Int>, step: Int = 1, unit: String = "") -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text("\(Int(value.wrappedValue))\(unit)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Stepper("", value: Binding(
                get: { Int(value.wrappedValue) },
                set: { value.wrappedValue = TimeInterval($0) }
            ), in: range, step: step)
            .labelsHidden()
        }
    }

    private func stepperRow(_ label: String, intValue: Binding<Int>, range: ClosedRange<Int>, step: Int = 1, unit: String = "") -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text("\(intValue.wrappedValue)\(unit)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Stepper("", value: intValue, in: range, step: step)
                .labelsHidden()
        }
    }

    private func stepperDouble(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
        }
    }
}
