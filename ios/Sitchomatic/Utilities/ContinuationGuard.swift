import Foundation
import Synchronization

/// A thread-safe one-shot guard that prevents double-consumption of async continuations.
/// Uses Swift 6's `Mutex` for statically-verified thread safety and strict concurrency compliance.
nonisolated final class ContinuationGuard: Sendable {
    private let state = Mutex(false)

    @inlinable
    func tryConsume() -> Bool {
        state.withLock { consumed in
            guard !consumed else { return false }
            consumed = true
            return true
        }
    }
}
