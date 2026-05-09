import Foundation

extension CustomerStore {
    func importWeightSlipRecords(_ records: [WeightSlipRecord]) -> (imported: Int, review: Int) {
        var imported = 0
        var review = 0
        var seenTickets = Set<String>()
        var existingTickets = Set(billing.values.map { normalizedKey($0.slipTicketNo) }.filter { !$0.isEmpty })

        for record in records {
            let normalizedTicket = normalizedKey(record.ticketNo)
            if normalizedTicket.isEmpty || seenTickets.contains(normalizedTicket) {
                review += 1
                continue
            }
            if existingTickets.contains(normalizedTicket) {
                review += 1
                continue
            }
            seenTickets.insert(normalizedTicket)

            guard let customer = matchedCustomer(for: record) else {
                review += 1
                continue
            }

            var line = billingLine(for: customer)
            guard record.totalWeight > 0 else {
                review += 1
                continue
            }

            line.weight = record.totalWeight
            line.slipTicketNo = record.ticketNo
            line.weightSlipSourceFilename = record.sourceFileName
            line.weightEvidenceNote = "Imported from WDATA/Scale export"
            updateBilling(line)
            existingTickets.insert(normalizedTicket)
            imported += 1
        }

        return (imported, review)
    }

    private func normalizedKey(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "th_TH"))
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matchedCustomer(for record: WeightSlipRecord) -> Customer? {
        let code = normalizedKey(record.customerCode)
        let name = normalizedKey(record.customerName)

        if !code.isEmpty, let exactCode = customers.first(where: { normalizedKey($0.customerCode) == code }) {
            return exactCode
        }
        if !name.isEmpty, let exactName = customers.first(where: { normalizedKey($0.agencyName) == name }) {
            return exactName
        }
        guard name.count >= 8, !isGenericThaiName(name) else { return nil }
        return customers.first(where: { customer in
            let agency = normalizedKey(customer.agencyName)
            guard agency.count >= 8, !isGenericThaiName(agency) else { return false }
            return agency.contains(name)
        })
    }

    private func isGenericThaiName(_ text: String) -> Bool {
        let genericTerms = ["เทศบาล", "อบต", "องค์การ", "สำนักงาน", "เทศบาลตำบล", "เทศบาลเมือง", "องค์การบริหารส่วนตำบล"]
        return genericTerms.contains { term in
            let normalizedTerm = normalizedKey(term)
            return text == normalizedTerm || text.contains(normalizedTerm)
        }
    }
}
