import SwiftUI
import UIKit

/// A SwiftUI wrapper around `UIActivityViewController` for sharing content.
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [any Sendable]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
