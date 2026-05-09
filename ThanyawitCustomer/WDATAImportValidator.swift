import Foundation

enum WDATAValidationState: Hashable {
    case pass
    case needsReview(String)
    case reject(String)
}

struct WDATAValidationOutcome: Hashable {
    var rawRecord: WDATARecord
    var state: WDATAValidationState
    var rowNumber: Int { rawRecord.rowNumber }
    var sourceFileName: String { rawRecord.sourceFileName }
}

enum WDATAImportValidator {
    static func validate(
        records: [WDATARecord],
        existingTickets: Set<String> = [],
        knownCustomerCodes: Set<String> = [],
        knownCustomerNames: Set<String> = [],
        knownVehiclePlates: Set<String> = [],
        billingPeriod: String? = nil
    ) -> [WDATAValidationOutcome] {
        var seenTickets = Set<String>()

        return records.map { record in
            let ticket = normalized(record.ticketNo)
            if ticket.isEmpty {
                return WDATAValidationOutcome(rawRecord: record, state: .reject("ticket number is empty"))
            }
            if seenTickets.contains(ticket) || existingTickets.contains(ticket) {
                return WDATAValidationOutcome(rawRecord: record, state: .needsReview("duplicate ticket number"))
            }
            seenTickets.insert(ticket)

            let weight = normalizedNumber(record.netWeightText)
            if weight <= 0 {
                return WDATAValidationOutcome(rawRecord: record, state: .reject("weight must be greater than zero"))
            }
            if weight > 200_000 {
                return WDATAValidationOutcome(rawRecord: record, state: .needsReview("weight is outside expected range"))
            }

            if !knownCustomerCodes.isEmpty, !record.customerCode.isEmpty,
               !knownCustomerCodes.contains(record.normalizedCustomerCode) {
                return WDATAValidationOutcome(rawRecord: record, state: .needsReview("customer code not found in master"))
            }
            let normalizedName = normalized(record.customerName)
            if !knownCustomerNames.isEmpty, !record.customerName.isEmpty,
               !knownCustomerNames.contains(normalizedName) {
                return WDATAValidationOutcome(rawRecord: record, state: .needsReview("customer name not found in master"))
            }
            if !record.customerCode.isEmpty, !record.customerName.isEmpty,
               !knownCustomerCodes.isEmpty, !knownCustomerNames.isEmpty,
               (!knownCustomerCodes.contains(record.normalizedCustomerCode) || !knownCustomerNames.contains(normalizedName)) {
                return WDATAValidationOutcome(rawRecord: record, state: .needsReview("customer code/name conflict"))
            }

            if !knownVehiclePlates.isEmpty, let plate = plateFromRawFields(record.rawFields) {
                if !isLikelyPlate(plate) {
                    return WDATAValidationOutcome(rawRecord: record, state: .needsReview("vehicle plate format is suspicious"))
                }
                if !knownVehiclePlates.contains(normalized(plate)) {
                    return WDATAValidationOutcome(rawRecord: record, state: .needsReview("vehicle plate not found in master"))
                }
            }

            if let billingPeriod, !billingPeriod.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !record.dateText.isEmpty,
               !record.dateText.contains(String(billingPeriod.prefix(4))) {
                return WDATAValidationOutcome(rawRecord: record, state: .needsReview("date outside billing period"))
            }

            return WDATAValidationOutcome(rawRecord: record, state: .pass)
        }
    }

    private static func plateFromRawFields(_ fields: [String]) -> String? {
        fields.first(where: { $0.contains("กทม") || $0.contains("-") || $0.contains("ทะเบียน") })
    }

    private static func isLikelyPlate(_ plate: String) -> Bool {
        let text = normalized(plate).replacingOccurrences(of: " ", with: "")
        return text.count >= 4 && text.count <= 12
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

    private static func normalized(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "th_TH"))
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
