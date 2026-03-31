# Fix ContinuationGuard actor isolation build error

**What's wrong:** The `ContinuationGuard` utility class is being treated as main-actor-only, but it's called from background threads (network callbacks). This causes build errors.

**Fix:** Mark `ContinuationGuard` as `nonisolated` so it can be used from any thread — which is exactly what it's designed for (it already has its own internal locking for thread safety).

**Change:** One word added to one file — `nonisolated` before the class declaration.