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

    var isAttached: Bool { attachedWebView != nil }

    private var pollTask: Task<Void, Never>?

    private init() {}

    func attach(webViewID: UUID, webView: WKWebView, label: String, sessionIndex: Int, startedAt: Date?) {
        if attachedWebViewID == webViewID { return }
        attachedWebViewID = webViewID
        attachedWebView = webView
        attachedLabel = label
        attachedSessionIndex = sessionIndex
        attachedStartedAt = startedAt
        isFullScreen = false
        showEndedToast = false
        startPolling()
    }

    func detach() {
        pollTask?.cancel()
        pollTask = nil
        attachedWebViewID = nil
        attachedWebView = nil
        attachedLabel = ""
        attachedSessionIndex = 0
        attachedStartedAt = nil
        isFullScreen = false
    }

    func attachToNearest() {
        let pool = WebViewPool.shared
        guard let first = pool.activeViews.first else {
            detach()
            return
        }
        attach(webViewID: first.key, webView: first.value, label: "Session", sessionIndex: 0, startedAt: nil)
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, let id = self.attachedWebViewID else { break }
                if WebViewPool.shared.activeViews[id] == nil {
                    self.showEndedToast = true
                    try? await Task.sleep(for: .seconds(2))
                    if !Task.isCancelled {
                        self.detach()
                    }
                    break
                }
            }
        }
    }
}
