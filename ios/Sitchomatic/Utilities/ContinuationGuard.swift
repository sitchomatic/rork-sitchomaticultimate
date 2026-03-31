import Foundation

/// Thread-safe continuation guard using Swift 6 concurrency primitives
actor ContinuationGuard {
    private var consumed = false

    init() {
        consumed = false
    }

    func tryConsume() -> Bool {
        if consumed { return false }
        consumed = true
        return true
    }

    func isConsumed() -> Bool {
        consumed
    }

    func reset() {
        consumed = false
    }
}
