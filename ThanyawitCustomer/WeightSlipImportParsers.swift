import Foundation
#if canImport(CoreFoundation)
import CoreFoundation
#endif

struct WeightSlipRecord: Hashable {
    var sourceFileName: String
    var customerCode: String
    var customerName: String
    var ticketNo: String
    var totalWeight: Double
    var slipDateText: String = ""
}

enum WindaWDATAParser {
    static func parse(data: Data, sourceFileName: String) -> [WeightSlipRecord] {
        let text = decodeText(data) ?? ""
        return parse(text: text, sourceFileName: sourceFileName)
    }

    static func parse(text: String, sourceFileName: String) -> [WeightSlipRecord] {
        let rows = parseRawRecords(text: text, sourceFileName: sourceFileName)
        return rows.compactMap { makeWeightSlipRecord(from: $0) }
    }

    static func parseRawRecords(data: Data, sourceFileName: String) -> [WDATARecord] {
        let text = decodeText(data) ?? ""
        return parseRawRecords(text: text, sourceFileName: sourceFileName)
    }

    static func parseRawRecords(text: String, sourceFileName: String) -> [WDATARecord] {
        let rows = csvRows(from: text)
        guard let header = rows.first else { return [] }
        let field = mappedFieldIndex(header)

        return rows.dropFirst().enumerated().map { offset, columns in
            let code = value(at: field.customerCode, in: columns)
            let name = value(at: field.customerName, in: columns)
            let ticket = value(at: field.ticketNo, in: columns)
            let weightText = value(at: field.weight, in: columns)
            let date = value(at: field.date, in: columns)
            return WDATARecord(
                sourceFileName: sourceFileName,
                rowNumber: offset + 2,
                customerCode: code,
                customerName: name,
                ticketNo: ticket,
                netWeightText: weightText,
                dateText: date,
                rawFields: columns,
                normalizedTicketNo: normalizedKey(ticket),
                normalizedCustomerCode: normalizedKey(code)
            )
        }
    }

    static func makeWeightSlipRecord(from row: WDATARecord) -> WeightSlipRecord? {
        let weight = normalizedNumber(row.netWeightText)
        guard weight > 0, !(row.customerCode.isEmpty && row.customerName.isEmpty), !row.ticketNo.isEmpty else {
            return nil
        }
        return WeightSlipRecord(
            sourceFileName: row.sourceFileName,
            customerCode: row.customerCode,
            customerName: row.customerName,
            ticketNo: row.ticketNo,
            totalWeight: weight,
            slipDateText: normalizedDateText(row.dateText)
        )
    }

    private static func decodeText(_ data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        #if canImport(CoreFoundation)
        let cp874Encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosThai.rawValue))
        if let thai = String(data: data, encoding: String.Encoding(rawValue: cp874Encoding)) {
            return thai
        }
        let tis620Encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatinThai.rawValue))
        if let tis620 = String(data: data, encoding: String.Encoding(rawValue: tis620Encoding)) {
            return tis620
        }
        #endif
        return String(data: data, encoding: .windowsCP1252)
    }

    private static func csvRows(from text: String) -> [[String]] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let firstLine = normalized.components(separatedBy: "\n").first ?? ""
        let delimiter: Character = firstLine.contains("\t") ? "\t" : (firstLine.contains(";") ? ";" : ",")
        return CodableCSVTableReader.parseRows(from: normalized, delimiter: delimiter)
    }

    private static func normalizedHeader(_ text: String) -> String {
        let removedBOM = text.replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        let folded = removedBOM.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "th_TH"))
        return folded
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }

    private static func mappedFieldIndex(_ header: [String]) -> (customerCode: Int?, customerName: Int?, ticketNo: Int?, weight: Int?, date: Int?) {
        var code: Int?
        var name: Int?
        var ticket: Int?
        var weight: Int?
        var date: Int?

        for (index, raw) in header.enumerated() {
            let h = normalizedHeader(raw)
            if ["รหัสลูกค้า", "customercode", "customerid", "code"].contains(where: h.contains) { code = code ?? index }
            if ["ชื่อลูกค้า", "customername", "ลูกค้า", "หน่วยงาน"].contains(where: h.contains) { name = name ?? index }
            if ["เลขที่ใบชั่ง", "ticket", "slip", "billno", "ใบทชั่ง", "เลขที่"].contains(where: h.contains) { ticket = ticket ?? index }
            if ["น้ำหนักสุทธิ", "netweight", "totalweight", "weight", "น้ำหนักรวม"].contains(where: h.contains) { weight = weight ?? index }
            if ["date", "วันที่", "weighdate"].contains(where: h.contains) { date = date ?? index }
        }

        return (code, name, ticket, weight, date)
    }

    private static func value(at index: Int?, in row: [String]) -> String {
        guard let index, row.indices.contains(index) else { return "" }
        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedNumber(_ raw: String) -> Double {
        let cleaned = raw
            .lowercased()
            .replacingOccurrences(of: "kg", with: "")
            .replacingOccurrences(of: "กก.", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        return Double(cleaned) ?? 0
    }

    private static func normalizedKey(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "th_TH"))
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedDateText(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let formats = ["dd/MM/yyyy", "d/M/yyyy", "yyyy-MM-dd"]
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "th_TH")
        parser.timeZone = TimeZone(secondsFromGMT: 0)

        for format in formats {
            parser.dateFormat = format
            if let date = parser.date(from: trimmed) {
                let out = DateFormatter()
                out.locale = Locale(identifier: "en_US_POSIX")
                out.timeZone = TimeZone(secondsFromGMT: 0)
                out.dateFormat = "yyyy-MM-dd"
                return out.string(from: date)
            }
        }

        if trimmed.contains("/") {
            let parts = trimmed.split(separator: "/").map(String.init)
            if parts.count == 3, var year = Int(parts[2]), let day = Int(parts[0]), let month = Int(parts[1]) {
                if year > 2400 { year -= 543 }
                var comps = DateComponents()
                comps.year = year
                comps.month = month
                comps.day = day
                let calendar = Calendar(identifier: .gregorian)
                if let date = calendar.date(from: comps) {
                    let out = DateFormatter()
                    out.locale = Locale(identifier: "en_US_POSIX")
                    out.timeZone = TimeZone(secondsFromGMT: 0)
                    out.dateFormat = "yyyy-MM-dd"
                    return out.string(from: date)
                }
            }
        }
        return trimmed
    }
}

enum ScaleExportParser {
    static func parse(text: String, sourceFileName: String) -> [WeightSlipRecord] {
        let rows = CodableCSVTableReader.parseRows(from: text, delimiter: ";")
        return rows.compactMap { cols in
            guard cols.count >= 5 else { return nil }
            return WeightSlipRecord(
                sourceFileName: sourceFileName,
                customerCode: cols[0],
                customerName: cols[1],
                ticketNo: cols[2],
                totalWeight: Double(cols[4]) ?? 0
            )
        }
    }
}
