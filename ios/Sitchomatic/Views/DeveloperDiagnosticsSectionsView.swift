import SwiftUI

struct DeveloperDiagnosticsSectionsView: View {
    @Bindable var vm: PPSRAutomationViewModel
    @Bindable var blacklist: BlacklistService
    @Bindable var liveDebug: LiveWebViewDebugService
    let grokStats: GrokUsageStats

    var body: some View {
        Group {
            screenshotSection
            aiGrokSection
            liveWebViewSection
            blacklistSection
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
        } header: {
            Label("Screenshot System", systemImage: "camera.fill")
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
}
