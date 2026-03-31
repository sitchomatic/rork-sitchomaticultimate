import SwiftUI

struct DeveloperSettingsView: View {
    @State private var vm = PPSRAutomationViewModel.shared
    @State private var unifiedVM = UnifiedSessionViewModel.shared
    @State private var dualFindVM = DualFindViewModel.shared
    @State private var proxyHealth = ProxyHealthMonitor.shared
    @State private var deviceProxy = DeviceProxyService.shared
    @State private var nordService = NordVPNService.shared
    @State private var nodeMaven = NodeMavenService.shared
    @State private var blacklist = BlacklistService.shared
    @State private var liveDebug = LiveWebViewDebugService.shared
    @State private var showSyncToast: Bool = false
    private let proxyService = ProxyRotationService.shared
    private let dnsPool = DNSPoolService.shared
    private let urlRotation = LoginURLRotationService.shared
    private let grokStats = GrokUsageStats.shared

    var body: some View {
        List {
            DeveloperAutomationSectionsView(
                vm: vm,
                unifiedVM: unifiedVM,
                dualFindVM: dualFindVM,
                showSyncToast: $showSyncToast
            )

            DeveloperNetworkSectionsView(
                vm: vm,
                proxyHealth: proxyHealth,
                deviceProxy: deviceProxy,
                nordService: nordService,
                nodeMaven: nodeMaven,
                proxyService: proxyService,
                dnsPool: dnsPool,
                urlRotation: urlRotation
            )

            DeveloperDiagnosticsSectionsView(
                vm: vm,
                blacklist: blacklist,
                liveDebug: liveDebug,
                grokStats: grokStats
            )

            DeveloperReferenceSectionsView(
                vm: vm,
                proxyService: proxyService,
                nordService: nordService
            )
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Developer Settings")
        .overlay(alignment: .bottom) {
            if showSyncToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("All modes synced")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.green.gradient, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 20)
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
            stepperRow("Page Load Timeout", value: $settings.pageLoadTimeout, range: Int(AutomationSettings.minimumTimeoutSeconds)...300, step: 10, unit: "s")
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
            stepperRow("Field Verification Timeout", value: $settings.fieldVerificationTimeout, range: Int(AutomationSettings.minimumTimeoutSeconds)...300, step: 10, unit: "s")
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

    // MARK: - Submit Behavior

    private var submitBehaviorSection: some View {
        Section {
            stepperRow("Submit Retry Count", intValue: $settings.submitRetryCount, range: 1...20)
            stepperDouble("Wait for Response", value: $settings.waitForResponseSeconds, range: AutomationSettings.minimumTimeoutSeconds...300, step: 10)
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
            stepperRow("Re-Enable URL After", value: $settings.reEnableURLAfterSeconds, range: 0...3600, step: 60, unit: "s")
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
            stepperRow("Wait for Enabled Timeout", intValue: $settings.loginButtonWaitForEnabledTimeoutMs, range: AutomationSettings.minimumTimeoutMilliseconds...180000, step: 5000, unit: "ms")
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
            stepperRow("MFA Wait Timeout", intValue: $settings.mfaWaitTimeoutSeconds, range: Int(AutomationSettings.minimumTimeoutSeconds)...300, step: 10, unit: "s")
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
            stepperRow("CAPTCHA Wait Timeout", intValue: $settings.captchaWaitTimeoutSeconds, range: Int(AutomationSettings.minimumTimeoutSeconds)...300, step: 10, unit: "s")
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
            stepperRow("HTTP 429 Retry After", intValue: $settings.http429RetryAfterSeconds, range: Int(AutomationSettings.minimumTimeoutSeconds)...300, step: 10, unit: "s")
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
