import Foundation

struct WDATAImportPreview {
    var passRecords: [WeightSlipRecord]
    var reviewNotes: [String]
    var reviewCount: Int
    var unsupportedCount: Int

    var summaryMessage: String {
        "Preview \(passRecords.count) records · Needs review \(reviewCount) · Unsupported \(unsupportedCount)"
    }
}

enum WDATAImportWorkflow {
    static func preparePreview(
        from urls: [URL],
        knownCustomerCodes: Set<String>,
        knownCustomerNames: Set<String>,
        existingTickets: Set<String>,
        servicePeriod: String
    ) -> WDATAImportPreview {
        var stagedRecords: [WeightSlipRecord] = []
        var reviewNotes: [String] = []
        var reviewCount = 0
        var unsupportedCount = 0

        for url in urls {
            #if canImport(UIKit)
            let needsScopedAccess = url.startAccessingSecurityScopedResource()
            defer {
                if needsScopedAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            #endif

            do {
                let data = try Data(contentsOf: url)
                let ext = url.pathExtension.lowercased()

                switch ext {
                case "txt", "csv":
                    let wdataRawRecords = WindaWDATAParser.parseRawRecords(data: data, sourceFileName: url.lastPathComponent)
                    let text = String(data: data, encoding: .utf8) ?? ""
                    let parsedRecords = wdataRawRecords.isEmpty ? ScaleExportParser.parse(text: text, sourceFileName: url.lastPathComponent) : []
                    let outcomes = WDATAImportValidator.validate(
                        records: wdataRawRecords,
                        existingTickets: existingTickets,
                        knownCustomerCodes: knownCustomerCodes,
                        knownCustomerNames: knownCustomerNames,
                        billingPeriod: servicePeriod
                    )

                    for outcome in outcomes {
                        switch outcome.state {
                        case .pass:
                            if let record = WindaWDATAParser.makeWeightSlipRecord(from: outcome.rawRecord) {
                                stagedRecords.append(record)
                            } else {
                                reviewCount += 1
                                reviewNotes.append("row \(outcome.rowNumber): cannot convert pass row to WeightSlipRecord")
                            }
                        case .needsReview(let reason):
                            reviewCount += 1
                            reviewNotes.append("row \(outcome.rowNumber) \(outcome.rawRecord.ticketNo): \(reason)")
                        case .reject(let reason):
                            reviewCount += 1
                            reviewNotes.append("row \(outcome.rowNumber) \(outcome.rawRecord.ticketNo.isEmpty ? "-" : outcome.rawRecord.ticketNo): \(reason)")
                        }
                    }

                    if outcomes.isEmpty {
                        if !parsedRecords.isEmpty {
                            stagedRecords.append(contentsOf: parsedRecords)
                        } else {
                            reviewCount += 1
                        }
                    }
                default:
                    unsupportedCount += 1
                }
            } catch {
                reviewCount += 1
            }
        }

        return WDATAImportPreview(
            passRecords: stagedRecords,
            reviewNotes: reviewNotes,
            reviewCount: reviewCount,
            unsupportedCount: unsupportedCount
        )
    }
}
