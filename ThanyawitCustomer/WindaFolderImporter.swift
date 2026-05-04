import Foundation

struct WindaFolderImporter {
    struct ImportResult: Hashable {
        var weightSlips: [WeightSlipRecord]
        var codLookups: [String: String]
    }
    struct AprilWDATAResult: Hashable {
        var sourceMonth: String
        var records: [WeightSlipRecord]
        var groupedByCustomerCompany: [String: [WeightSlipRecord]]
        var netTonTotal: Double
    }
    let defaultSourceMonth = "2569-04"

    func importFiles(from folderURL: URL) throws -> ImportResult {
        let files = try collectCandidateFiles(in: folderURL)
        var slips: [WeightSlipRecord] = []
        var cod: [String: String] = [:]

        for url in files {
            let rawText = try readText(from: url)
            let upper = url.lastPathComponent.uppercased()
            if upper.hasPrefix("COD") {
                cod.merge(parseCODLookup(from: rawText)) { current, _ in current }
                continue
            }
            if upper.hasPrefix("TRK") || upper.hasPrefix("TICKET") {
                slips.append(parseWeightSlip(from: rawText, fileURL: url))
            }
        }

        return ImportResult(weightSlips: slips, codLookups: cod)
    }

    func importApril2026WDATA(from folderURL: URL) throws -> AprilWDATAResult {
        let primary = folderURL.appendingPathComponent("WDATA_NORMALIZED_WITH_STATUS.csv")
        let fallback = folderURL.appendingPathComponent("WDATA_2569_LOCAL_DEFAULT.csv")
        let csvURL = FileManager.default.fileExists(atPath: primary.path) ? primary : fallback
        let csvText = try readText(from: csvURL)
        let rows = parseCSV(csvText)
        guard let header = rows.first else {
            return AprilWDATAResult(sourceMonth: defaultSourceMonth, records: [], groupedByCustomerCompany: [:], netTonTotal: 0)
        }
        let map = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1.lowercased(), $0) })
        let records = rows.dropFirst().compactMap { row -> WeightSlipRecord? in
            guard csvCell("source_month", row, map) == defaultSourceMonth else { return nil }
            let gross = csvDoubleAny(["w1", "gross_kg"], row, map)
            let tare = csvDoubleAny(["w2", "tare_kg"], row, map)
            let netFromFile = csvDoubleAny(["net_weight_kg", "net_kg"], row, map)
            let net = netFromFile ?? (gross != nil && tare != nil ? abs((gross ?? 0) - (tare ?? 0)) : nil)
            let confidence: Double = {
                if netFromFile != nil { return 1.0 }
                if gross != nil && tare != nil { return 0.9 }
                if net != nil || gross != nil || tare != nil { return 0.6 }
                return 0.3
            }()
            return WeightSlipRecord(
                id: csvCellAny(["record_id", "id"], row, map).isEmpty ? UUID().uuidString : csvCellAny(["record_id", "id"], row, map),
                customerCode: csvCellAny(["customer_code"], row, map),
                customerName: csvCellAny(["company_name", "customer_name"], row, map),
                companyCode: csvCellAny(["company_code"], row, map),
                productCode: csvCellAny(["product_code"], row, map),
                productName: csvCellAny(["product_name"], row, map),
                ticketNo: csvCellAny(["ticket1", "ticket2", "ticket_no"], row, map),
                truckPlate: csvCellAny(["truck", "truck_plate"], row, map),
                dateIn: csvCellAny(["dayin", "date_in"], row, map),
                timeIn: csvCellAny(["tmin", "time_in"], row, map),
                grossKg: gross,
                dateOut: csvCellAny(["dayout", "date_out"], row, map),
                timeOut: csvCellAny(["tmout", "time_out"], row, map),
                tareKg: tare,
                netKg: net,
                netTon: net.map { $0 / 1000 },
                sourceType: "Winda",
                sourceFileName: csvURL.lastPathComponent,
                sourceFilePath: csvURL.path,
                sourceRawText: row.joined(separator: ","),
                evidenceImagePath: "",
                signatureImagePath: "",
                parserConfidence: confidence,
                parserNote: netFromFile != nil ? "WDATA April 2026 (net from file)" : (gross != nil && tare != nil ? "WDATA April 2026 (net from w1/w2)" : "WDATA April 2026 (partial)"),
                isReviewed: false,
                reviewedAt: "",
                reviewerNote: ""
            )
        }
        let grouped = Dictionary(grouping: records) { "\($0.customerCode)|\($0.companyCode)|\(defaultSourceMonth)" }
        let sum = records.reduce(0) { $0 + ($1.netTon ?? 0) }
        return AprilWDATAResult(sourceMonth: defaultSourceMonth, records: records, groupedByCustomerCompany: grouped, netTonTotal: sum)
    }

    func collectCandidateFiles(in folderURL: URL) throws -> [URL] {
        let allFiles = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        return allFiles.filter { url in
            guard url.pathExtension.lowercased() == "txt" else { return false }
            let upper = url.lastPathComponent.uppercased()
            return upper.hasPrefix("TRK") || upper.hasPrefix("TICKET") || upper.hasPrefix("COD")
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func parseWeightSlip(from text: String, fileURL: URL) -> WeightSlipRecord {
        let gross = extractKg(for: ["GROSS", "น้ำหนักเข้า", "หนักเข้า"], in: text)
        let tare = extractKg(for: ["TARE", "น้ำหนักออก", "หนักออก", "รถเปล่า"], in: text)
        let explicitNet = extractKg(for: ["NET", "สุทธิ", "น้ำหนักจริง"], in: text)

        let computedNet: Double?
        if let gross, let tare {
            computedNet = max(gross - tare, 0)
        } else {
            computedNet = explicitNet
        }

        let netTon = computedNet.map { $0 / 1000 }
        let ticketNo = extractField(for: ["TICKET", "เลขที่", "เลขใบชั่ง"], in: text)
        let truckPlate = extractField(for: ["ทะเบียน", "TRUCK", "PLATE"], in: text)
        let customerCode = extractField(for: ["CUSTOMER CODE", "CUSCODE", "รหัสลูกค้า"], in: text)
        let customerName = extractField(for: ["CUSTOMER", "ลูกค้า"], in: text)
        let companyCode = extractField(for: ["COMPANY CODE", "รหัสบริษัท"], in: text)
        let productCode = extractField(for: ["PRODUCT CODE", "รหัสสินค้า"], in: text)
        let productName = extractField(for: ["PRODUCT", "สินค้า"], in: text)
        let dateIn = extractField(for: ["DATE IN", "วันที่เข้า", "วันที่"], in: text)
        let timeIn = extractField(for: ["TIME IN", "เวลาเข้า"], in: text)
        let dateOut = extractField(for: ["DATE OUT", "วันที่ออก"], in: text)
        let timeOut = extractField(for: ["TIME OUT", "เวลาออก"], in: text)

        let confidence = confidenceScore(gross: gross, tare: tare, net: computedNet, ticketNo: ticketNo)
        let note = parserNote(gross: gross, tare: tare, explicitNet: explicitNet, computedNet: computedNet)

        return WeightSlipRecord(
            id: UUID().uuidString,
            customerCode: customerCode,
            customerName: customerName,
            companyCode: companyCode,
            productCode: productCode,
            productName: productName,
            ticketNo: ticketNo,
            truckPlate: truckPlate,
            dateIn: dateIn,
            timeIn: timeIn,
            grossKg: gross,
            dateOut: dateOut,
            timeOut: timeOut,
            tareKg: tare,
            netKg: computedNet,
            netTon: netTon,
            sourceType: "Winda",
            sourceFileName: fileURL.lastPathComponent,
            sourceFilePath: fileURL.path,
            sourceRawText: text,
            evidenceImagePath: "",
            signatureImagePath: "",
            parserConfidence: confidence,
            parserNote: note,
            isReviewed: false,
            reviewedAt: "",
            reviewerNote: ""
        )
    }

    private func parseCODLookup(from text: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = text.components(separatedBy: .newlines)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            let parts = line.split(separator: "|", omittingEmptySubsequences: false)
            if parts.count >= 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty, !value.isEmpty { result[key] = value }
            }
        }
        return result
    }

    private func readText(from url: URL) throws -> String {
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        if let text = try? String(contentsOf: url, encoding: .windowsCP874) {
            return text
        }
        return try String(contentsOf: url, encoding: .ascii)
    }

    private func extractKg(for keywords: [String], in text: String) -> Double? {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let upper = line.uppercased()
            guard keywords.contains(where: { upper.contains($0.uppercased()) }) else { continue }
            if let value = extractWeightNumber(in: line) {
                return value
            }
        }
        return nil
    }

    private func extractField(for keywords: [String], in text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let upper = line.uppercased()
            guard keywords.contains(where: { upper.contains($0.uppercased()) }) else { continue }
            if let range = line.range(of: ":") {
                return String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if tokens.count > 1 {
                return tokens.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    private func extractWeightNumber(in text: String) -> Double? {
        let pattern = #"([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]+)?|[0-9]+(?:\.[0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)

        for match in matches.reversed() {
            guard let range = Range(match.range(at: 1), in: text) else { continue }
            let raw = String(text[range]).replacingOccurrences(of: ",", with: "")
            guard let value = Double(raw) else { continue }
            if value >= 1000 {
                return value
            }
        }
        return nil
    }

    private func confidenceScore(gross: Double?, tare: Double?, net: Double?, ticketNo: String) -> Double {
        var score = 0.2
        if !ticketNo.isEmpty { score += 0.2 }
        if gross != nil { score += 0.2 }
        if tare != nil { score += 0.2 }
        if net != nil { score += 0.2 }
        return min(score, 1)
    }

    private func parserNote(gross: Double?, tare: Double?, explicitNet: Double?, computedNet: Double?) -> String {
        if gross != nil && tare != nil {
            return "คำนวณ netKg จาก grossKg - tareKg"
        }
        if explicitNet != nil {
            return "พบค่า netKg จากบรรทัดน้ำหนักสุทธิ"
        }
        if computedNet == nil {
            return "ไม่พบ gross/tare/net ที่ชัดเจน"
        }
        return "Parsed"
    }

    private func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if inQuotes && i + 1 < chars.count && chars[i + 1] == "\"" {
                    field.append("\"")
                    i += 1
                } else {
                    inQuotes.toggle()
                }
            } else if c == "," && !inQuotes {
                row.append(field)
                field = ""
            } else if (c == "\n" || c == "\r") && !inQuotes {
                if c == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" { i += 1 }
                row.append(field)
                field = ""
                if !row.isEmpty && row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    rows.append(row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                }
                row = []
            } else {
                field.append(c)
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        }
        return rows
    }

    private func csvCell(_ key: String, _ row: [String], _ map: [String: Int]) -> String {
        guard let idx = map[key], row.indices.contains(idx) else { return "" }
        return row[idx]
    }

    private func csvDouble(_ key: String, _ row: [String], _ map: [String: Int]) -> Double? {
        let raw = csvCell(key, row, map).replacingOccurrences(of: ",", with: "")
        return Double(raw)
    }

    private func csvCellAny(_ keys: [String], _ row: [String], _ map: [String: Int]) -> String {
        for key in keys {
            let value = csvCell(key, row, map)
            if !value.isEmpty { return value }
        }
        return ""
    }

    private func csvDoubleAny(_ keys: [String], _ row: [String], _ map: [String: Int]) -> Double? {
        for key in keys {
            if let value = csvDouble(key, row, map) { return value }
        }
        return nil
    }
}

