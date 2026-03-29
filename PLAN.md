# Make Direct the default network mode

## Change

Set the default network connection mode to **Direct** instead of WireGuard across all targets.

This affects:
- The initial default when no saved preference exists (fresh install / first launch)
- The fallback when no persisted mode is found
- All three target defaults (Joe, Ignition, PPSR) and the unified mode

Users who already have a saved preference will **not** be affected — their persisted choice loads on startup as before.

---

## Top 5 Suggested Improvements (for your review)

Based on deep logical analysis of the entire codebase:

### 1. 🔴 Post-submit evaluation skips the retry cycle
The `evaluatePostSubmit` method returns "unsure" after a single DOM+OCR check. It never re-submits and re-checks (Step 8 from your spec). Only `runStandardLoginDetection` has the retry. This means some code paths get premature "unsure" results.

### 2. 🔴 "Incorrect" count-based categorization missing
Your spec defines 1incorrect / 2incorrect / noAcc(3+) statuses based on how many times "incorrect" is detected across cycles. The current code returns `noAcc` immediately on the **first** detection — no counting at all.

### 3. 🟡 Settlement Gate URL redirect is too aggressive
Any URL change away from `/login` is treated as "page settled successfully". Redirects to CAPTCHA, error, or password-reset pages are falsely classified as settled. The gate should verify the destination is a genuine success page.

### 4. 🟡 `performLoginTest` is a 400+ line monolith
Page loading, challenge handling, calibration, pattern cycling, evaluation, and AI telemetry are all jammed into one method. Splitting into phases would make debugging and future changes much safer.

### 5. 🟢 12+ AI services initialized per login regardless of need
Every login session calls into all AI services (anti-detection, fingerprint tuning, credential priority, interaction graph, etc.) even when those features are off. Lazy initialization or feature-gating would reduce per-test overhead.
