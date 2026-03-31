import SwiftUI

// LoginDebugScreenshotsView is now a thin wrapper around UnifiedScreenshotFeedView.
// All category filters, album views, correction sheets, and evidence badges
// have been merged into the unified feed.

struct LoginDebugScreenshotsView: View {
    @Bindable var vm: LoginViewModel

    var body: some View {
        UnifiedScreenshotFeedView()
            .navigationTitle("Debug Screenshots")
    }
}
