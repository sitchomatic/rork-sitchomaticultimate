import Foundation
import Observation
import UIKit
import SwiftUI

// PPSRDebugScreenshot is now a type alias for CapturedScreenshot in UnifiedScreenshotManager.swift.
// UserResultOverride enum is kept here as it's referenced throughout the codebase.

@frozen
nonisolated enum UserResultOverride: String, Sendable, CaseIterable {
    case none
    case success
    case noAcc
    case permDisabled
    case tempDisabled
    case unsure

    var displayLabel: String {
        switch self {
        case .none: "Auto"
        case .success: "Success"
        case .noAcc: "No Acc"
        case .permDisabled: "Perm Disabled"
        case .tempDisabled: "Temp Disabled"
        case .unsure: "Unsure"
        }
    }

    var color: SwiftUI.Color {
        switch self {
        case .none: .gray
        case .success: .green
        case .noAcc: .secondary
        case .permDisabled: .red
        case .tempDisabled: .orange
        case .unsure: .yellow
        }
    }

    var icon: String {
        switch self {
        case .none: "questionmark.circle"
        case .success: "checkmark.circle.fill"
        case .noAcc: "xmark.circle.fill"
        case .permDisabled: "lock.slash.fill"
        case .tempDisabled: "clock.badge.exclamationmark"
        case .unsure: "questionmark.diamond.fill"
        }
    }

    static var overrideable: [UserResultOverride] {
        [.success, .noAcc, .permDisabled, .tempDisabled, .unsure]
    }
}

