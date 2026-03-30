import SwiftUI

struct ActiveSessionRowView: View {
    let item: ActiveSessionItem
    @State private var liveFlash: Bool = false
    private var debugService: LiveWebViewDebugService { LiveWebViewDebugService.shared }

    private var isLiveAttached: Bool {
        guard let wvID = item.webViewID else { return false }
        return debugService.isAttached && debugService.attachedWebViewID == wvID
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                    .frame(width: 28, height: 28)
                Circle()
                    .trim(from: 0, to: item.progress)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
                Image(systemName: item.statusIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(progressColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if isLiveAttached {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                            .symbolEffect(.pulse)
                    }
                }
                Text(item.statusText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Text(item.elapsed)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(liveFlash ? Color.green.opacity(0.2) : Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 8))
        .onTapGesture(count: 3) {
            attachLiveWebView()
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: liveFlash)
    }

    private var progressColor: Color {
        if item.progress >= 0.8 { return .green }
        if item.progress >= 0.4 { return .cyan }
        return .blue
    }

    private func attachLiveWebView() {
        guard item.isActive else { return }
        let pool = WebViewPool.shared
        guard let wvID = item.webViewID,
              let webView = pool.activeViews[wvID] else {
            guard let match = pool.activeViews.first else { return }
            withAnimation(.easeInOut(duration: 0.15)) { liveFlash = true }
            debugService.attach(
                webViewID: match.key,
                webView: match.value,
                label: item.label,
                sessionIndex: 0,
                startedAt: nil
            )
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation { liveFlash = false }
            }
            return
        }
        withAnimation(.easeInOut(duration: 0.15)) { liveFlash = true }
        debugService.attach(
            webViewID: wvID,
            webView: webView,
            label: item.label,
            sessionIndex: 0,
            startedAt: nil
        )
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation { liveFlash = false }
        }
    }
}
