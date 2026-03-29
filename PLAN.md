# Implement improvements 1, 2, 3, and 5 from deep analysis

## Improvement 1: Add retry cycle to `evaluatePostSubmit()`

**Problem:** `evaluatePostSubmit()` returns "unsure" after a single DOM + OCR check. It never re-submits and re-checks (Step 8 from your spec). Only `runStandardLoginDetection()` has the retry.

**Fix:**

- Add the Step 8 retry cycle to `evaluatePostSubmit()` — after the first DOM scan and OCR scan both miss "incorrect", perform exactly ONE full retry:
  - Wait 3.5s again for DOM to settle
  - Re-scan DOM for "incorrect"
  - If still not found, re-run OCR verification
  - Only return `.unsure` after this complete second cycle fails
- Accept the `session` parameter (already there) to re-capture content after the retry wait
- Mark `retryPerformed: true` in the result when the retry path is taken

---

## Improvement 2: Implement "incorrect" count-based categorization

**Problem:** The helper methods `categorizeByIncorrectCount`, `shouldRequeue`, and `isFinalNoAccount` exist but are never called. Every "incorrect" detection immediately returns `.noAcc` — no counting, no 1incorrect/2incorrect differentiation.

**Fix:**

- Update `categorizeByIncorrectCount` to return proper graduated statuses:
  - 0 completed incorrect cycles → `.unsure`
  - 1 → `.noAcc` (but flagged as `1incorrect` in the reason, eligible for requeue)
  - 2 → `.noAcc` (flagged as `2incorrect`, eligible for requeue)
  - 3+ → `.noAcc` (final — `isFinalNoAccount` confirmed)
- Update the callers in `evaluateStrict()` and `evaluatePostSubmit()` so that when "incorrect" is detected, they return the result with the phase/reason containing the count info (e.g. "1incorrect", "2incorrect", "3+incorrect_final")
- The count itself is tracked by the caller (DualFindViewModel / DualSiteWorkerService), so add a `detectedIncorrect: Bool` field to `DetectionResult` that callers use to increment their per-account counter
- The callers then use `shouldRequeue()` and `isFinalNoAccount()` to decide whether to retry or finalize

---

## Improvement 3: Settlement Gate URL redirect validation

**Problem:** In the settlement gate, any URL change away from `/login` is immediately treated as "settled successfully." Redirects to CAPTCHA pages, error pages, or password reset pages are falsely classified as settled.

**Fix:**

- After detecting a URL redirect away from login, add a verification step before returning success:
  - Check the new URL against known **bad** destination patterns: `captcha`, `challenge`, `verify`, `reset`, `error`, `403`, `blocked`, `maintenance`, `unavailable`
  - If the new URL matches a bad pattern, don't treat it as successfully settled — continue polling instead
  - Check for known **good** destination patterns: `lobby`, `home`, `dashboard`, `account`, `my-`, `welcome`, `deposit`
  - If good pattern matched → settled (as before)
  - If neither good nor bad → still treat as settled (preserves current behavior for unknown redirects) but log a warning
- This prevents CAPTCHA/error page redirects from being falsely classified as login success

---

## Improvement 5: Lazy AI service initialization with feature gating

**Problem:** 12+ AI services are initialized as stored properties on `LoginAutomationEngine`. All of them fire their recording/analysis callbacks after every single login test — even when those features aren't needed or enabled.

**Fix:**

- Convert the AI service stored properties from eager `let` declarations to lazy computed access:
  - `aiProxyStrategy`, `aiChallengeSolver`, `aiURLOptimizer`, `aiFingerprintTuning`, `aiSessionHealth`, `aiCredentialPriority`, `aiAntiDetection`, `customTools`, `aiInteractionGraph` — all become accessed only when actually needed
- Gate the post-outcome AI telemetry block (lines ~226-368) behind a single check:
  - Add an `aiTelemetryEnabled` property to `AutomationSettings` (default: `true`)
  - Wrap the entire AI recording section in `guard automationSettings.aiTelemetryEnabled else { return }` style check
  - The `aiSessionHealth.predictHealth()` pre-check at session start remains ungated (it's a critical safety check)
- This reduces per-test latency and memory overhead when AI telemetry is not needed
- Add a toggle in settings views for "AI Telemetry" so users can disable the overhead

