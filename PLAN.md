# Live WebView Debug Preview — Triple-Tap to Watch

## Features

- **Triple-tap any active session row** (in both the Sessions list and the Run Command active sessions) to attach to that session's live WebView
- **Floating mini-window** appears as a draggable, resizable picture-in-picture overlay showing the real-time WebView content
- **Tap the mini-window to expand** to a full-screen sheet with the live WebView at native resolution
- **Session picker badge** — the attached session shows a green "LIVE 👁" indicator on its row
- **Auto-detach** when the session completes or is torn down — mini-window fades out with a brief "Session ended" toast
- **Switch sessions** by triple-tapping a different active session row — seamlessly transfers the live preview
- **Login engine only** for now — works with `LoginSiteWebSession` WebViews tracked in `WebViewPool`

## Design

- **Mini-window**: ~160×280pt floating overlay with rounded corners, thin green glowing border, "LIVE" badge in top-left corner, drag handle at top. Positioned bottom-right by default. Subtle drop shadow
- **Full-screen mode**: Full sheet with the WebView filling the screen, a top toolbar showing the credential email, session index, elapsed time, and a "Minimize" button to return to mini-window
- **Triple-tap feedback**: Haptic impact + brief green flash on the tapped session row
- **Session row indicator**: Small pulsing green eye icon (SF Symbol `eye.fill`) next to the session label when that session is being watched
- **Detach toast**: Small capsule notification "Session ended" that fades after 2 seconds

## How It Works (Technical Summary)

1. **LiveWebViewDebugService** — A singleton `@Observable` that holds the currently-attached WebView UUID and manages the live preview state (attached/detached, mini/fullscreen)
2. **Triple-tap gesture** added to `LoginSessionRow` and `ActiveSessionRowView` — looks up the session's WebView UUID in `WebViewPool.shared.activeViews` and attaches it to the debug service
3. **LiveWebViewMiniWindow** — A draggable overlay view that uses `EphemeralWebViewContainer` to display the actual WKWebView at mini size. Mounted in the app's root view via `.overlay`
4. **LiveWebViewFullScreen** — A sheet that displays the same WebView at full resolution with session metadata
5. **HiddenWebViewAnchor modification** — When a WebView is attached to the live preview, it's excluded from the hidden 1x1 anchor (since it's now visible elsewhere)
6. **Auto-cleanup** — Observes `WebViewPool` changes; when the attached UUID is unmounted, auto-detaches

## Files Created/Modified

- **New**: `LiveWebViewDebugService.swift` — singleton managing live preview state
- **New**: `LiveWebViewMiniWindow.swift` — floating draggable mini-window overlay
- **New**: `LiveWebViewFullScreenView.swift` — full-screen sheet view
- **Modified**: `LoginSessionRow` — add triple-tap gesture + live indicator badge
- **Modified**: `ActiveSessionRowView` — add triple-tap gesture + live indicator badge  
- **Modified**: `HiddenWebViewAnchor` — skip rendering attached WebView at 1x1
- **Modified**: App root / ContentView — add the mini-window overlay

