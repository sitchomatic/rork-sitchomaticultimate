import Foundation
import ZIPFoundation

struct XLSXParserService: Sendable {
    static func parseToCSV(url: URL) -> String? {
        guard let archive = Archive(url: url, accessMode: .read) else { return nil }

        var sharedStrings: [String] = []
        if let ssEntry = archive["xl/sharedStrings.xml"] {
            var ssData = Data()
            try? archive.extract(ssEntry, consumer: { ssData.append($0) })
            sharedStrings = parseSharedStrings(from: ssData)
        }

        guard let sheetEntry = archive["xl/worksheets/sheet1.xml"] else { return nil }
        var sheetData = Data()
        try? archive.extract(sheetEntry, consumer: { sheetData.append($0) })

        let rows = parseWorksheet(from: sheetData, sharedStrings: sharedStrings)
        guard !rows.isEmpty else { return nil }

        let csv = rows.map { cells in
            cells.map { escapeCSVField($0) }.joined(separator: ",")
        }.joined(separator: "\n")

        return csv.isEmpty ? nil : csv
    }

    private static func parseSharedStrings(from data: Data) -> [String] {
        let parser = SharedStringsXMLParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        return parser.strings
    }

    private static func parseWorksheet(from data: Data, sharedStrings: [String]) -> [[String]] {
        let parser = WorksheetXMLParser(sharedStrings: sharedStrings)
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        return parser.rows
    }

    private static func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}

private final class SharedStringsXMLParser: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var inSI = false
    private var inT = false
    private var currentSIText = ""
    private var tBuffer = ""

    func parser(_ parser: XMLParser, didStartElement element: String,
                namespaceURI: String?, qualifiedName _: String?,
                attributes _: [String: String] = [:]) {
        switch element {
        case "si":
            inSI = true
            currentSIText = ""
        case "t":
            inT = true
            tBuffer = ""
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inT { tBuffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement element: String,
                namespaceURI _: String?, qualifiedName _: String?) {
        switch element {
        case "t":
            if inSI { currentSIText += tBuffer }
            inT = false
        case "si":
            strings.append(currentSIText)
            inSI = false
        default: break
        }
    }
}

private final class WorksheetXMLParser: NSObject, XMLParserDelegate {
    var rows: [[String]] = []
    private let sharedStrings: [String]
    private var currentRow: [String] = []
    private var cellType = ""
    private var valueBuffer = ""
    private var isTextBuffer = ""
    private var inValue = false
    private var inIS = false
    private var inT = false

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parser(_ parser: XMLParser, didStartElement element: String,
                namespaceURI: String?, qualifiedName _: String?,
                attributes: [String: String] = [:]) {
        switch element {
        case "row":
            currentRow = []
        case "c":
            cellType = attributes["t"] ?? ""
            valueBuffer = ""
            isTextBuffer = ""
        case "v":
            inValue = true
        case "is":
            inIS = true
        case "t":
            if inIS { inT = true }
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inValue { valueBuffer += string }
        if inT { isTextBuffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement element: String,
                namespaceURI _: String?, qualifiedName _: String?) {
        switch element {
        case "v":
            inValue = false
        case "t":
            inT = false
        case "is":
            inIS = false
        case "c":
            let cellValue: String
            switch cellType {
            case "s":
                if let idx = Int(valueBuffer), idx >= 0, idx < sharedStrings.count {
                    cellValue = sharedStrings[idx]
                } else {
                    cellValue = ""
                }
            case "inlineStr":
                cellValue = isTextBuffer
            default:
                cellValue = valueBuffer
            }
            currentRow.append(cellValue)
        case "row":
            if !currentRow.isEmpty {
                rows.append(currentRow)
            }
        default: break
        }
    }
}
