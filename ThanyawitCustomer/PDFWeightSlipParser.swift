import Foundation

/// Parses OCR/PDF text from Thai weight slips and extracts structured weight data.
///
/// The parser is intentionally dependency-free so it can be reused by OCR image imports,
/// PDF imports, and future automated tests.
struct PDFWeightSlipParser {
    struct ParsedSlip: Hashable {
        var grossTon: Double?
        var tareTon: Double?
        var netTon: Double?
        var ticketNo: String?
        var timeIn: String?
        var timeOut: String?
        var sourceLine: String?
        var confidence: Double

        var bestBillingWeightTon: Double {
            netTon ?? calculatedNetTon ?? 0
        }

        var calculatedNetTon: Double? {
            guard let grossTon, let tareTon, grossTon >= tareTon else { return nil }
            return grossTon - tareTon
        }

        var note: String {
            var parts: [String] = []
            if let grossTon { parts.append("gross=\(PDFWeightSlipParser.formatTon(grossTon))") }
            if let tareTon { parts.append("tare=\(PDFWeightSlipParser.formatTon(tareTon))") }
            if let netTon { parts.append("net=\(PDFWeightSlipParser.formatTon(netTon))") }
            if let ticketNo { parts.append("ticket=\(ticketNo)") }
            if let timeIn { parts.append("in=\(timeIn)") }
            if let timeOut { parts.append("out=\(timeOut)") }
            return parts.isEmpty ? "ไม่พบค่าน้ำหนัก" : parts.joined(separator: " · ")
        }
    }

    struct ParsedRow: Hashable {
        var rawLine: String
        var numbers: [Double]
        var grossTon: Double?
        var tareTon: Double?
        var netTon: Double?
        var score: Double
    }

    static func parse(_ rawText: String) -> ParsedSlip {
        let normalized = normalize(rawText)
        let lines = normalized
            .components(separatedBy: .newlines)
            .map { cleanupLine($0) }
            .filter { !$0.isEmpty }

        let rows = lines.map(parseRow).filter { !$0.numbers.isEmpty }
        let bestRow = rows.max { $0.score < $1.score }
        let labelled = parseLabelledWeights(from: lines)

        var slip = ParsedSlip(
            grossTon: labelled.grossTon ?? bestRow?.grossTon,
            tareTon: labelled.tareTon ?? bestRow?.tareTon,
            netTon: labelled.netTon ?? bestRow?.netTon,
            ticketNo: parseTicketNo(from: lines),
            timeIn: parseTime(from: lines, keywords: ["เวลาเข้า", "เข้า", "time in", "in"]),
            timeOut: parseTime(from: lines, keywords: ["เวลาออก", "ออก", "time out", "out"]),
            sourceLine: bestRow?.rawLine,
            confidence: bestRow?.score ?? 0
        )

        if slip.netTon == nil, let calculated = slip.calculatedNetTon, calculated > 0 {
            slip.netTon = calculated
            slip.confidence += 0.15
        }

        if slip.bestBillingWeightTon > 0 {
            slip.confidence += 0.20
        }
        if slip.grossTon != nil && slip.tareTon != nil && slip.netTon != nil {
            slip.confidence += 0.20
        }
        if slip.ticketNo != nil { slip.confidence += 0.05 }
        if slip.timeIn != nil || slip.timeOut != nil { slip.confidence += 0.05 }
        slip.confidence = min(1.0, max(0.0, slip.confidence))
        return slip
    }

    static func parseRows(_ rawText: String) -> [ParsedRow] {
        normalize(rawText)
            .components(separatedBy: .newlines)
            .map { cleanupLine($0) }
            .filter { !$0.isEmpty }
            .map(parseRow)
            .filter { !$0.numbers.isEmpty }
            .sorted { $0.score > $1.score }
    }

