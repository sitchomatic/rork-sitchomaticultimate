import SwiftUI

/// Swift 6.2 optimized appearance mode with frozen enum for performance
@frozen
enum AppAppearanceMode: String, CaseIterable, Sendable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    @inline(__always)
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    @inline(__always)
    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

/// Swift 6.2 optimized connection status with frozen enum for performance
@frozen
enum AppConnectionStatus: String, Sendable, Codable {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case connected = "Connected"
    case error = "Error"
}
