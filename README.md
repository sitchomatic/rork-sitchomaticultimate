# Sitchomatic

**Sitchomatic** is a sophisticated iOS automation platform for credential testing and payment-card validation. It orchestrates concurrent browser sessions via embedded WebViews, applies AI-powered analysis, and routes traffic through layered VPN/proxy networks — all while maintaining comprehensive evidence bundles for every test run.

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Technology Stack](#technology-stack)
- [Key Modules](#key-modules)
  - [Login Automation](#login-automation)
  - [PPSR Card Validation](#ppsr-card-validation)
  - [Dual-Site Unified Testing](#dual-site-unified-testing)
  - [VPN & Proxy Management](#vpn--proxy-management)
  - [AI Services](#ai-services)
  - [Screenshot & Evidence System](#screenshot--evidence-system)
  - [Widget & Live Activity](#widget--live-activity)
- [Networking Modes](#networking-modes)
- [Anti-Detection & Stealth](#anti-detection--stealth)
- [Getting Started](#getting-started)
- [Codebase Stats](#codebase-stats)
- [License](#license)

---

## Features

| Area | Highlights |
|------|-----------|
| **Login Testing** | Concurrent credential testing across multiple sites with adaptive retry, circuit-breaker protection, and confidence scoring |
| **PPSR Validation** | Automated 8-stage payment-card checking on the Australian PPSR portal with email rotation and charge-tier control |
| **Dual-Site Testing** | Parallel credential validation across two sites simultaneously with coordinated OCR-based response analysis |
| **Network Evasion** | WireGuard (NordLynx), OpenVPN, SOCKS5 proxy, DNS-over-HTTPS, and device-wide proxy routing |
| **AI / ML** | 19 AI-powered services for session health prediction, anti-detection adaptation, challenge solving, and credential prioritisation |
| **Evidence Bundles** | Exportable JSON forensic records with screenshots, replay logs, confidence signals, and AI reasoning |
| **Batch Processing** | Queue-based batch execution with adaptive concurrency, live progress, and auto-requeue on transient failures |
| **Screenshot Pipeline** | Unified capture → compress → dedup → cache pipeline with Vision OCR text extraction |
| **Crash Resilience** | SafeBoot detection, session recovery snapshots, WebView crash recovery, and memory-pressure monitoring |
| **Live Activity** | Command-center Live Activity widget for real-time run status on the Lock Screen |

---

## Architecture

Sitchomatic follows a **MVVM + Service Layer** architecture with **Swift Concurrency** (async/await, actors):

```
┌─────────────────────────────────────────────────────┐
│                    SwiftUI Views                    │
│  (94 view files — dashboards, feeds, settings)      │
├─────────────────────────────────────────────────────┤
│                   ViewModels (16)                    │
│  @Observable @MainActor singletons                  │
│  LoginViewModel · UnifiedSessionViewModel · …       │
├─────────────────────────────────────────────────────┤
│               Services & Engines (169)              │
│  Automation · Networking · AI · Persistence · …     │
├─────────────────────────────────────────────────────┤
│                    Models (46)                       │
│  LoginCredential · PPSRCard · DualSiteSession · …   │
├─────────────────────────────────────────────────────┤
│                  Utilities (14)                      │
│  Date formatters · Style extensions · Task helpers   │
└─────────────────────────────────────────────────────┘
```

### Key Patterns

- **Actor-based concurrency** — `AutomationActor`, `EarlyStopActor`, `SitchomaticApexActor`, `IdentityActor` isolate mutable state
- **Circuit Breaker** — `HostCircuitBreakerService` protects target hosts from excessive requests
- **Adaptive Retry** — `AdaptiveRetryService` applies intelligent back-off strategies per credential
- **Session Recovery** — `SessionRecoveryService` persists snapshots to resume after crashes
- **HyperFlow** — Custom WebView anchoring system that prevents iOS Jetsam termination of background sessions

---

## Project Structure

```
ios/
├── Sitchomatic/
│   ├── SitchomaticApp.swift          # @main entry point, SafeBoot, state restoration
│   ├── ContentView.swift             # Tab-based navigation (Dashboard, Cards, Sessions, Settings)
│   ├── ProductMode.swift             # Product mode enum (PPSR CarCheck)
│   ├── Assets.xcassets/              # App icon, accent colour, background images
│   ├── Models/                       # 46 domain models
│   │   ├── LoginCredential.swift     #   Credential with status tracking & history
│   │   ├── PPSRCard.swift            #   Payment card with brand detection & BIN lookup
│   │   ├── DualSiteSession.swift     #   Paired session with classification
│   │   ├── AutomationSettings.swift  #   Automation configuration (Codable)
│   │   ├── AutomationTemplate.swift  #   6 built-in automation presets
│   │   ├── EvidenceBundle.swift      #   Forensic test record with AI signals
│   │   └── …
│   ├── ViewModels/                   # 16 @Observable view models
│   │   ├── LoginViewModel.swift      #   Login credential management
│   │   ├── UnifiedSessionViewModel.swift  # Dual-site session orchestration
│   │   ├── PPSRAutomationViewModel.swift  # PPSR batch management
│   │   └── …
│   ├── Views/                        # 94 SwiftUI views
│   │   ├── LoginDashboardView.swift  #   Login testing dashboard
│   │   ├── DualFindContainerView.swift  # Dual-site testing UI
│   │   ├── UnifiedScreenshotFeedView.swift  # Screenshot gallery
│   │   ├── EvidenceBundleListView.swift     # Evidence browser
│   │   └── …
│   ├── Services/                     # 169 service files
│   │   ├── LoginAutomationEngine.swift     # 6-phase login automation
│   │   ├── PPSRAutomationEngine.swift      # 8-stage card validation
│   │   ├── DualSiteWorkerService.swift     # Parallel dual-site testing
│   │   ├── NordVPNService.swift            # NordVPN integration
│   │   ├── ProxyRotationManager.swift      # Proxy rotation & health
│   │   ├── AI*.swift (×19)                 # AI/ML services
│   │   ├── WireProxy/                      # Custom WireGuard proxy stack
│   │   │   ├── Crypto/                     #   Blake2s, WireGuard crypto
│   │   │   ├── Handshake/                  #   Noise protocol handshake
│   │   │   ├── TCPStack/                   #   IP/TCP packet handling, DNS
│   │   │   └── Transport/                  #   WireGuard transport layer
│   │   └── Patterns/
│   │       └── HumanTypingEngine.swift     # Realistic keystroke simulation
│   └── Utilities/                    # 14 utility files
│       ├── SharedStyleExtensions.swift     # Colour extensions for status enums
│       ├── BlankScreenshotDetector.swift   # Detects blank captures
│       └── …
├── SitchomaticTests/                 # Unit tests
├── SitchomaticUITests/               # UI tests
├── SitchomaticWidget/                # Widget & Live Activity
│   ├── SitchomaticWidget.swift       #   Home-screen widget
│   ├── CommandCenterLiveActivity.swift  # Lock-screen Live Activity
│   └── SitchomaticWidgetBundle.swift    # Widget bundle entry point
└── Sitchomatic.xcodeproj/            # Xcode project
```

---

## Technology Stack

| Layer | Technologies |
|-------|-------------|
| **UI** | SwiftUI, UIKit (WebView hosting), Observation framework |
| **Concurrency** | Swift Concurrency (async/await), Actors, Structured Tasks |
| **Networking** | URLSession, Network framework, WebKit (WKWebView) |
| **VPN / Proxy** | WireGuard (custom userspace stack), OpenVPN, SOCKS5, DNS-over-HTTPS |
| **Cryptography** | CryptoKit, custom Blake2s, Noise protocol handshake |
| **AI / Vision** | Vision framework (OCR), FoundationModels, custom ML classifiers |
| **Persistence** | FileManager (document vault), UserDefaults, Keychain (Security) |
| **Widgets** | WidgetKit, ActivityKit (Live Activities) |
| **Notifications** | UserNotifications |
| **File Parsing** | CoreXLSX (Excel import for card data) |
| **Shortcuts** | AppIntents (Siri Shortcuts) |

---

## Key Modules

### Login Automation

The **Login Automation Engine** drives concurrent credential testing across configurable target sites.

**Flow** (6 phases):
1. **Pre-flight** — Network check, proxy assignment, stealth activation
2. **Navigation** — Load login URL via embedded WKWebView
3. **Interaction** — Locate form fields, fill credentials with human-like typing
4. **Submission** — Submit form, handle challenge pages
5. **Analysis** — OCR/Vision text extraction, AI confidence scoring
6. **Classification** — Mark credential as Working / NoAcc / PermDisabled / TempDisabled / Unsure

**Capabilities:**
- Up to 8 concurrent WebView sessions
- Adaptive URL rotation (`LoginURLRotationService`)
- JavaScript injection (`LoginJSBuilder`)
- Challenge-page classification and AI solving
- Smart button recovery with coordinate/Vision/OCR fallback chain
- WebView crash recovery and lifetime budgeting
- Detailed per-attempt evidence bundles

### PPSR Card Validation

Automates payment-card validation on the Australian **PPSR (Personal Property Securities Register)** portal.

**Flow** (8 stages):
1. Queued → 2. Filling VIN → 3. Submitting Search → 4. Processing Results → 5. Entering Payment → 6. Processing Payment → 7. Confirming Report → 8. Completed / Failed

**Capabilities:**
- Smart card parsing from multiple formats (pipe-delimited, CSV, rich-text)
- Brand detection (Visa, Mastercard, Amex, JCB, Discover, Diners, UnionPay)
- BIN lookup for issuer/country data
- Email rotation for form submissions
- Charge-amount tier selection (low / medium / high)
- Gateway selection with fallback

### Dual-Site Unified Testing

Simultaneously tests a single credential against two sites in parallel (V4.2):

- **Site A** — Joe Fortune
- **Site B** — Ignition Casino

Each session runs parallel WebViews with coordinated interaction, OCR-based response validation, and a joint verdict. Sessions are classified as `ValidAccount`, `PermanentBan`, `TemporaryLock`, or `NoAccount`.

### VPN & Proxy Management

A layered network stack routes test traffic through multiple anonymisation layers:

| Protocol | Implementation |
|----------|---------------|
| **WireGuard** | Custom userspace stack in `WireProxy/` — Noise handshake, Blake2s, TCP/IP packet handling |
| **NordLynx** | NordVPN WireGuard integration with server pool management and country selection |
| **OpenVPN** | TCP/UDP tunnels via `OpenVPNTunnelConnection` + SOCKS5 bridge |
| **SOCKS5** | Local proxy server (`SOCKS5ProxyManager`) for per-session routing |
| **DNS-over-HTTPS** | Custom DoH resolver for DNS leak prevention |

Additional features:
- Automatic proxy rotation with health monitoring (`ProxyHealthMonitor`)
- Proxy quality decay scoring (`ProxyQualityDecayService`)
- Circuit-breaker protection per host
- Per-session tunnel assignment

### AI Services

19 AI-powered services provide intelligent automation:

| Service | Purpose |
|---------|---------|
| `AISessionHealthMonitorService` | Predicts session failure risk in real time |
| `AIAntiDetectionAdaptiveService` | Dynamically adjusts behaviour to evade detection |
| `AIChallengePageSolverService` | Solves CAPTCHAs and challenge pages |
| `AIFingerprintTuningService` | Optimises browser fingerprint parameters |
| `AICredentialPriorityScoringService` | Ranks credentials by success likelihood |
| `AIConfidenceAnalyzerService` | Computes multi-signal confidence scores |
| `AIProxyStrategyService` | Selects optimal proxy rotation strategy |
| `AITimingOptimizerService` | Calculates human-like action delays |
| `AIReinforcementInteractionGraph` | Learns interaction patterns over time |
| `AIPredictiveConcurrencyGovernor` | Adjusts concurrency limits dynamically |
| `AILoginURLOptimizerService` | Identifies highest-success login URLs |
| `AIBatchInsightTuningTool` | Applies batch-level optimisation |
| `AIPredictiveBatchPreOptimizer` | Pre-optimises before batch execution |
| `AICredentialTriageService` | Initial credential sorting/prioritisation |
| `AICheckpointVerificationTool` | Verifies automation checkpoint success |
| `AIRunHealthAnalyzerTool` | Analyses overall batch health |
| `AICustomToolsCoordinator` | Orchestrates custom AI tool pipelines |
| `OnDeviceAIService` | On-device inference via FoundationModels |
| `GrokAISetup` | AI system bootstrap and configuration |

### Screenshot & Evidence System

**Screenshot Pipeline:**
```
Capture (WKWebView) → Scale & Compress (JPEG 0.15) → Dedup → Cache (10 mem / 200 disk) → OCR
```

- `ScreenshotCaptureService` — Captures at 1320×2868 (iPhone Pro Max resolution)
- `ScreenshotDedupService` — Eliminates duplicate screenshots
- `ScreenshotCache` — Two-tier memory + disk cache
- `UnifiedScreenshotManager` — Central storage and retrieval
- `VisionTextCropService` — OCR text extraction via Vision framework
- `BlankScreenshotDetector` — Detects and filters blank captures

**Evidence Bundles** (`EvidenceBundle`) contain:
- Credential details and test result
- Confidence score with signal breakdown
- AI reasoning explanation
- Network context (VPN server, IP, country)
- Screenshot references
- Structured session replay logs
- Exportable as JSON

### Widget & Live Activity

| Component | Description |
|-----------|-------------|
| `SitchomaticWidget` | Home-screen widget displaying current time / status |
| `CommandCenterLiveActivity` | Lock-screen Live Activity showing real-time batch progress |
| `SitchomaticWidgetBundle` | Widget + Live Activity bundle |

---

## Networking Modes

The app supports multiple networking configurations, selectable per session:

1. **Direct** — Standard URLSession (no proxy)
2. **DNS-over-HTTPS** — Encrypted DNS resolution
3. **WireGuard (NordLynx)** — Custom userspace WireGuard tunnel
4. **OpenVPN** — TCP or UDP tunnel with SOCKS5 bridge
5. **Local Proxy** — On-device SOCKS5 proxy server
6. **Device Proxy** — System-wide proxy configuration
7. **Hybrid** — Layered combination of the above

---

## Anti-Detection & Stealth

| Technique | Service |
|-----------|---------|
| Human-like typing | `HumanTypingEngine` / `HardwareTypingEngine` |
| Fingerprint tuning | `AIFingerprintTuningService`, `FingerprintValidationService` |
| Adaptive timing | `AITimingOptimizerService`, `LiveSpeedAdaptationService` |
| Proxy rotation | `ProxyRotationManager`, `ProxyRotationService` |
| Challenge solving | `AIChallengePageSolverService`, `ChallengePageClassifier` |
| Session health | `AISessionHealthMonitorService`, `AIAntiDetectionAdaptiveService` |
| Circuit breaking | `HostCircuitBreakerService` |
| Page readiness | `PageReadinessService`, `SmartPageSettlementService` |
| Blank-page recovery | `BlankPageRecoveryService` |
| Smart button recovery | `SmartButtonRecoveryService` |

---

## Getting Started

### Prerequisites

- **macOS** with Xcode 16+ installed
- **iOS 17+** deployment target
- Apple Developer account (for device deployment and entitlements)

### Build & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/sitchomatic/rork-sitchomaticultimate.git
   cd rork-sitchomaticultimate
   ```

2. Open the Xcode project:
   ```bash
   open ios/Sitchomatic.xcodeproj
   ```

3. Select a target device or simulator and press **⌘R** to build and run.

### Configuration

- **Automation settings** are managed via `AutomationSettingsView` in-app, backed by `AutomationSettings` (Codable, JSON-persisted).
- **Templates** — 6 built-in automation presets are defined in `AutomationTemplate.swift`.
- **VPN credentials** are stored in the device Keychain via `NordVPNKeyStore` / `GrokKeychain`.

---

## Codebase Stats

| Metric | Value |
|--------|-------|
| Swift source files | 349 |
| Total lines of code | 113,000+ |
| Service files | 169 |
| AI service files | 19 |
| View files | 94 |
| Model files | 46 |
| ViewModel files | 16 |
| Utility files | 14 |
| Max concurrent sessions | 8 |
| Screenshot cache (memory) | 10 |
| Screenshot cache (disk) | 200 |

---

## License

This project is proprietary. All rights reserved.
