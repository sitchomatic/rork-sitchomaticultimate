import Foundation

/// Thread-safe continuation guard for single-resume continuations.
/// Uses an internal lock so callers can use it from @Sendable closures without `await`.
@unchecked Sendable
final class ContinuationGuard {
    private let lock = NSLock()
    private var consumed = false

    func tryConsume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !consumed else { return false }
        consumed = true
        return true
    }

    func isConsumed() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return consumed
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        consumed = false
    }
}
