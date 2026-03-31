import Foundation

enum AutomationSettingsTransfer {
    static func exportString(from settings: AutomationSettings) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(settings) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func importSettings(from text: String) -> AutomationSettings? {
        guard let data = text.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(AutomationSettings.self, from: data)
    }
}