    private static func parseRow(_ line: String) -> ParsedRow {
        let lower = line.lowercased()
        let values = extractNumbers(from: line).map(normalizeWeightToTon)
        var score = 0.0

        if containsAny(lower, ["gross", "น้ำหนักรวม", "นน.รวม", "ชั่งเข้า"]) { score += 0.20 }
        if containsAny(lower, ["tare", "น้ำหนักรถ", "นน.รถ", "ชั่งออก"]) { score += 0.20 }
        if containsAny(lower, ["net", "สุทธิ", "น้ำหนักสุทธิ", "นน.สุทธิ"]) { score += 0.30 }
        if lower.contains("kg") || lower.contains("กก") || lower.contains("ตัน") || lower.contains("ton") { score += 0.10 }
        if values.count >= 3 { score += 0.25 }
        if values.count == 2 { score += 0.10 }

        var gross: Double?
        var tare: Double?
        var net: Double?

        if values.count >= 3 {
            let sorted = values.sorted(by: >)
            gross = sorted[0]
            tare = sorted[1]
            let candidateNet = sorted.dropFirst(2).first ?? sorted[0] - sorted[1]
            net = abs((sorted[0] - sorted[1]) - candidateNet) <= max(0.05, candidateNet * 0.05)
                ? candidateNet
                : sorted[0] - sorted[1]
            score += 0.20
        } else if values.count == 2 {
            gross = values.max()
            tare = values.min()
            if let gross, let tare, gross > tare {
                net = gross - tare
                score += 0.10
            }
        } else if values.count == 1 {
            let value = values[0]
            if containsAny(lower, ["net", "สุทธิ", "น้ำหนักสุทธิ", "นน.สุทธิ"]) {
                net = value
                score += 0.15
            } else if containsAny(lower, ["gross", "น้ำหนักรวม", "นน.รวม", "ชั่งเข้า"]) {
                gross = value
            } else if containsAny(lower, ["tare", "น้ำหนักรถ", "นน.รถ", "ชั่งออก"]) {
                tare = value
            }
        }

        if let net, net > 0, net < 200 { score += 0.15 }
        if let gross, gross > 0, gross < 200 { score += 0.05 }
        if let tare, tare > 0, tare < 200 { score += 0.05 }

        return ParsedRow(rawLine: line, numbers: values, grossTon: gross, tareTon: tare, netTon: net, score: min(score, 1.0))
    }

    private static func parseLabelledWeights(from lines: [String]) -> (grossTon: Double?, tareTon: Double?, netTon: Double?) {
        var gross: Double?
        var tare: Double?
        var net: Double?

        for line in lines {
            let lower = line.lowercased()
            let values = extractNumbers(from: line).map(normalizeWeightToTon)
            guard let first = values.first else { continue }

            if gross == nil, containsAny(lower, ["gross", "น้ำหนักรวม", "นน.รวม", "ชั่งเข้า"]) {
                gross = first
            }
            if tare == nil, containsAny(lower, ["tare", "น้ำหนักรถ", "นน.รถ", "ชั่งออก"]) {
                tare = first
            }
            if net == nil, containsAny(lower, ["net", "สุทธิ", "น้ำหนักสุทธิ", "นน.สุทธิ"]) {
                net = first
            }
        }

        return (gross, tare, net)
    }

    private static func parseTicketNo(from lines: [String]) -> String? {
        let keywords = ["เลขที่", "เลขใบชั่ง", "ticket", "no.", "no", "เลข"]
        for line in lines {
            let lower = line.lowercased()
            guard containsAny(lower, keywords) else { continue }
            let tokens = line
                .replacingOccurrences(of: ":", with: " ")
                .replacingOccurrences(of: "#", with: " ")
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init)
            if let token = tokens.last(where: { $0.rangeOfCharacter(from: .decimalDigits) != nil }) {
                return token.trimmingCharacters(in: .punctuationCharacters)
            }
        }
        return nil
    }

    private static func parseTime(from lines: [String], keywords: [String]) -> String? {
        for line in lines {
            let lower = line.lowercased()
            guard containsAny(lower, keywords) else { continue }
            if let match = firstMatch(in: line, pattern: #"\b([0-2]?\d)[:.]([0-5]\d)\b"#) {
                return match.replacingOccurrences(of: ".", with: ":")
            }
        }

        for line in lines {
            if let match = firstMatch(in: line, pattern: #"\b([0-2]?\d)[:.]([0-5]\d)\b"#) {
                return match.replacingOccurrences(of: ".", with: ":")
            }
        }
        return nil
    }

    private static func extractNumbers(from text: String) -> [Double] {
        let pattern = #"(?<![A-Za-z0-9])\d{1,3}(?:,\d{3})*(?:\.\d+)?|(?<![A-Za-z0-9])\d+(?:\.\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            return Double(text[swiftRange].replacingOccurrences(of: ",", with: ""))
        }
    }

    private static func normalizeWeightToTon(_ value: Double) -> Double {
        // Most Thai scale slips show kilograms as 5-6 digit values. Convert kg to tons.
        if value >= 1000 { return value / 1000.0 }
        return value
    }

    private static func normalize(_ text: String) -> String {
        var output = text
        let thaiDigits = ["๐": "0", "๑": "1", "๒": "2", "๓": "3", "๔": "4", "๕": "5", "๖": "6", "๗": "7", "๘": "8", "๙": "9"]
        for (thai, arabic) in thaiDigits {
            output = output.replacingOccurrences(of: thai, with: arabic)
        }
        return output
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
    }

    private static func cleanupLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: "|", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let swiftRange = Range(match.range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    private static func formatTon(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
