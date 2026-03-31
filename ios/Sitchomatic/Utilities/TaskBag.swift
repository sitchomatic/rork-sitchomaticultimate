import Foundation

/// A keyed collection of managed tasks with automatic cancellation on replacement and cleanup.
/// Generic over key type for type-safe task management.
@MainActor
final class TaskBag<Key: Hashable & Sendable> {
    private var tasks: [Key: Task<Void, Never>] = [:]

    @inlinable
    func add(_ key: Key, _ task: Task<Void, Never>) {
        tasks[key]?.cancel()
        tasks[key] = task
    }

    @inlinable
    func cancel(_ key: Key) {
        tasks[key]?.cancel()
        tasks[key] = nil
    }

    func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
    }

    var activeKeys: [Key] {
        Array(tasks.keys)
    }

    @inlinable
    var count: Int { tasks.count }

    @inlinable
    var isEmpty: Bool { tasks.isEmpty }

    deinit {
        for task in tasks.values {
            task.cancel()
        }
    }
}

/// Backward-compatible String-keyed TaskBag type alias.
typealias StringTaskBag = TaskBag<String>
