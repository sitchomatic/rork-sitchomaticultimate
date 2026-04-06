import Foundation
import WebKit

nonisolated enum TripleClickSubmitError: Error, Sendable {
    case cancelled
    case webViewUnavailable
    case jsEvaluationFailed(String)
    case elementNotFound
}

@MainActor
final class TripleClickSubmitEngine {
    static let shared = TripleClickSubmitEngine()

    private let click1Delay: Duration = .milliseconds(240)
    private let click2Delay: Duration = .milliseconds(260)

    private init() {}

    func executeTripleClickSubmitSequence(targetSelector: String, in webView: WKWebView) async throws {
        guard !Task.isCancelled else { throw TripleClickSubmitError.cancelled }

        let elementCheckJS = """
        (function(){
            var el = document.querySelector('\(targetSelector.replacingOccurrences(of: "'", with: "\\'"))');
            if (!el) return 'NOT_FOUND';
            var r = el.getBoundingClientRect();
            return JSON.stringify({x: r.left + r.width/2, y: r.top + r.height/2, w: r.width, h: r.height});
        })()
        """
        let checkResult = try await evaluateJS(elementCheckJS, in: webView)
        guard checkResult != "NOT_FOUND" else { throw TripleClickSubmitError.elementNotFound }

        let clickJS = buildClickJS(targetSelector: targetSelector)

        // Click 1
        guard !Task.isCancelled else { throw TripleClickSubmitError.cancelled }
        let result1 = try await evaluateJS(clickJS, in: webView)
        guard result1.contains("CLICKED") else {
            throw TripleClickSubmitError.jsEvaluationFailed("Click 1 failed: \(result1)")
        }

        guard !Task.isCancelled else { throw TripleClickSubmitError.cancelled }
        try await Task.sleep(for: click1Delay)

        // Click 2
        guard !Task.isCancelled else { throw TripleClickSubmitError.cancelled }
        let result2 = try await evaluateJS(clickJS, in: webView)
        guard result2.contains("CLICKED") else {
            throw TripleClickSubmitError.jsEvaluationFailed("Click 2 failed: \(result2)")
        }

        guard !Task.isCancelled else { throw TripleClickSubmitError.cancelled }
        try await Task.sleep(for: click2Delay)

        // Click 3
        guard !Task.isCancelled else { throw TripleClickSubmitError.cancelled }
        let result3 = try await evaluateJS(clickJS, in: webView)
        guard result3.contains("CLICKED") else {
            throw TripleClickSubmitError.jsEvaluationFailed("Click 3 failed: \(result3)")
        }
    }

    private func buildClickJS(targetSelector: String) -> String {
        let escaped = targetSelector.replacingOccurrences(of: "'", with: "\\'")
        return """
        (function(){
            var el = document.querySelector('\(escaped)');
            if (!el) return 'NOT_FOUND';
            var r = el.getBoundingClientRect();
            var cx = r.left + r.width/2;
            var cy = r.top + r.height/2;
            el.dispatchEvent(new MouseEvent('mousedown',{bubbles:true,cancelable:true,clientX:cx,clientY:cy,button:0,buttons:1}));
            el.dispatchEvent(new MouseEvent('mouseup',{bubbles:true,cancelable:true,clientX:cx,clientY:cy,button:0}));
            el.dispatchEvent(new MouseEvent('click',{bubbles:true,cancelable:true,clientX:cx,clientY:cy,button:0}));
            return 'CLICKED:'+el.tagName+':'+el.textContent.substring(0,30);
        })()
        """
    }

    private func evaluateJS(_ js: String, in webView: WKWebView) async throws -> String {
        do {
            let result = try await webView.evaluateJavaScript(js)
            return (result as? String) ?? "UNKNOWN"
        } catch {
            throw TripleClickSubmitError.jsEvaluationFailed(error.localizedDescription)
        }
    }
}
