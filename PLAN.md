# Fix All 15 Error Audit Issues

## Summary

Fix all 15 issues identified in the automation & screenshot error audit — 4 critical, 6 significant, 5 minor.

---

### 🔴 Fix 1 — Double Pre-Test Network Check (PPSRAutomationEngine)

**Problem:** `testSingleCardViaPPSR()` runs `engine.runPreTestNetworkCheck()` manually, then calls `engine.runCheck()` which runs it again internally.

**Fix:** Remove the redundant pre-test call from `testSingleCardViaPPSR()` and instead pass a `skipPreTest` flag to `PPSRAutomationEngine.runCheck()` — matching how BPoint already works. The ViewModel will do the pre-test, then tell the engine to skip its internal one.

**Files:** `PPSRAutomationEngine.swift`, `PPSRAutomationViewModel.swift`

---

### 🔴 Fix 2 — Screenshot Memory Leak in handleMemoryPressure

**Problem:** `handleMemoryPressure()` calls `ScreenshotCacheService.shared.store(ss.image, ...)` which decodes JPEG data back to UIImage, then re-compresses it — double JPEG compression during memory pressure (worst time for CPU spikes).

**Fix:** Change `handleMemoryPressure()` to use `.storeData(ss.imageData, ...)` directly — matching `addScreenshot()` — to avoid the decode→re-encode cycle.

**Files:** `PPSRAutomationViewModel.swift`

---

### 🔴 Fix 3 — ScreenshotImageCache Thread Safety

**Problem:** `ScreenshotImageCache` is `nonisolated @unchecked Sendable` but the check→miss→create→store pattern isn't atomic — two threads could create duplicate images.

**Fix:** Add an `NSLock` around the cache-check-and-store operation to make it truly thread-safe.

**Files:** `ScreenshotImageCache.swift`

---

### 🔴 Fix 4 — Batch Concurrency Counter Race Condition

**Problem:** `activeTestCount` is incremented on MainActor before task starts, but decremented via `Task { @MainActor in }` inside `group.addTask` defer — can go negative after `forceFinalizeBatch` resets it to 0.

**Fix:** Guard the decrement: only decrement if `activeTestCount > 0` and if `isRunning` is still true. This removes the need for `syncActiveTestCount()` as a band-aid. Also keep `syncActiveTestCount()` as a safety net but remove the warning log since it's expected.

**Files:** `PPSRAutomationViewModel.swift`

---

### 🟡 Fix 5 — BlankScreenshotDetector Sample Size Too Small

**Problem:** 60×60 pixel sample means fine UI details are lost, increasing false positive rate.

**Fix:** Increase sample size from 60×60 to 120×120 pixels — 4× more data for better accuracy with minimal CPU cost.

**Files:** `BlankScreenshotDetector.swift`

---

### 🟡 Fix 6 — PPSRAutomationEngine Uses Default AutomationSettings

**Problem:** `performCheck()` creates `let blankPageSettings = AutomationSettings()` — uses defaults instead of user-configured settings.

**Fix:** Add an `automationSettings: AutomationSettings` property to `PPSRAutomationEngine` that the ViewModel sets during `configureEngine()`. Use that instead of creating a fresh default.

**Files:** `PPSRAutomationEngine.swift`, `PPSRAutomationViewModel.swift`

---

### 🟡 Fix 7 — BPoint Screenshot Crop Rect Not Applied in Pool Check

**Problem:** Screenshots captured during biller validation in `performBPointPoolCheck` don't use the crop rect.

**Fix:** Pass `screenshotCropRect` through to the `captureScreenshotForCheck` calls within `performBPointPoolCheck` — same pattern already used in the PPSR engine.

**Files:** `BPointAutomationEngine.swift`

---

### 🟡 Fix 8 — Dual Screenshot Systems Inconsistency

**Problem:** Two separate screenshot systems (`PPSRDebugScreenshot` with 200 limit vs `UnifiedScreenshot` with 300 limit) have different compression levels and cache strategies.

**Fix:** Align the memory limits and compression quality between the two systems. Set both to use the same overflow limit (200) and same JPEG compression (0.4). This is a config alignment, not a full refactor.

**Files:** `PPSRAutomationViewModel.swift`, `UnifiedScreenshotManager.swift`

---

### 🟡 Fix 9 — ScreenshotCacheService.fileURL nonisolated Safety

**Problem:** `fileURL(for:)` is `nonisolated` but accesses `FileManager` from mixed isolation contexts.

**Fix:** Since `FileManager.default.urls()` is thread-safe and the function is pure (no shared mutable state), this is safe but fragile. Cache the base directory URL at init time so `fileURL(for:)` doesn't need to call `FileManager` each time.

**Files:** `ScreenshotCacheService.swift`

---

### 🟡 Fix 10 — Auto-Retry Creates Unbounded Retry Chains

**Problem:** `finalizePPSRBatch()` calls `testSelectedCards(retryCards)` which starts a NEW batch that clears `autoRetryBackoffCounts` — creating an infinite loop.

**Fix:** Don't clear `autoRetryBackoffCounts` at the start of `testSelectedCards()`. Only clear it at the start of `testAllUntestedViaPPSR()` and `testAllUntestedViaBPoint()` (fresh user-initiated batches). This preserves retry counts across auto-retry chains and properly enforces `autoRetryMaxAttempts`.

**Files:** `PPSRAutomationViewModel.swift`

---

### 🟢 Fix 11 — FlipbookPage Unused Variable

**Problem:** `let fitHeight = fitWidth / imageAspect` is computed but never used.

**Fix:** Remove the unused variable.

**Files:** `ScreenshotFlipbookView.swift`

---

### 🟢 Fix 12 — Unnecessary Array Allocation in ForEach

**Problem:** `ForEach(Array(vm.debugScreenshots.enumerated()), id: \.element.id)` creates a new array every re-render.

**Fix:** Keep the `enumerated()` pattern since the `index` is actually used for the flipbook context menu — but this is correct as-is. The allocation is negligible. **No change needed** — marking as intentional.

---

### 🟢 Fix 13 — Double Screenshot Compression

**Problem:** `captureScreenshotForCheck()` compresses to 0.3 quality, then `PPSRDebugScreenshot.init` compresses AGAIN to 0.4 quality.

**Fix:** Remove the pre-compression in `captureScreenshotForCheck()` and pass the original image directly to `PPSRDebugScreenshot.init` which does its own compression at 0.4. Single compression = better quality + less CPU.

**Files:** `PPSRAutomationEngine.swift`

---

### 🟢 Fix 14 — Timeout Confusion (pageLoadTimeout vs testTimeout vs waitForResponseSeconds)

**Problem:** Three overlapping timeout values that can be configured independently but affect similar operations.

**Fix:** Add a clarifying inline comment to each timeout property explaining its specific scope. No functional change — this is a documentation/clarity fix.

**Files:** `AutomationSettings.swift`, `PPSRAutomationViewModel.swift`

---

### 🟢 Fix 15 — autoRetryBackoffCounts Not Cleaned Up

**Problem:** `autoRetryBackoffCounts` retains stale card IDs after all retries complete.

**Fix:** Clear `autoRetryBackoffCounts` in `finalizePPSRBatch()` AFTER the auto-retry scheduling logic (not before). This ensures stale data is cleaned up once no more retries are needed.

**Files:** `PPSRAutomationViewModel.swift`
