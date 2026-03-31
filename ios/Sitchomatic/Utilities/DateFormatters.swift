import Foundation

/// Pre-configured date formatters for consistent date/time formatting throughout the app.
/// Formatters are created once as static lets and never mutated after initialization.
/// `nonisolated(unsafe)` is used because `DateFormatter` is not `Sendable`, but these
/// instances are effectively immutable after the static initializer completes.
@MainActor
enum DateFormatters {
    nonisolated(unsafe) static let timeWithMillis: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    nonisolated(unsafe) static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    nonisolated(unsafe) static let mediumDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    nonisolated(unsafe) static let fullTimestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    nonisolated(unsafe) static let exportTimestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    nonisolated(unsafe) static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmm"
        return f
    }()
}
