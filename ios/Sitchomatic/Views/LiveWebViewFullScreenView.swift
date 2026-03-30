import SwiftUI
import WebKit

struct LiveWebViewFullScreenView: View {
    @State private var debugService = LiveWebViewDebugService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let webView = debugService.attachedWebView {
                    LiveWebViewContainerView(webView: webView)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ContentUnavailableView(
                        "Session Ended",
                        systemImage: "play.slash",
                        description: Text("The WebView session has been torn down.")
                    )
                }
            }
            .background(.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    sessionInfo
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        debugService.isFullScreen = false
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pip.enter")
                            Text("Minimize")
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        debugService.detach()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
    }

    private var sessionInfo: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 7, height: 7)
            Text("LIVE")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(.red)
            Text(debugService.attachedLabel.prefix(18))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .lineLimit(1)
            Text("S\(debugService.attachedSessionIndex)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color(.tertiarySystemFill))
                .clipShape(.rect(cornerRadius: 3))
            if let start = debugService.attachedStartedAt {
                Text(elapsedString(from: start))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func elapsedString(from start: Date) -> String {
        let elapsed = Date().timeIntervalSince(start)
        if elapsed < 60 { return String(format: "%.0fs", elapsed) }
        let m = Int(elapsed) / 60
        let s = Int(elapsed) % 60
        return "\(m)m \(s)s"
    }
}
