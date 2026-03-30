import SwiftUI
import WebKit

struct LiveWebViewMiniWindow: View {
    @State private var debugService = LiveWebViewDebugService.shared
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let miniWidth: CGFloat = 160
    private let miniHeight: CGFloat = 280

    var body: some View {
        if debugService.isAttached, let webView = debugService.attachedWebView {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.black)
                    .overlay {
                        LiveWebViewContainerView(webView: webView)
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
            }
            .frame(width: miniWidth, height: miniHeight)
            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
            .offset(x: offset.width, y: offset.height)
            .gesture(dragGesture)
            .onTapGesture {
                debugService.isFullScreen = true
            }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.5).combined(with: .opacity),
                removal: .scale(scale: 0.5).combined(with: .opacity)
            ))
            .animation(.spring(duration: 0.3), value: debugService.isAttached)
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
            Text("LIVE")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.red.opacity(0.85))
        .clipShape(Capsule())
        .padding(6)
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

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
}

struct LiveWebViewContainerView: UIViewRepresentable {
    let webView: WKWebView

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
    }
}
