import SwiftUI

@frozen
enum ProductMode: String, CaseIterable, Sendable {
    case ppsr = "PPSR CarCheck"

    @inlinable
    var title: String { rawValue }

    @inlinable
    var isLoginMode: Bool { false }

    @inlinable
    var baseURL: String {
        switch self {
        case .ppsr: "https://transact.ppsr.gov.au/CarCheck/"
        }
    }
}
