import Foundation

/// Swift 6.2 optimized log entry with frozen enum and performance attributes
struct PPSRLogEntry: Identifiable, Sendable, Codable {
    let id: UUID
    let timestamp: Date
    let message: String
    let level: Level

    @frozen
    enum Level: String, Sendable, Codable {
        case info = "INFO"
        case success = "OK"
        case warning = "WARN"
        case error = "ERR"
    }

    init(message: String, level: Level = .info) {
        self.id = UUID()
        self.timestamp = Date()
        self.message = message
        self.level = level
    }

    @inline(__always)
    var formattedTime: String {
        DateFormatters.timeWithMillis.string(from: timestamp)
    }
}
