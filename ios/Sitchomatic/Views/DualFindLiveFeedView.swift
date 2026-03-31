import SwiftUI

// DualFindLiveFeedView is now a thin wrapper around UnifiedScreenshotFeedView.
// DualFind screenshots now appear in the unified feed.

struct DualFindLiveFeedView: View {
    @Bindable var vm: DualFindViewModel

    var body: some View {
        UnifiedScreenshotFeedView()
            .navigationTitle("Live Feed")
    }
}
