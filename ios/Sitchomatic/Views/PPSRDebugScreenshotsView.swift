import SwiftUI

// PPSRDebugScreenshotsView is now a thin wrapper around UnifiedScreenshotFeedView.
// All album, card, and correction functionality has been merged into the unified feed.

struct PPSRDebugScreenshotsView: View {
    @Bindable var vm: PPSRAutomationViewModel

    var body: some View {
        UnifiedScreenshotFeedView()
            .navigationTitle("Debug Screenshots")
    }
}
