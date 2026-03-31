import Foundation
import WebKit
import Observation

@Observable
class LiveWebViewDebugService {
    static let shared = LiveWebViewDebugService()

    var attachedWebViewID: UUID?
    var attachedWebView: WKWebView?
    var attachedLabel: String = ""
    var attachedSessionIndex: Int = 0
    var attachedStartedAt: Date?
    var isFullScreen: Bool = false
    var showEndedToast: Bool = false
    var autoObserve: Bool = false
    var isInteractive: Bool = false
    var currentURL: String = ""
    var currentTitle: String = ""
    var consoleEntries: [LiveConsoleEntry] = []
    var showConsole: Bool = false
    var screenshotToast: Bool = false

    var isAttached: Bool { attachedWebView != nil }

    private var urlObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?
    private var toastDismissTask: Task<Void, Never>?

    private init() {
        setupPoolCallbacks()
    }

    func attach(webViewID: UUID, webView: WKWebView, label: String, sessionIndex: Int, startedAt: Date?) {
        if attachedWebViewID == webViewID { return }
        cleanupObservations()
        attachedWebViewID = webViewID
        attachedWebView = webView
        attachedLabel = label
        attachedSessionIndex = sessionIndex
        attachedStartedAt = startedAt ?? Date()
        isFullScreen = false
        showEndedToast = false
        isInteractive = false
        consoleEntries = []
        currentURL = webView.url?.absoluteString ?? ""
        currentTitle = webView.title ?? ""
        setupKVO(for: webView)
        injectConsoleInterceptor(into: webView)
    }

    func detach() {
        cleanupObservations()
        removeConsoleInterceptor()
        attachedWebViewID = nil
        attachedWebView = nil
        attachedLabel = ""
        attachedSessionIndex = 0
        attachedStartedAt = nil
        isFullScreen = false
        isInteractive = false
        currentURL = ""
        currentTitle = ""
    }

    func attachToNearest() {
        let pool = WebViewPool.shared
        guard let first = pool.activeViews.first else {
            detach()
            return
        }
        attach(webViewID: first.key, webView: first.value, label: "Session", sessionIndex: 0, startedAt: nil)
    }

    func captureScreenshot() {
        guard let webView = attachedWebView else { return }
        let config = WKSnapshotConfiguration()
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            guard let self, let image else { return }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            self.screenshotToast = true
            self.toastDismissTask?.cancel()
            self.toastDismissTask = Task {
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled {
                    self.screenshotToast = false
                }
            }
        }
    }

    func addConsoleEntry(level: LiveConsoleEntry.Level, message: String) {
        let entry = LiveConsoleEntry(level: level, message: message)
        consoleEntries.append(entry)
        if consoleEntries.count > 200 {
            consoleEntries.removeFirst(consoleEntries.count - 200)
        }
    }

    // MARK: - Pool Callbacks (#7 + #9)

    private func setupPoolCallbacks() {
        let pool = WebViewPool.shared
        pool.onUnmount = { [weak self] id in
            guard let self else { return }
            if self.attachedWebViewID == id {
                self.showEndedToast = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    if self.attachedWebViewID == id {
                        self.detach()
                        if self.autoObserve {
                            self.attachToNearest()
                        }
                    }
                }
            }
        }
        pool.onMount = { [weak self] id, webView in
            guard let self else { return }
            if self.autoObserve && !self.isAttached {
                self.attach(webViewID: id, webView: webView, label: "Auto", sessionIndex: 0, startedAt: Date())
            }
        }
    }

    // MARK: - KVO (#6)

    private func setupKVO(for webView: WKWebView) {
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
            Task { @MainActor [weak self] in
                self?.currentURL = wv.url?.absoluteString ?? ""
            }
        }
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
            Task { @MainActor [weak self] in
                self?.currentTitle = wv.title ?? ""
            }
        }
    }

    private func cleanupObservations() {
        urlObservation?.invalidate()
        urlObservation = nil
        titleObservation?.invalidate()
        titleObservation = nil
    }

    // MARK: - Console Interception (#3)

    private let consoleHandlerName = "liveDebugConsole"

    private func injectConsoleInterceptor(into webView: WKWebView) {
        let js = """
        (function() {
            if (window.__liveDebugConsoleInjected) return;
            window.__liveDebugConsoleInjected = true;
            var origLog = console.log, origWarn = console.warn, origError = console.error;
            function post(level, args) {
                try {
                    window.webkit.messageHandlers.liveDebugConsole.postMessage({level: level, message: Array.from(args).map(String).join(' ')});
                } catch(e) {}
            }
            console.log = function() { post('log', arguments); origLog.apply(console, arguments); };
            console.warn = function() { post('warn', arguments); origWarn.apply(console, arguments); };
            console.error = function() { post('error', arguments); origError.apply(console, arguments); };
        })();
        """
        let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
        let handler = LiveConsoleMessageHandler(service: self)
        webView.configuration.userContentController.add(handler, name: consoleHandlerName)
    }

    private func removeConsoleInterceptor() {
        attachedWebView?.configuration.userContentController.removeScriptMessageHandler(forName: consoleHandlerName)
    }
}

struct LiveConsoleEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let level: Level
    let message: String

    enum Level: String, Sendable {
        case log, warn, error
    }
}

class LiveConsoleMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var service: LiveWebViewDebugService?

    init(service: LiveWebViewDebugService) {
        self.service = service
        super.init()
    }

    nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Task { @MainActor [weak self] in
            guard let self, let service = self.service else { return }
            guard let body = message.body as? [String: String],
                  let levelStr = body["level"],
                  let msg = body["message"] else { return }
            let level: LiveConsoleEntry.Level = switch levelStr {
            case "warn": .warn
            case "error": .error
            default: .log
            }
            service.addConsoleEntry(level: level, message: msg)
        }
    }
}
