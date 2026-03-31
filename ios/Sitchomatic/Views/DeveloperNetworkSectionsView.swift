import SwiftUI

struct DeveloperNetworkSectionsView: View {
    @Bindable var vm: PPSRAutomationViewModel
    @Bindable var proxyHealth: ProxyHealthMonitor
    @Bindable var deviceProxy: DeviceProxyService
    @Bindable var nordService: NordVPNService
    @Bindable var nodeMaven: NodeMavenService
    let proxyService: ProxyRotationService
    let dnsPool: DNSPoolService
    let urlRotation: LoginURLRotationService

    var body: some View {
        Group {
            urlRotationSection
            networkProxySection
            proxyHealthSection
            vpnTunnelSection
            dnsPoolSection
            hybridNetworkingSection
            nodeMavenSection
            nordVPNSection
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
            Text("Persist key: nodemaven_config_v1. ⚠️ Hardcoded defaults exist for mobile/residential usernames and passwords.")
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
}
