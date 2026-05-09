import Foundation

#if canImport(CodableCSV)
import CodableCSV
#endif

#if !canImport(CodableCSV) && !DEBUG
#error("CodableCSV is required for non-DEBUG builds. Please add/link CodableCSV via Swift Package Manager.")
#endif

enum CodableCSVTableReader {
    static func parseRows(from text: String, delimiter: Character) -> [[String]] {
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        #if canImport(CodableCSV)
        do {
            var config = CSVReader.Configuration()
            config.headerStrategy = .none
            config.delimiters.field = delimiter
            config.delimiters.row = "\n"
            config.presample = false
            let reader = try CSVReader(input: normalizedText, configuration: config)
            return reader.readRows().map { $0.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
        } catch {
            assertionFailure("CodableCSV parse failed: \(error.localizedDescription)")
            print("⚠️ CodableCSV parse failed, fallback parser used: \(error.localizedDescription)")
            #if DEBUG
            return fallbackParseRows(from: normalizedText, delimiter: delimiter)
            #else
            return []
            #endif
        }
        #else
        return fallbackParseRows(from: normalizedText, delimiter: delimiter)
        #endif
    }

    private static func fallbackParseRows(from text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var current = ""
        var inQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let ch = text[index]
            if ch == "\"" {
                let next = text.index(after: index)
                if inQuotes && next < text.endIndex && text[next] == "\"" {
                    current.append("\"")
                    index = next
                } else {
                    inQuotes.toggle()
                }
            } else if ch == delimiter, !inQuotes {
                row.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else if ch == "\n", !inQuotes {
                row.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                if !row.allSatisfy({ $0.isEmpty }) {
                    rows.append(row)
                }
                row = []
                current = ""
            } else {
                current.append(ch)
            }
            index = text.index(after: index)
        }

        row.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        if !row.allSatisfy({ $0.isEmpty }) {
            rows.append(row)
        }
        return rows
    }
}
