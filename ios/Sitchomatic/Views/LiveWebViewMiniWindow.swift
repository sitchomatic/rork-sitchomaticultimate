import SwiftUI
import WebKit

struct LiveWebViewMiniWindow: View {
    @State private var debugService = LiveWebViewDebugService.shared
    @State private var position: CGPoint = .zero
    @State private var sizePreset: SizePreset = .medium
    @State private var isDragging: Bool = false

    private enum SizePreset: CaseIterable {
        case small, medium, large

        var size: CGSize {
            switch self {
            case .small: CGSize(width: 120, height: 210)
            case .medium: CGSize(width: 160, height: 280)
            case .large: CGSize(width: 220, height: 385)
            }
        }

        var next: SizePreset {
            switch self {
            case .small: .medium
            case .medium: .large
            case .large: .small
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            if debugService.isAttached, !debugService.isFullScreen, let webView = debugService.attachedWebView {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.black)
                        .overlay {
                            LiveWebViewContainerView(webView: webView, interactive: false)
                                .clipShape(.rect(cornerRadius: 14))
                                .allowsHitTesting(false)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.green.opacity(0.7), lineWidth: 1.5)
                        )

                    liveBadge

                    if debugService.showEndedToast {
                        endedToast
                    }

                    closeButton

                    elapsedBadge
                }
                .frame(width: sizePreset.size.width, height: sizePreset.size.height)
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                .position(position == .zero ? snapToCorner(.bottomRight, in: geo) : position)
                .gesture(dragGesture(in: geo))
                .onTapGesture {
                    debugService.isFullScreen = true
                }
                .gesture(
                    MagnifyGesture()
                        .onEnded { _ in
                            withAnimation(.spring(duration: 0.3)) {
                                sizePreset = sizePreset.next
                                position = nearestCorner(from: position, in: geo)
                            }
                        }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity),
                    removal: .scale(scale: 0.5).combined(with: .opacity)
                ))
                .animation(.spring(duration: 0.3), value: debugService.isAttached)
                .animation(.spring(duration: 0.3), value: sizePreset)
                .onAppear {
                    if position == .zero {
                        position = snapToCorner(.bottomRight, in: geo)
                    }
                }
            }
        }
        .allowsHitTesting(debugService.isAttached && !debugService.isFullScreen)
    }

    private var liveBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
            Text("LIVE")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
            if debugService.autoObserve {
                Text("AUTO")
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(.cyan)
                    .clipShape(.rect(cornerRadius: 2))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.red.opacity(0.85))
        .clipShape(Capsule())
        .padding(6)
    }

    private var elapsedBadge: some View {
        VStack {
            Spacer()
            HStack {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    if let start = debugService.attachedStartedAt {
                        Text(elapsedString(from: start))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.6))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }
            .padding(6)
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        debugService.detach()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.7))
                        .background(Circle().fill(.black.opacity(0.5)))
                }
                .padding(6)
            }
            Spacer()
        }
    }

    private var endedToast: some View {
        VStack {
            Spacer()
            Text("Session ended")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    // MARK: - Snap-to-Corner

    private enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    private let edgePadding: CGFloat = 12

    private func snapToCorner(_ corner: Corner, in geo: GeometryProxy) -> CGPoint {
        let w = sizePreset.size.width / 2
        let h = sizePreset.size.height / 2
        let safeArea = geo.safeAreaInsets
        switch corner {
        case .topLeft:
            return CGPoint(x: edgePadding + w, y: safeArea.top + edgePadding + h)
        case .topRight:
            return CGPoint(x: geo.size.width - edgePadding - w, y: safeArea.top + edgePadding + h)
        case .bottomLeft:
            return CGPoint(x: edgePadding + w, y: geo.size.height - safeArea.bottom - edgePadding - h)
        case .bottomRight:
            return CGPoint(x: geo.size.width - edgePadding - w, y: geo.size.height - safeArea.bottom - edgePadding - h)
        }
    }

    private func nearestCorner(from point: CGPoint, in geo: GeometryProxy) -> CGPoint {
        let corners: [Corner] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
        var closest = snapToCorner(.bottomRight, in: geo)
        var minDist = CGFloat.greatestFiniteMagnitude
        for corner in corners {
            let p = snapToCorner(corner, in: geo)
            let dist = hypot(point.x - p.x, point.y - p.y)
            if dist < minDist {
                minDist = dist
                closest = p
            }
        }
        return closest
    }

    private func dragGesture(in geo: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                position = value.location
            }
            .onEnded { value in
                isDragging = false
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                    position = nearestCorner(from: value.location, in: geo)
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

struct LiveWebViewContainerView: UIViewRepresentable {
    let webView: WKWebView
    var interactive: Bool = false

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.clipsToBounds = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        webView.isUserInteractionEnabled = interactive
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if webView.superview !== uiView {
            uiView.subviews.forEach { $0.removeFromSuperview() }
            webView.translatesAutoresizingMaskIntoConstraints = false
            uiView.addSubview(webView)
            NSLayoutConstraint.activate([
                webView.topAnchor.constraint(equalTo: uiView.topAnchor),
                webView.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: uiView.trailingAnchor),
                webView.bottomAnchor.constraint(equalTo: uiView.bottomAnchor),
            ])
        }
        webView.isUserInteractionEnabled = interactive
    }
}
