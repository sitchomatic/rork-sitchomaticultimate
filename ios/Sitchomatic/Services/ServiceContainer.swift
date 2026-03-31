import Foundation

@MainActor
class ServiceContainer {
    static let shared = ServiceContainer()

    lazy var proxyRotation: ProxyRotationService = .shared
    lazy var networkSessionFactory: NetworkSessionFactory = .shared
    lazy var deviceProxy: DeviceProxyService = .shared
    lazy var debugLogger: DebugLogger = .shared
    lazy var fingerprintValidation: FingerprintValidationService = .shared
    lazy var screenshotCache: ScreenshotCache = .shared

    lazy var socks5Manager: SOCKS5ProxyManager = SOCKS5ProxyManager()
    lazy var jsBuilder: LoginJSBuilder = LoginJSBuilder()
    lazy var typingEngine: HumanTypingEngine = HumanTypingEngine()
}
