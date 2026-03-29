# Refactor performLoginTest into separate phase methods

## What changes

Break the ~685-line `performLoginTest` method into **6 clearly named phase methods**, each handling one logical step of the login test flow. The main method becomes a short orchestrator that calls each phase in sequence and handles early returns.

### Phase methods

1. `**phaseLoadPage**` — Handles 3 page load retries, crash recovery, and blank page detection. Returns the loaded state or a failure outcome.
2. `**phaseHandleChallenges**` — Runs the challenge classifier and executes the AI-recommended bypass strategy (abort, waitAndRetry, rotateProxy, rotateFingerprint, fullSessionReset, etc.). Returns whether to continue or abort.
3. `**phaseValidatePageReadiness**` — Injects settlement monitor, waits for full page readiness, dismisses cookie notices, verifies login fields exist, checks for dead sessions and interactive elements. Returns success or a failure outcome.
4. `**phaseCalibrate**` — Runs auto-calibration or Vision ML calibration if no saved calibration exists. Returns the calibration result.
5. `**phasePatternCycleLoop**` — The main login attempt loop: pattern selection, field filling, submit strategies (debug button replay → calibrated → legacy → OCR → Vision ML), response polling, page evaluation, screenshot capture. Returns the final outcome from all cycles.
6. `**phaseResolveFinalOutcome**` — Takes the last evaluation result and final outcome from the loop and maps it to the correct return value with appropriate logging.

### The refactored `performLoginTest` becomes:

A ~40-line orchestrator that:

- Calls `phaseLoadPage` → early return on failure
- Calls `phaseHandleChallenges` → early return on abort
- Calls `phaseValidatePageReadiness` → early return on failure
- Calls `phaseCalibrate` → gets calibration
- Calls `phasePatternCycleLoop` → gets outcome
- Returns `phaseResolveFinalOutcome`

### What stays the same

- **Zero logic changes** — every line of existing logic is preserved exactly as-is, just moved into the appropriate phase method
- All existing helper methods (`retryFill`, `advanceTo`, `failAttempt`, `captureAlwaysScreenshot`, etc.) remain untouched
- All callbacks, logging, and replay logger calls remain in place
- The `runLoginTest` wrapper method is not modified
- All other files in the project are untouched

### Benefits

- Each phase is independently readable and debuggable
- Future changes to one phase (e.g. adding a new challenge handler) won't risk breaking others
- Error sources are immediately identifiable by which phase method they originate from
- Xcode jump-to-definition and call hierarchy work much better with smaller methods