struct CustomerMasterImporter {
    func importCSV(from fileURL: URL) throws -> [CustomerMasterRecord] {
        let text = try readText(from: fileURL)
        let rows = parseCSV(text)
        guard let header = rows.first else { return [] }
        let map = Dictionary(uniqueKeysWithValues: header.enumerated().map { (normalizeHeader($1), $0) })
        return rows.dropFirst().compactMap { row in
            let customerCode = csvCellAny(["customer_code", "customercode", "custcode", "รหัสลูกค้า"], row, map)
            let companyCode = csvCellAny(["company_code", "companycode", "code_company", "รหัสบริษัท"], row, map)
            if customerCode.isEmpty && companyCode.isEmpty { return nil }
            return CustomerMasterRecord(
                customerCode: customerCode,
                companyCode: companyCode,
                customerName: csvCellAny(["customer_name", "company_name", "customername", "companyname", "ชื่อลูกค้า"], row, map),
                agencyName: csvCellAny(["agency_name", "agencyname", "หน่วยงาน"], row, map),
                districtName: csvCellAny(["district_name", "districtname", "อำเภอ"], row, map),
                customerGroup: csvCellAny(["customer_group", "customergroup", "กลุ่มลูกค้า"], row, map),
                billingName: csvCellAny(["billing_name", "billingname", "ชื่อออกบิล"], row, map),
                sourceFileName: fileURL.lastPathComponent,
                sourceRawText: row.joined(separator: ",")
            )
        }
    }

