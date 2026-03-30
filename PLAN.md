# Live Look-In: 9 Improvements (All except Session Picker)

Implementing all 10 suggested improvements except #2 (Session Picker Sheet).

---

### 1. Fix Broken Session-to-WebView Matching (Critical Bug)

- Currently `attachLiveWebView()` grabs the first arbitrary webview from the pool instead of the one belonging to the tapped session
- Fix both `LoginSessionRow` and `ActiveSessionRowView` to match by session ID instead of `first(where: { _ in true })`
- Add a `webViewID` property to `ActiveSessionItem` so it can look up the correct webview

### 3. Live Console & Network Overlay

- Add a `WKScriptMessageHandler` to intercept `console.log`, `console.error`, `console.warn` from the attached webview
- Create a togglable translucent overlay panel in the full-screen view showing real-time JS console output
- Color-code entries by level (log=white, warn=orange, error=red)
- Auto-scroll to latest entry, with a max buffer of 200 lines

### 4. Manual Screenshot Capture Button

- Add a camera button to the full-screen view toolbar
- Uses `WKWebView.takeSnapshot()` to capture the current page
- Saves the screenshot to the photo library and shows a brief confirmation toast
- Haptic feedback on capture

### 5. Fix Static Elapsed Timer

- Wrap the elapsed time display in `TimelineView(.periodic(from: .now, by: 1))` so it updates every second
- Apply to both the full-screen view toolbar and the mini window (add elapsed display to mini window too)

### 6. Live URL Bar & Page Title

- Add KVO observers on the attached webview's `.url` and `.title` properties
- Display the current page title and truncated URL below the session info bar in the full-screen view
- Update in real-time as the automation navigates between pages

### 7. Replace Polling with Callback-Based Detection

- Remove the 1-second polling loop from `LiveWebViewDebugService`
- Instead, hook into `WebViewPool.unmount(id:)` to notify `LiveWebViewDebugService` when the attached webview is removed
- Instant detection with zero CPU overhead

### 8. Resizable Mini Window with Snap-to-Corner

- Replace free-drag with snap-to-corner behavior (like iOS Picture-in-Picture)
- On drag end, animate the window to the nearest screen corner
- Add pinch gesture to cycle between 3 size presets: small (120×210), medium (160×280), large (220×385)
- Prevent the window from going off-screen

### 9. Auto-Attach to Next Session

- Add an `autoObserve` toggle to `LiveWebViewDebugService`
- When enabled, observe `WebViewPool.activeViews` changes and automatically attach to newly mounted webviews
- Show a small "Auto" badge on the mini window when active
- Togglable from the full-screen view toolbar

### 10. Interactive Debug Mode in Full-Screen

- Add a toggle button in the full-screen toolbar to switch between "View Only" and "Interactive" modes
- In interactive mode, enable hit testing on the webview so you can tap, scroll, and type
- Show a clear visual indicator (orange border + "INTERACTIVE" badge) when interactive mode is on
- Default to view-only to prevent accidental interference with automation