    private func readText(from url: URL) throws -> String {
        if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
        if let text = try? String(contentsOf: url, encoding: .windowsCP874) { return text }
        return try String(contentsOf: url, encoding: .ascii)
    }

    private func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        for c in text {
            if c == "\"" { inQuotes.toggle(); continue }
            if c == "," && !inQuotes { row.append(field); field = ""; continue }
            if (c == "\n" || c == "\r") && !inQuotes {
                if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row); row = []; field = "" }
                continue
            }
            field.append(c)
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows.map { $0.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
    }

    private func csvCell(_ key: String, _ row: [String], _ map: [String: Int]) -> String {
        guard let idx = map[normalizeHeader(key)], row.indices.contains(idx) else { return "" }
        return row[idx]
    }

    private func csvCellAny(_ keys: [String], _ row: [String], _ map: [String: Int]) -> String {
        for key in keys {
            let value = csvCell(key, row, map)
            if !value.isEmpty { return value }
        }
        return ""
    }

    private func normalizeHeader(_ text: String) -> String {
        text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
}

struct WeightSlipMatcher {
    func match(_ slips: [WeightSlipRecord], with masters: [CustomerMasterRecord]) -> [WeightSlipRecord] {
        let byCompany = Dictionary(uniqueKeysWithValues: masters.filter { !$0.companyCode.isEmpty }.map { ($0.companyCode, $0) })
        let byCustomer = Dictionary(uniqueKeysWithValues: masters.filter { !$0.customerCode.isEmpty }.map { ($0.customerCode, $0) })

        return slips.map { slip in
            var out = slip
            let master = (!slip.companyCode.isEmpty ? byCompany[slip.companyCode] : nil) ?? (!slip.customerCode.isEmpty ? byCustomer[slip.customerCode] : nil)
            guard let master else {
                out.matchStatus = "unmatched"
                out.conflictReason = "ไม่พบ master จาก companyCode/customerCode"
                return out
            }

            out.matchedCustomerCode = master.customerCode
            out.matchedCustomerName = master.customerName.isEmpty ? master.agencyName : master.customerName
            if out.customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                out.customerName = out.matchedCustomerName
            }
            if !out.customerName.isEmpty, !out.matchedCustomerName.isEmpty, out.customerName != out.matchedCustomerName {
                out.matchStatus = "warning"
                out.conflictReason = "รหัสตรงกันแต่ชื่อลูกค้าไม่ตรง (ยึดรหัส)"
            } else {
                out.matchStatus = "matched"
                out.conflictReason = ""
            }
            out.isReviewed = false
            return out
        }
    }
}
