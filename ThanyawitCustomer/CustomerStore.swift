import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit
import Vision
import PDFKit

@MainActor
final class CustomerStore: ObservableObject {
    @Published var customers: [Customer] = []
    @Published var billing: [String: BillingLine] = [:]
    @Published var monthlyProfitRecords: [MonthlyProfitRecord] = []
    @Published var servicePeriod: String = "เมษายน 2569"
    @Published var documentDate: String = "1 พฤษภาคม 2569"
    @Published var searchText: String = ""
    @Published var groupFilter: String = "ทั้งหมด"
    @Published var statusFilter: String = "ทั้งหมด"

    private var billingKey: String { "thanyawit.billing.v10" }
    private var customersKey: String { "thanyawit.customers.v10" }
    private var servicePeriodKey: String { "thanyawit.servicePeriod.v10" }
    private var documentDateKey: String { "thanyawit.documentDate.v10" }
    private var monthlyProfitRecordsKey: String { "thanyawit.monthlyProfitRecords.v1" }
    private var bundledCustomersVersionKey: String { "thanyawit.customers.bundleVersion.v1" }
    private let bundledCustomersVersion = 20260419
    private let autoWeightEvidenceNotes: Set<String> = ["แนบภาพใบชั่งแล้ว", "แนบเอกสารใบชั่ง PDF แล้ว"]

    init() {
        loadCustomers()
        loadSavedBilling()
        loadMonthlyProfitRecords()
        _ = writeEmergencyExportFiles()
    }

    var filteredCustomers: [Customer] {
        customers.filter { customer in
            let matchesSearch: Bool
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                let text = [
                    customer.customerCode,
                    customer.agencyName,
                    customer.agencyShort,
                    customer.districtName,
                    customer.customerGroup
                ].joined(separator: " ").lowercased()
                matchesSearch = text.contains(searchText.lowercased())
            }

            let matchesGroup = groupFilter == "ทั้งหมด" || customer.customerGroup == groupFilter
            let status = precheck(for: customer).status
            let matchesStatus = statusFilter == "ทั้งหมด" || status == statusFilter
            return matchesSearch && matchesGroup && matchesStatus
        }
    }

    var readyCount: Int {
        customers.map { precheck(for: $0) }.filter(\.isReady).count
    }

    var reviewCount: Int {
        customers.count - readyCount
    }

    var totalAmountBeforeVAT: Double {
        customers.reduce(0) { partial, customer in
            partial + billingLine(for: customer).amountBeforeVAT
        }
    }

    var selectedBillingLines: [BillingLine] {
        customers.map { billingLine(for: $0) }.filter(\.isSelected)
    }

    var currentSalesBeforeVAT: Double {
        selectedBillingLines.reduce(0) { $0 + $1.amountBeforeVAT }
    }

    var currentVATAmount: Double {
        selectedBillingLines.reduce(0) { $0 + $1.vatAmount }
    }

    var currentWithholdingAmount: Double {
        selectedBillingLines.reduce(0) { $0 + $1.withholdingAmount }
    }

    var currentNetReceipt: Double {
        selectedBillingLines.reduce(0) { $0 + $1.netAmount }
    }

    var currentTotalWeight: Double {
        selectedBillingLines.reduce(0) { $0 + $1.weight }
    }

    var currentReadyDocuments: Int {
        allPrecheckResults().filter(\.isReady).count
    }

    func loadCustomers() {
        let bundled = loadBundledCustomers()
        let savedVersion = UserDefaults.standard.integer(forKey: bundledCustomersVersionKey)

        if let data = UserDefaults.standard.data(forKey: customersKey),
           let saved = try? JSONDecoder().decode([Customer].self, from: data),
           !saved.isEmpty {
            if savedVersion < bundledCustomersVersion {
                customers = mergeSavedCustomers(saved, withBundled: bundled)
                saveCustomers()
                UserDefaults.standard.set(bundledCustomersVersion, forKey: bundledCustomersVersionKey)
            } else {
                customers = saved
            }
        } else {
            customers = bundled
            saveCustomers()
            UserDefaults.standard.set(bundledCustomersVersion, forKey: bundledCustomersVersionKey)
        }

        for customer in customers where billing[customer.id] == nil {
            billing[customer.id] = defaultBilling(for: customer)
        }
    }

    private func loadBundledCustomers() -> [Customer] {
        let jsonCustomers = loadBundledCustomersFromJSON()
        let csvRows = loadBundledCustomersFromCSV()
        guard !csvRows.isEmpty else { return jsonCustomers }
        return mergeBundledCustomers(from: csvRows, fallback: jsonCustomers)
    }

    private func loadBundledCustomersFromJSON() -> [Customer] {
        guard let url = Bundle.main.url(forResource: "customers", withExtension: "json", subdirectory: "Resources")
                ?? Bundle.main.url(forResource: "customers", withExtension: "json") else {
            assertionFailure("customers.json not found")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Customer].self, from: data)
        } catch {
            assertionFailure("Failed to load customers: \(error)")
            return []
        }
    }

    private func loadBundledCustomersFromCSV() -> [BundledCustomerCSVRow] {
        guard let url = Bundle.main.url(forResource: "thanyawit_customers", withExtension: "csv", subdirectory: "Resources")
                ?? Bundle.main.url(forResource: "thanyawit_customers", withExtension: "csv") else {
            return []
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = parseCSVRows(content)
            guard let header = rows.first else { return [] }
            let cleanedHeader = header.map { $0.replacingOccurrences(of: "\u{FEFF}", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
            let requiredHeaders = [
                "customer_code",
                "agency_name",
                "customer_group",
                "district_name",
                "tax_id",
                "contract_no",
                "contract_date",
                "เลขที่โครงการ",
                "เลขคุมสัญญา",
                "agency_address"
            ]
            guard requiredHeaders.allSatisfy({ cleanedHeader.contains($0) }) else {
                assertionFailure("CSV header mismatch: required headers are missing")
                return []
            }
            let headerIndex = Dictionary(uniqueKeysWithValues: cleanedHeader.enumerated().map { index, value in
                (value, index)
            })

            return rows.dropFirst().compactMap { row -> BundledCustomerCSVRow? in
                func value(_ key: String) -> String {
                    guard let index = headerIndex[key], index < row.count else { return "" }
                    return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
                }

                let customerCode = value("customer_code").uppercased()
                let agencyName = value("agency_name")
                guard !customerCode.isEmpty, !agencyName.isEmpty else { return nil }

                let rawMissingItems = value("missing_items")
                let missingItems = rawMissingItems
                    .split(whereSeparator: { $0 == ";" || $0 == "," })
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                let readinessValue = value("readiness")
                let readiness = readinessValue.isEmpty
                    ? (missingItems.isEmpty ? "พร้อมออก" : "รอตรวจ")
                    : readinessValue

                return BundledCustomerCSVRow(
                    customerCode: customerCode,
                    agencyName: agencyName,
                    customerGroup: value("customer_group"),
                    districtName: value("district_name"),
                    taxId: value("tax_id"),
                    contractNo: value("contract_no"),
                    contractDate: value("contract_date"),
                    projectNo: value("เลขที่โครงการ"),
                    contractControlNo: value("เลขคุมสัญญา"),
                    agencyAddress: value("agency_address"),
                    readiness: readiness,
                    missingItems: missingItems
                )
            }
        } catch {
            assertionFailure("Failed to load thanyawit_customers.csv: \(error)")
            return []
        }
    }

    private func mergeBundledCustomers(from csvRows: [BundledCustomerCSVRow], fallback: [Customer]) -> [Customer] {
        let fallbackByCode = Dictionary(uniqueKeysWithValues: fallback.map { ($0.customerCode.uppercased(), $0) })
        var merged: [Customer] = []
        var usedCodes = Set<String>()

        for row in csvRows {
            let code = row.customerCode.uppercased()
            var customer = fallbackByCode[code] ?? Customer.blank(nextCode: code)
            customer.id = code
            customer.customerCode = code
            customer.agencyName = row.agencyName
            customer.documentName = row.agencyName
            customer.agencyShort = preferredText(customer.agencyShort, makeAgencyShort(from: row.agencyName))
            customer.agencyType = preferredText(makeAgencyType(from: row.agencyName), customer.agencyType)
            customer.customerGroup = preferredText(row.customerGroup, customer.customerGroup)
            customer.districtName = preferredText(row.districtName, customer.districtName)
            customer.taxId = preferredText(row.taxId, customer.taxId)
            customer.contractNo = preferredText(row.contractNo, customer.contractNo)
            customer.contractDate = preferredText(row.contractDate, customer.contractDate)
            customer.projectNo = preferredText(row.projectNo, customer.projectNo)
            customer.contractControlNo = preferredText(row.contractControlNo, customer.contractControlNo)
            customer.agencyAddress = preferredText(row.agencyAddress, customer.agencyAddress)
            customer.provinceName = preferredText(inferProvinceName(from: customer.agencyAddress), customer.provinceName)
            customer.readiness = preferredText(row.readiness, customer.readiness)
            if !row.missingItems.isEmpty {
                customer.missingItems = row.missingItems
            } else if customer.readiness == "พร้อมออก" {
                customer.missingItems = []
            }
            customer.internalNote = appendSourceNote(customer.internalNote, source: "thanyawit_customers.csv")
            merged.append(customer)
            usedCodes.insert(code)
        }

        let extras = fallback.filter { !usedCodes.contains($0.customerCode.uppercased()) }
        return merged + extras
    }

    private func mergeSavedCustomers(_ saved: [Customer], withBundled bundled: [Customer]) -> [Customer] {
        let savedByID = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
        let savedByCode = Dictionary(uniqueKeysWithValues: saved.map { ($0.customerCode, $0) })
        var merged: [Customer] = []
        var usedSavedIDs = Set<String>()

        for bundledCustomer in bundled {
            let savedCustomer = savedByID[bundledCustomer.id] ?? savedByCode[bundledCustomer.customerCode]
            if let savedCustomer {
                merged.append(mergeCustomer(savedCustomer, fallback: bundledCustomer))
                usedSavedIDs.insert(savedCustomer.id)
            } else {
                merged.append(bundledCustomer)
            }
        }

        let extras = saved.filter { !usedSavedIDs.contains($0.id) }
        return merged + extras
    }

    private func mergeCustomer(_ saved: Customer, fallback bundled: Customer) -> Customer {
        var merged = saved

        merged.id = preferredText(saved.id, bundled.id)
        merged.customerCode = preferredText(saved.customerCode, bundled.customerCode)
        merged.agencyName = preferredText(bundled.agencyName, saved.agencyName)
        merged.agencyShort = preferredText(bundled.agencyShort, saved.agencyShort)
        merged.agencyType = preferredText(bundled.agencyType, saved.agencyType)
        merged.customerGroup = preferredText(bundled.customerGroup, saved.customerGroup)
        merged.districtName = preferredText(bundled.districtName, saved.districtName)
        merged.provinceName = preferredText(bundled.provinceName, saved.provinceName)
        merged.procurementMethod = preferredText(saved.procurementMethod, bundled.procurementMethod)
        merged.projectType = preferredText(saved.projectType, bundled.projectType)
        merged.taxId = preferredText(bundled.taxId, saved.taxId)
        merged.contractNo = preferredText(bundled.contractNo, saved.contractNo)
        merged.contractDate = preferredText(bundled.contractDate, saved.contractDate)
        merged.projectNo = preferredText(bundled.projectNo, saved.projectNo)
        merged.contractControlNo = preferredText(bundled.contractControlNo, saved.contractControlNo)
        merged.documentName = preferredText(bundled.documentName, saved.documentName)
        merged.attentionName = preferredText(bundled.attentionName, saved.attentionName)
        merged.agencyAddress = preferredText(bundled.agencyAddress, saved.agencyAddress)
        merged.baseRevenue2569 = preferredNumber(saved.baseRevenue2569, bundled.baseRevenue2569)
        merged.baseWeight2569 = preferredNumber(saved.baseWeight2569, bundled.baseWeight2569)
        merged.unitRateDefault = preferredNumber(saved.unitRateDefault, bundled.unitRateDefault)
        merged.vatPercent = preferredNumber(saved.vatPercent, bundled.vatPercent)
        merged.whtPercent = preferredNumber(saved.whtPercent, bundled.whtPercent)
        merged.readiness = preferredText(bundled.readiness, saved.readiness)
        merged.missingItems = bundled.missingItems.isEmpty ? saved.missingItems : bundled.missingItems
        merged.internalNote = preferredText(bundled.internalNote, saved.internalNote)
        merged.lineId = preferredText(saved.lineId, bundled.lineId)
        merged.documentWorkCompletedAt = preferredText(saved.documentWorkCompletedAt, bundled.documentWorkCompletedAt)
        merged.lastLineSentAt = preferredText(saved.lastLineSentAt, bundled.lastLineSentAt)

        return merged
    }

    private func preferredText(_ primary: String, _ fallback: String) -> String {
        primary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : primary
    }

    private func preferredNumber(_ primary: Double, _ fallback: Double) -> Double {
        primary == 0 ? fallback : primary
    }

    private struct BundledCustomerCSVRow {
        let customerCode: String
        let agencyName: String
        let customerGroup: String
        let districtName: String
        let taxId: String
        let contractNo: String
        let contractDate: String
        let projectNo: String
        let contractControlNo: String
        let agencyAddress: String
        let readiness: String
        let missingItems: [String]
    }

    private func parseCSVRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if character == "\"" {
                let next = text.index(after: index)
                if inQuotes, next < text.endIndex, text[next] == "\"" {
                    field.append("\"")
                    index = next
                } else {
                    inQuotes.toggle()
                }
            } else if character == ",", !inQuotes {
                row.append(field)
                field = ""
            } else if (character == "\n" || character == "\r"), !inQuotes {
                row.append(field)
                field = ""
                if !row.isEmpty, !row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    rows.append(row)
                }
                row = []
                if character == "\r" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\n" {
                        index = next
                    }
                }
            } else {
                field.append(character)
            }
            index = text.index(after: index)
        }

        row.append(field)
        if !row.isEmpty, !row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            rows.append(row)
        }
        return rows
    }

    private func makeAgencyType(from agencyName: String) -> String {
        if agencyName.contains("เทศบาล") {
            return "ทต."
        }
        if agencyName.contains("องค์การบริหารส่วนตำบล") || agencyName.contains("อบต") {
            return "อบต."
        }
        return ""
    }

    private func makeAgencyShort(from agencyName: String) -> String {
        let trimmed = agencyName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("เทศบาลตำบล") {
            return "ทต." + trimmed.replacingOccurrences(of: "เทศบาลตำบล", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if trimmed.hasPrefix("องค์การบริหารส่วนตำบล") {
            return "อบต." + trimmed.replacingOccurrences(of: "องค์การบริหารส่วนตำบล", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private func inferProvinceName(from address: String) -> String {
        if address.contains("สมุทรสงคราม") { return "สมุทรสงคราม" }
        if address.contains("ราชบุรี") { return "ราชบุรี" }
        return ""
    }

    private func appendSourceNote(_ current: String, source: String) -> String {
        if current.contains(source) { return current }
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "โหลดฐานล่าสุดจาก \(source)"
        }
        return "\(trimmed) | โหลดฐานล่าสุดจาก \(source)"
    }

    func saveCustomers() {
        do {
            let data = try JSONEncoder().encode(customers)
            UserDefaults.standard.set(data, forKey: customersKey)
        } catch {
            print("Failed to save customers: \(error)")
        }
    }

    func resetLocalCustomersToBundledData() {
        UserDefaults.standard.removeObject(forKey: customersKey)
        UserDefaults.standard.removeObject(forKey: billingKey)
        customers = []
        billing = [:]
        loadCustomers()
        loadSavedBilling()
        objectWillChange.send()
    }

    func nextCustomerCode() -> String {
        let maxNumber = customers.compactMap { customer -> Int? in
            let digits = customer.customerCode.filter { $0.isNumber }
            return Int(digits)
        }.max() ?? 0
        return "C\(String(format: "%03d", maxNumber + 1))"
    }

    func addCustomer(_ customer: Customer) {
        var newCustomer = customer
        if newCustomer.id.isEmpty {
            newCustomer.id = nextCustomerCode()
        }
        if newCustomer.customerCode.isEmpty {
            newCustomer.customerCode = newCustomer.id
        }
        if newCustomer.documentName.isEmpty {
            newCustomer.documentName = newCustomer.agencyName
        }
        customers.append(newCustomer)
        billing[newCustomer.id] = defaultBilling(for: newCustomer)
        saveCustomers()
        saveBilling()
    }

    func updateCustomer(_ customer: Customer) {
        if let index = customers.firstIndex(where: { $0.id == customer.id }) {
            var edited = customer
            if edited.documentName.isEmpty {
                edited.documentName = edited.agencyName
            }
            customers[index] = edited
            if billing[edited.id] == nil {
                billing[edited.id] = defaultBilling(for: edited)
            }
            saveCustomers()
            saveBilling()
        }
    }

    func deleteCustomer(_ customer: Customer) {
        customers.removeAll { $0.id == customer.id }
        billing.removeValue(forKey: customer.id)
        saveCustomers()
        saveBilling()
    }

    func missingItems(for customer: Customer) -> [String] {
        var items: [String] = []
        if customer.agencyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("ชื่อหน่วยงาน")
        }
        if customer.taxId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("เลขผู้เสียภาษี")
        }
        if customer.contractNo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("เลขสัญญา")
        }
        if customer.contractDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("วันที่สัญญา")
        }
        if customer.agencyAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("ที่อยู่")
        }
        return items
    }

    func defaultBilling(for customer: Customer) -> BillingLine {
        var line = BillingLine(id: customer.id)
        line.weight = customer.baseWeight2569
        line.unitRate = customer.unitRateDefault
        line.amountBeforeVAT = customer.baseRevenue2569
        line.vatPercent = customer.vatPercent
        line.withholdingPercent = customer.whtPercent
        return line
    }

    func billingLine(for customer: Customer) -> BillingLine {
        billing[customer.id] ?? defaultBilling(for: customer)
    }

    func updateBilling(_ line: BillingLine) {
        billing[line.id] = line
        saveBilling()
    }

    func precheck(for customer: Customer) -> PrecheckResult {
        let line = billingLine(for: customer)
        var reasons = missingItems(for: customer)
        if line.weight <= 0 {
            reasons.append("น้ำหนัก/จำนวน")
        }
        if line.unitRate <= 0 {
            reasons.append("หน่วยราคา")
        }
        if line.amountBeforeVAT <= 0 {
            reasons.append("ยอดก่อน VAT")
        }
        if !hasWeightEvidence(line) {
            reasons.append("ภาพ/หลักฐานใบชั่งน้ำหนัก")
        }
        if hasWeightEvidence(line) {
            if !line.weightSlipAgencyMatched {
                reasons.append("OCR ใบชั่งยังไม่ยืนยันชื่อ อปท.")
            }
            if line.weightTonFromTable <= 0 {
                reasons.append("OCR ยังไม่พบบรรทัดตารางน้ำหนักที่ใช้คำนวณผลรวม")
            } else if requiresReviewerWeightNote(line) && !hasReviewerWeightNote(line) {
                reasons.append("ตารางน้ำหนักไม่ตรงยอดรวม OCR ต้องกรอกหมายเหตุผู้ตรวจก่อนอนุมัติ")
            }
        }
        if line.weightTimeIn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            line.weightTimeOut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reasons.append("เวลาเข้า/ออกของหลักฐานใบชั่ง")
        }
        if amountMismatchWarning(for: line) != nil {
            reasons.append("ยอดไม่ตรงน้ำหนัก x ราคา")
        }
        if line.billingApprovedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reasons.append("ยังไม่อนุมัติบิลหลังตรวจพรีวิว")
        }
        if !line.isSelected {
            reasons.append("พักรายการ")
        }
        let status = reasons.isEmpty ? "พร้อมออก" : "รอตรวจ"
        return PrecheckResult(id: customer.id, customer: customer, billing: line, status: status, reasons: reasons)
    }

    func allPrecheckResults() -> [PrecheckResult] {
        customers.map { precheck(for: $0) }
    }

    func saveBilling() {
        do {
            let data = try JSONEncoder().encode(billing)
            UserDefaults.standard.set(data, forKey: billingKey)
            UserDefaults.standard.set(servicePeriod, forKey: servicePeriodKey)
            UserDefaults.standard.set(documentDate, forKey: documentDateKey)
        } catch {
            print("Failed to save billing: \(error)")
        }
    }

    func loadSavedBilling() {
        servicePeriod = UserDefaults.standard.string(forKey: servicePeriodKey) ?? servicePeriod
        documentDate = UserDefaults.standard.string(forKey: documentDateKey) ?? documentDate

        guard let data = UserDefaults.standard.data(forKey: billingKey) else { return }
        do {
            billing = try JSONDecoder().decode([String: BillingLine].self, from: data)
        } catch {
            print("Failed to load saved billing: \(error)")
        }
    }

    func resetBilling() {
        billing = Dictionary(uniqueKeysWithValues: customers.map { ($0.id, defaultBilling(for: $0)) })
        saveBilling()
    }

    func loadMonthlyProfitRecords() {
        guard let data = UserDefaults.standard.data(forKey: monthlyProfitRecordsKey) else { return }
        do {
            monthlyProfitRecords = try JSONDecoder().decode([MonthlyProfitRecord].self, from: data)
        } catch {
            print("Failed to load monthly profit records: \(error)")
        }
    }

    func saveMonthlyProfitRecords() {
        do {
            let data = try JSONEncoder().encode(monthlyProfitRecords)
            UserDefaults.standard.set(data, forKey: monthlyProfitRecordsKey)
        } catch {
            print("Failed to save monthly profit records: \(error)")
        }
    }

    func costForCurrentPeriod() -> Double {
        monthlyProfitRecords.first(where: { $0.servicePeriod == servicePeriod })?.costAmount ?? 0
    }

    func profitDraft(costAmount: Double) -> MonthlyProfitRecord {
        let sales = currentSalesBeforeVAT
        return MonthlyProfitRecord(
            id: servicePeriod,
            servicePeriod: servicePeriod,
            recordedAt: ThaiDate.nowDateTimeText(),
            salesBeforeVAT: sales,
            vatAmount: currentVATAmount,
            withholdingAmount: currentWithholdingAmount,
            netReceipt: currentNetReceipt,
            costAmount: costAmount,
            profitAmount: sales - costAmount,
            totalWeight: currentTotalWeight,
            readyDocuments: currentReadyDocuments
        )
    }

    @discardableResult
    func upsertMonthlyProfitRecord(costAmount: Double) -> MonthlyProfitRecord {
        let record = profitDraft(costAmount: costAmount)
        if let index = monthlyProfitRecords.firstIndex(where: { $0.servicePeriod == record.servicePeriod }) {
            monthlyProfitRecords[index] = record
        } else {
            monthlyProfitRecords.append(record)
        }
        monthlyProfitRecords.sort { $0.recordedAt < $1.recordedAt }
        saveMonthlyProfitRecords()
        return record
    }

    func deleteMonthlyProfitRecords(at offsets: IndexSet) {
        monthlyProfitRecords.remove(atOffsets: offsets)
        saveMonthlyProfitRecords()
    }

    func csvForBilling() -> String {
        let header = [
            "customer_code",
            "agency_name",
            "service_period",
            "document_date",
            "weight",
            "unit_rate",
            "amount_before_vat",
            "vat_percent",
            "vat_amount",
            "withholding_percent",
            "withholding_amount",
            "net_amount",
            "weight_slip_source_file",
            "weight_slip_image",
            "weight_slip_confirmed_at",
            "weight_evidence_note",
            "slip_ticket_no",
            "weight_time_in",
            "weight_time_out",
            "weight_slip_ocr_checked_at",
            "agency_name_matched",
            "total_weight_matched",
            "weight_ton_from_table",
            "ocr_total_ton",
            "is_consistent",
            "agency_check_note",
            "weight_check_note",
            "ocr_detected_weight",
            "billing_approved_at",
            "billing_approval_note",
            "status",
            "reasons"
        ]

        let rows = customers.map { customer -> [String] in
            let result = precheck(for: customer)
            let line = result.billing
            return [
                customer.customerCode,
                customer.agencyName,
                servicePeriod,
                documentDate,
                formatNumber(line.weight),
                formatNumber(line.unitRate),
                formatNumber(line.amountBeforeVAT),
                formatNumber(line.vatPercent),
                formatNumber(line.vatAmount),
                formatNumber(line.withholdingPercent),
                formatNumber(line.withholdingAmount),
                formatNumber(line.netAmount),
                line.weightSlipSourceFilename,
                line.weightSlipImageFilename,
                line.weightSlipConfirmedAt,
                line.weightEvidenceNote,
                line.slipTicketNo,
                line.weightTimeIn,
                line.weightTimeOut,
                line.weightSlipOCRCheckedAt,
                line.weightSlipAgencyMatched ? "yes" : "no",
                line.weightSlipTotalWeightMatched ? "yes" : "no",
                formatNumber(line.weightTonFromTable),
                formatNumber(line.ocrTotalTon),
                line.weightSlipTotalWeightMatched ? "yes" : "no",
                line.weightSlipAgencyCheckNote,
                line.weightSlipWeightCheckNote,
                formatNumber(line.ocrDetectedWeight),
                line.billingApprovedAt,
                line.billingApprovalNote,
                result.status,
                result.reasons.joined(separator: "; ")
            ]
        }

        return ([header] + rows)
            .map { $0.map(csvEscape).joined(separator: ",") }
            .joined(separator: "\n")
    }

    func csvForCustomers() -> String {
        let header = [
            "customer_code",
            "agency_name",
            "customer_group",
            "district_name",
            "tax_id",
            "contract_no",
            "contract_date",
            "agency_address",
            "line_id",
            "document_work_completed_at",
            "last_line_sent_at",
            "readiness",
            "missing_items"
        ]

        let rows = customers.map { customer -> [String] in
            [
                customer.customerCode,
                customer.agencyName,
                customer.customerGroup,
                customer.districtName,
                customer.taxId,
                customer.contractNo,
                customer.contractDate,
                customer.agencyAddress,
                customer.lineId,
                customer.documentWorkCompletedAt,
                customer.lastLineSentAt,
                precheck(for: customer).status,
                precheck(for: customer).reasons.joined(separator: "; ")
            ]
        }

        return ([header] + rows)
            .map { $0.map(csvEscape).joined(separator: ",") }
            .joined(separator: "\n")
    }

    private func csvEscape(_ text: String) -> String {
        "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    func formatNumber(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    func expectedAmount(for line: BillingLine) -> Double {
        line.weight * line.unitRate
    }

    func hasWeightEvidence(_ line: BillingLine) -> Bool {
        !line.weightSlipSourceFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !line.weightSlipImageFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !line.weightEvidenceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func normalizedEvidenceNote(_ note: String) -> String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func requiresReviewerWeightNote(_ line: BillingLine) -> Bool {
        line.weightTonFromTable > 0 && !line.weightSlipTotalWeightMatched
    }

    func hasReviewerWeightNote(_ line: BillingLine) -> Bool {
        let note = normalizedEvidenceNote(line.weightEvidenceNote)
        guard !note.isEmpty else { return false }
        return !autoWeightEvidenceNotes.contains(note)
    }

    func isWeightSlipApprovalReady(_ line: BillingLine) -> Bool {
        guard line.weightSlipAgencyMatched else { return false }
        guard line.weightTonFromTable > 0 else { return false }
        if requiresReviewerWeightNote(line) {
            return hasReviewerWeightNote(line)
        }
        return true
    }

    func isWeightSlipOCRVerified(_ line: BillingLine) -> Bool {
        isWeightSlipApprovalReady(line)
    }

    func amountMismatchWarning(for line: BillingLine) -> String? {
        let expected = expectedAmount(for: line)
        guard line.weight > 0, line.unitRate > 0, line.amountBeforeVAT > 0, expected > 0 else {
            return nil
        }
        let diff = abs(expected - line.amountBeforeVAT)
        guard diff > 1 else { return nil }
        return "ยอดก่อน VAT ควรเป็น \(ThaiFormat.money(expected)) ต่างจากที่กรอก \(ThaiFormat.money(diff))"
    }

    func saveWeightSlipImage(_ data: Data, for customer: Customer) throws -> BillingLine {
        let folder = try weightSlipEvidenceFolder()
        let filename = "\(safeStorageName(customer.id))_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).jpg"
        let url = folder.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)

        var line = billingLine(for: customer)
        line.weightSlipSourceFilename = filename
        line.weightSlipImageFilename = filename
        line.weightSlipConfirmedAt = ThaiDate.nowDateTimeText()
        if line.weightEvidenceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            line.weightEvidenceNote = "แนบภาพใบชั่งแล้ว"
        }
        updateBilling(line)
        return line
    }

    func analyzeWeightSlipImage(_ data: Data, for customer: Customer, baseLine: BillingLine? = nil) throws -> BillingLine {
        let recognizedText = try recognizeText(fromWeightSlipImageData: data)
        return applyRecognizedWeightSlipText(recognizedText, for: customer, baseLine: baseLine)
    }

    func analyzeWeightSlipDocument(_ data: Data, fileName: String, for customer: Customer, baseLine: BillingLine? = nil) throws -> BillingLine {
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        if ext == "pdf" {
            var line = baseLine ?? billingLine(for: customer)
            line.weightSlipSourceFilename = fileName
            line.weightSlipImageFilename = ""
            line.weightSlipConfirmedAt = ThaiDate.nowDateTimeText()
            if line.weightEvidenceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                line.weightEvidenceNote = "แนบเอกสารใบชั่ง PDF แล้ว"
            }
            let recognizedText = try recognizeText(fromWeightSlipPDFData: data)
            return applyRecognizedWeightSlipText(recognizedText, for: customer, baseLine: line)
        }

        let savedLine = try saveWeightSlipImage(data, for: customer)
        return try analyzeWeightSlipImage(data, for: customer, baseLine: savedLine)
    }

    func importBulkWeightSlipImages(_ imageDatas: [Data]) -> [BulkWeightSlipImportResult] {
        imageDatas.enumerated().map { offset, data in
            let index = offset + 1

            do {
                let recognizedText = try recognizeText(fromWeightSlipImageData: data)
                let weightResult = detectTotalWeight(in: recognizedText)

                guard let matched = bestCustomerMatch(in: recognizedText) else {
                    return BulkWeightSlipImportResult(
                        index: index,
                        customerName: "-",
                        status: "รอตรวจ",
                        detectedWeight: weightResult.weightTonFromTable,
                        note: "ยังแยก อปท. ไม่ได้ กรุณาตรวจข้อความ OCR หรือเพิ่มคำสำคัญในชื่อหน่วยงาน"
                    )
                }

                let savedLine = try saveWeightSlipImage(data, for: matched.customer)
                let analyzedLine = applyRecognizedWeightSlipText(recognizedText, for: matched.customer, baseLine: savedLine)
                return BulkWeightSlipImportResult(
                    index: index,
                    customerName: matched.customer.agencyShort.isEmpty ? matched.customer.agencyName : matched.customer.agencyShort,
                    status: isWeightSlipOCRVerified(analyzedLine) ? "แยกสำเร็จ" : "รอตรวจ",
                    detectedWeight: analyzedLine.ocrDetectedWeight,
                    note: "\(matched.note) | \(analyzedLine.weightSlipWeightCheckNote)"
                )
            } catch {
                return BulkWeightSlipImportResult(
                    index: index,
                    customerName: "-",
                    status: "ผิดพลาด",
                    detectedWeight: 0,
                    note: error.localizedDescription
                )
            }
        }
    }

    private func recognizeText(fromWeightSlipImageData data: Data) throws -> String {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            throw NSError(domain: "ThanyawitOCR", code: 1, userInfo: [NSLocalizedDescriptionKey: "เปิดภาพใบชั่งไม่ได้"])
        }

        let orientations: [CGImagePropertyOrientation] = [.up, .right, .left, .down]
        let candidates = orientations.compactMap { orientation -> String? in
            try? recognizeText(in: cgImage, orientation: orientation)
        }
        if let best = candidates.max(by: { recognitionScore(for: $0) < recognitionScore(for: $1) }) {
            return best
        }

        return try recognizeText(in: cgImage, orientation: .up)
    }

    private func recognizeText(fromWeightSlipPDFData data: Data) throws -> String {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw NSError(domain: "ThanyawitOCR", code: 2, userInfo: [NSLocalizedDescriptionKey: "เปิดไฟล์ PDF ใบชั่งไม่ได้"])
        }

        var parts: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let directText = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !directText.isEmpty {
                parts.append(directText)
                continue
            }

            let image = page.thumbnail(of: CGSize(width: 2000, height: 2600), for: .mediaBox)
            if let cgImage = image.cgImage, let ocrText = try? recognizeText(in: cgImage, orientation: .up), !ocrText.isEmpty {
                parts.append(ocrText)
            }
        }

        let combined = parts.joined(separator: "\n")
        if combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw NSError(domain: "ThanyawitOCR", code: 3, userInfo: [NSLocalizedDescriptionKey: "PDF ไม่มีข้อความให้อ่าน กรุณาสแกนใหม่"])
        }
        return combined
    }

    private func recognizeText(in cgImage: CGImage, orientation: CGImagePropertyOrientation) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let supportedLanguages = (try? request.supportedRecognitionLanguages()) ?? []
        let preferredLanguages = ["th-TH", "en-US"].filter { supportedLanguages.contains($0) }
        if !preferredLanguages.isEmpty {
            request.recognitionLanguages = preferredLanguages
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        try handler.perform([request])

        let recognizedText = request.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n") ?? ""

        return recognizedText
    }

    private func recognitionScore(for text: String) -> Int {
        let customerScore = bestCustomerMatch(in: text) == nil ? 0 : 2_000
        let weightScore = detectTotalWeight(in: text).weightTonFromTable > 0 ? 1_000 : 0
        return customerScore + weightScore + min(normalizedCheckText(text).count, 1_000)
    }

    private func applyRecognizedWeightSlipText(_ recognizedText: String, for customer: Customer, baseLine: BillingLine? = nil) -> BillingLine {
        var line = baseLine ?? billingLine(for: customer)
        let agencyResult = validateAgencyName(in: recognizedText, customer: customer)
        let weightResult = detectTotalWeight(in: recognizedText)
        let ticket = detectTicketNo(in: recognizedText)
        let timeRange = detectTimeRange(in: recognizedText)

        line.weightSlipOCRText = recognizedText
        line.weightSlipOCRCheckedAt = ThaiDate.nowDateTimeText()
        line.weightSlipAgencyMatched = agencyResult.matched
        line.weightSlipTotalWeightMatched = weightResult.isConsistent
        line.weightSlipAgencyCheckNote = agencyResult.note
        line.weightSlipWeightCheckNote = weightResult.note
        line.weightParserAudit = weightResult.parserAudit
        line.weightTonFromTable = weightResult.weightTonFromTable
        line.ocrTotalTon = weightResult.ocrTotalTon
        line.ocrDetectedWeight = weightResult.ocrTotalTon
        if line.weightSlipSourceFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !line.weightSlipImageFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            line.weightSlipSourceFilename = line.weightSlipImageFilename
        }
        if !ticket.isEmpty {
            line.slipTicketNo = ticket
        }
        if !timeRange.inTime.isEmpty {
            line.weightTimeIn = timeRange.inTime
        }
        if !timeRange.outTime.isEmpty {
            line.weightTimeOut = timeRange.outTime
        }
        if weightResult.weightTonFromTable > 0 {
            line.weight = weightResult.weightTonFromTable
            if line.unitRate > 0 {
                line.amountBeforeVAT = expectedAmount(for: line)
            }
        }
        line.billingApprovedAt = ""
        line.billingApprovalNote = ""
        updateBilling(line)
        return line
    }

    private func bestCustomerMatch(in ocrText: String) -> (customer: Customer, note: String)? {
        let source = normalizedCheckText(ocrText)
        let relaxedSource = relaxedNormalizedCheckText(ocrText)
        var best: (customer: Customer, keyword: String, score: Int)?

        for customer in customers {
            for keyword in agencyMatchKeywords(for: customer) {
                if source.contains(keyword.normalized), keyword.normalized.count * 2 > (best?.score ?? 0) {
                    best = (customer, keyword.display, keyword.normalized.count * 2)
                }
                if relaxedSource.contains(keyword.relaxed), keyword.relaxed.count > (best?.score ?? 0) {
                    best = (customer, keyword.display, keyword.relaxed.count)
                }
            }
        }

        guard let best else { return nil }
        return (best.customer, "พบคำสำคัญ \(best.keyword) จึงแยกเข้า \(best.customer.agencyName)")
    }

    func weightSlipImageURL(for line: BillingLine) -> URL? {
        guard !line.weightSlipImageFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL
            .appendingPathComponent("ThanyawitWeightSlipEvidence", isDirectory: true)
            .appendingPathComponent(line.weightSlipImageFilename)
    }

    private func weightSlipEvidenceFolder() throws -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = documentsURL.appendingPathComponent("ThanyawitWeightSlipEvidence", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func safeStorageName(_ text: String) -> String {
        text.map { character in
            character.isLetter || character.isNumber || character == "-" || character == "_" ? character : "_"
        }
        .map(String.init)
        .joined()
    }

    private func validateAgencyName(in ocrText: String, customer: Customer) -> (matched: Bool, note: String) {
        let source = normalizedCheckText(ocrText)
        let relaxedSource = relaxedNormalizedCheckText(ocrText)
        let keywords = agencyMatchKeywords(for: customer)

        if let matched = keywords.first(where: { source.contains($0.normalized) }) {
            return (true, "พบคำสำคัญของหน่วยงาน: \(matched.display)")
        }

        if let matched = keywords.first(where: { relaxedSource.contains($0.relaxed) }) {
            return (true, "พบคำสำคัญของหน่วยงานแบบละวรรณยุกต์: \(matched.display)")
        }

        let examples = keywords.prefix(4).map { $0.display }.joined(separator: ", ")
        return (false, "ไม่พบชื่อ อปท. ในภาพใบชั่ง ต้องพบอย่างน้อยบางคำ เช่น \(examples)")
    }

    private struct WeightDecision {
        let weightTonFromTable: Double
        let ocrTotalTon: Double
        let isConsistent: Bool
        let note: String
        let parserAudit: String
    }

    private struct ParsedWeightRowDecision {
        let sourceLine: String
        let signature: String
        let extractedCandidates: [Double]
        let normalizedCandidates: [Double]
        let selectedWeightTon: Double?
        let accepted: Bool
        let reason: String
    }

    private func detectTotalWeight(in ocrText: String) -> WeightDecision {
        let lines = thaiDigitsToArabic(ocrText)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let tableResult = detectWeightFromTable(lines: lines)
        let tableTotalTon = roundedTon(tableResult.total)
        let explicitTotalTon = roundedTon(detectExplicitTotalWeight(lines: lines))
        let parserAudit = makeParserAuditPayload(decisions: tableResult.decisions)
        let droppedSummary = droppedReasonSummary(decisions: tableResult.decisions)

        guard tableTotalTon > 0 else {
            if explicitTotalTon > 0 {
                return WeightDecision(
                    weightTonFromTable: 0,
                    ocrTotalTon: explicitTotalTon,
                    isConsistent: false,
                    note: "OCR พบยอดรวม \(formatNumber(explicitTotalTon)) ตัน แต่ไม่พบบรรทัดตารางน้ำหนัก จึงไม่เติมน้ำหนักอัตโนมัติ\(droppedSummary)",
                    parserAudit: parserAudit
                )
            }
            return WeightDecision(
                weightTonFromTable: 0,
                ocrTotalTon: 0,
                isConsistent: false,
                note: "OCR ไม่พบบรรทัดตารางน้ำหนักที่ใช้คำนวณผลรวม\(droppedSummary)",
                parserAudit: parserAudit
            )
        }

        if explicitTotalTon > 0 {
            let isConsistent = tableTotalTon == explicitTotalTon
            let compareText = isConsistent
                ? "ตารางน้ำหนักตรงกับยอดรวม OCR"
                : "ตารางน้ำหนักไม่ตรงยอดรวม OCR (ต้องกรอกหมายเหตุผู้ตรวจก่อนอนุมัติ)"
            return WeightDecision(
                weightTonFromTable: tableTotalTon,
                ocrTotalTon: explicitTotalTon,
                isConsistent: isConsistent,
                note: "รวมจากตารางน้ำหนัก \(tableResult.rowCount) แถว = \(formatNumber(tableTotalTon)) ตัน | ยอดรวม OCR \(formatNumber(explicitTotalTon)) ตัน | \(compareText)\(droppedSummary)",
                parserAudit: parserAudit
            )
        }

        return WeightDecision(
            weightTonFromTable: tableTotalTon,
            ocrTotalTon: 0,
            isConsistent: true,
            note: "รวมจากตารางน้ำหนัก \(tableResult.rowCount) แถว = \(formatNumber(tableTotalTon)) ตัน (ไม่พบยอดรวม OCR สำหรับเทียบ)\(droppedSummary)",
            parserAudit: parserAudit
        )
    }

    private func detectWeightFromTable(lines: [String]) -> (total: Double, rowCount: Int, decisions: [ParsedWeightRowDecision]) {
        let summaryKeywords = ["น้ำหนักรวม", "รวมน้ำหนัก", "รวมสุทธิ", "รวมทั้งเดือน", "ยอดรวม", "total", "sum"]
        let amountKeywords = ["บาท", "vat", "ภาษี", "amount", "ราคา", "รวมเงิน", "ยอดเงิน"]
        let idKeywords = ["เลขที่", "เลขใบชั่ง", "ticket", "invoice", "ทะเบียน", "โทร", "fax", "แฟกซ์", "สัญญา", "ใบแจ้งหนี้"]
        let rowKeywords = ["น้ำหนัก", "weight", "kg", "กก", "ตัน", "ton", "net", "สุทธิ", "gross", "tare", "เที่ยว", "trip"]
        var weights: [Double] = []
        var decisions: [ParsedWeightRowDecision] = []
        var seenSignatures = Set<String>()

        for line in lines {
            let normalizedLine = line.lowercased()
            let signature = parserLineSignature(line)
            if containsAnyKeyword(summaryKeywords, in: normalizedLine) {
                decisions.append(
                    ParsedWeightRowDecision(sourceLine: line, signature: signature, extractedCandidates: [], normalizedCandidates: [], selectedWeightTon: nil, accepted: false, reason: "reject: summary line")
                )
                continue
            }
            if containsAnyKeyword(amountKeywords, in: normalizedLine) {
                decisions.append(
                    ParsedWeightRowDecision(sourceLine: line, signature: signature, extractedCandidates: [], normalizedCandidates: [], selectedWeightTon: nil, accepted: false, reason: "reject: amount/money line")
                )
                continue
            }
            if containsAnyKeyword(idKeywords, in: normalizedLine) {
                decisions.append(
                    ParsedWeightRowDecision(sourceLine: line, signature: signature, extractedCandidates: [], normalizedCandidates: [], selectedWeightTon: nil, accepted: false, reason: "reject: id/meta line")
                )
                continue
            }
            if isDateTimeOnlyLine(line) {
                decisions.append(
                    ParsedWeightRowDecision(sourceLine: line, signature: signature, extractedCandidates: [], normalizedCandidates: [], selectedWeightTon: nil, accepted: false, reason: "reject: datetime-only line")
                )
                continue
            }

            let extraction = extractTableRowWeightTon(from: line, rowKeywords: rowKeywords)
            var decision = extraction.decision
            if let rowWeight = extraction.weightTon {
                if seenSignatures.contains(signature) {
                    decision = ParsedWeightRowDecision(
                        sourceLine: decision.sourceLine,
                        signature: signature,
                        extractedCandidates: decision.extractedCandidates,
                        normalizedCandidates: decision.normalizedCandidates,
                        selectedWeightTon: decision.selectedWeightTon,
                        accepted: false,
                        reason: "reject: duplicate OCR line signature"
                    )
                    decisions.append(decision)
                    continue
                }
                seenSignatures.insert(signature)
                weights.append(rowWeight)
                decisions.append(decision)
                continue
            }
            decisions.append(decision)
        }

        let total = weights.reduce(0, +)
        return (total, weights.count, decisions)
    }

    private func extractTableRowWeightTon(from line: String, rowKeywords: [String]) -> (weightTon: Double?, decision: ParsedWeightRowDecision) {
        let normalizedLine = line.lowercased()
        let signature = parserLineSignature(line)
        let rawCandidates = extractNumbers(from: line)
            .filter(plausibleWeight)
        let candidates = rawCandidates
            .map { normalizedWeight($0, sourceLine: normalizedLine) }
            .filter(plausibleTableRowWeight)

        guard !candidates.isEmpty else {
            return (
                nil,
                ParsedWeightRowDecision(
                    sourceLine: line,
                    signature: signature,
                    extractedCandidates: rawCandidates,
                    normalizedCandidates: candidates,
                    selectedWeightTon: nil,
                    accepted: false,
                    reason: "reject: no plausible row-weight candidate"
                )
            )
        }

        let hasRowKeyword = containsAnyKeyword(rowKeywords, in: normalizedLine)
        let startsWithRowIndex = line.range(of: #"^\s*\d{1,3}(?:[\)\.\-]|\s)"#, options: .regularExpression) != nil
        let hasTableSeparator = line.contains("|")
        let hasMultipleCandidates = candidates.count >= 2

        guard hasRowKeyword || (startsWithRowIndex && hasMultipleCandidates) || (hasTableSeparator && hasMultipleCandidates) else {
            return (
                nil,
                ParsedWeightRowDecision(
                    sourceLine: line,
                    signature: signature,
                    extractedCandidates: rawCandidates,
                    normalizedCandidates: candidates,
                    selectedWeightTon: nil,
                    accepted: false,
                    reason: "reject: row-shape gate failed"
                )
            )
        }

        guard let selected = candidates.last else {
            return (
                nil,
                ParsedWeightRowDecision(
                    sourceLine: line,
                    signature: signature,
                    extractedCandidates: rawCandidates,
                    normalizedCandidates: candidates,
                    selectedWeightTon: nil,
                    accepted: false,
                    reason: "reject: candidate selection failed"
                )
            )
        }
        let rounded = roundedTon(selected)
        return (
            rounded,
            ParsedWeightRowDecision(
                sourceLine: line,
                signature: signature,
                extractedCandidates: rawCandidates,
                normalizedCandidates: candidates,
                selectedWeightTon: rounded,
                accepted: true,
                reason: "accept: parsed table row weight"
            )
        )
    }

    private func parserLineSignature(_ text: String) -> String {
        thaiDigitsToArabic(text)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
            .map(String.init)
            .joined()
    }

    private func makeParserAuditPayload(decisions: [ParsedWeightRowDecision]) -> String {
        decisions.map { decision in
            let raw = decision.extractedCandidates.map(formatNumber).joined(separator: ",")
            let normalized = decision.normalizedCandidates.map(formatNumber).joined(separator: ",")
            let selected = decision.selectedWeightTon.map(formatNumber) ?? "-"
            return [
                decision.accepted ? "ACCEPT" : "REJECT",
                decision.reason,
                "sig=\(decision.signature)",
                "raw=[\(raw)]",
                "norm=[\(normalized)]",
                "selected=\(selected)",
                "line=\(decision.sourceLine)"
            ].joined(separator: " | ")
        }
        .joined(separator: "\n")
    }

    private func droppedReasonSummary(decisions: [ParsedWeightRowDecision]) -> String {
        let rejected = decisions.filter { !$0.accepted }
        guard !rejected.isEmpty else { return "" }
        let grouped = Dictionary(grouping: rejected, by: \.reason)
            .map { reason, items in "\(reason)=\(items.count)" }
            .sorted()
            .joined(separator: ", ")
        return " | ตัดทิ้ง \(rejected.count) บรรทัด (\(grouped))"
    }

    private func detectExplicitTotalWeight(lines: [String]) -> Double {
        let summaryKeywords = ["น้ำหนักรวม", "รวมน้ำหนัก", "รวมสุทธิ", "รวมทั้งเดือน", "ยอดรวม", "total", "sum"]
        var candidates: [Double] = []

        for line in lines {
            let normalizedLine = line.lowercased()
            guard containsAnyKeyword(summaryKeywords, in: normalizedLine) else { continue }
            let values = extractNumbers(from: line)
                .filter(plausibleWeight)
                .map { normalizedWeight($0, sourceLine: normalizedLine) }
                .filter(plausibleTotalWeight)
            if let value = values.last {
                candidates.append(value)
            }
        }

        return candidates.last ?? 0
    }

    private func containsAnyKeyword(_ keywords: [String], in text: String) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }

    private func looksLikeDateTimeLine(_ text: String) -> Bool {
        let datePattern = #"\b\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}\b"#
        let timePattern = #"\b([01]?\d|2[0-3])[:\.]([0-5]\d)\b"#
        return text.range(of: datePattern, options: .regularExpression) != nil
            || text.range(of: timePattern, options: .regularExpression) != nil
    }

    private func isDateTimeOnlyLine(_ text: String) -> Bool {
        guard looksLikeDateTimeLine(text) else { return false }
        let normalized = text.lowercased()
        let hasWeightKeyword = containsAnyKeyword(["น้ำหนัก", "weight", "kg", "กก", "ตัน", "ton", "สุทธิ", "net", "gross", "tare"], in: normalized)
        if hasWeightKeyword {
            return false
        }
        let candidates = extractNumbers(from: text)
            .filter(plausibleWeight)
            .map { normalizedWeight($0, sourceLine: normalized) }
            .filter(plausibleTableRowWeight)
        return candidates.isEmpty
    }

    private func detectTicketNo(in ocrText: String) -> String {
        let text = thaiDigitsToArabic(ocrText)
        let patterns = [
            #"(?i)(?:เลขที่|เลขใบชั่ง|ticket|bill|no\.?)\s*[:\-]?\s*([A-Z0-9\-\/]{4,})"#,
            #"(?m)^\s*([A-Z]{1,4}\d{4,}|\d{6,})\s*$"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, range: range), match.numberOfRanges >= 2,
                let capture = Range(match.range(at: 1), in: text) {
                let ticket = String(text[capture]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !ticket.isEmpty { return ticket }
            }
        }

        return ""
    }

    private func detectTimeRange(in ocrText: String) -> (inTime: String, outTime: String) {
        guard let regex = try? NSRegularExpression(pattern: #"\b([01]?\d|2[0-3])[:\.]([0-5]\d)\b"#) else {
            return ("", "")
        }
        let text = thaiDigitsToArabic(ocrText)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let times: [String] = regex.matches(in: text, range: range).compactMap { match in
            guard let hourRange = Range(match.range(at: 1), in: text),
                let minuteRange = Range(match.range(at: 2), in: text) else {
                return nil
            }
            let hourValue = Int(String(text[hourRange])) ?? 0
            let hour = String(format: "%02d", hourValue)
            let minute = String(text[minuteRange])
            return "\(hour):\(minute)"
        }

        guard let first = times.first else { return ("", "") }
        return (first, times.count >= 2 ? (times.last ?? first) : first)
    }

    private func plausibleWeight(_ value: Double) -> Bool {
        value > 0 && value < 1_000_000 && value != 2568 && value != 2569 && value != 2570
    }

    private func plausibleTotalWeight(_ value: Double) -> Bool {
        value > 0 && value < 2_000
    }

    private func plausibleTableRowWeight(_ value: Double) -> Bool {
        value > 0 && value <= 120
    }

    private func normalizedWeight(_ value: Double, sourceLine: String) -> Double {
        let usesKilogramUnit = containsAnyKeyword(["kg", "กก"], in: sourceLine)
        let usesTonUnit = containsAnyKeyword(["ตัน", "ton"], in: sourceLine)

        if usesKilogramUnit && !usesTonUnit {
            return value / 1000
        }
        if usesTonUnit {
            return value
        }
        return value >= 1000 ? value / 1000 : value
    }

    private func roundedTon(_ value: Double) -> Double {
        (value * 1000).rounded() / 1000
    }

    private func agencyCoreName(_ text: String) -> String {
        var output = text
        [
            "องค์การบริหารส่วนตำบล",
            "องค์การบริหารส่วนตําบล",
            "เทศบาลตำบล",
            "เทศบาลตําบล",
            "เทศบาลเมือง",
            "เทศบาลนคร",
            "อบต.",
            "อบต",
            "ทต.",
            "ทต",
            "อปท.",
            "อปท",
            "ตำบล",
            "ตําบล",
            "เทศบาล",
            "องค์การบริหารส่วน"
        ].forEach { output = output.replacingOccurrences(of: $0, with: "") }
        return output
    }

    private func agencyMatchKeywords(for customer: Customer) -> [(display: String, normalized: String, relaxed: String)] {
        var raw: [String] = []
        [customer.agencyName, customer.documentName, customer.agencyShort].forEach { text in
            appendUnique(text, to: &raw)
            appendUnique(agencyCoreName(text), to: &raw)
        }

        let genericWords = Set([
            "องค์การบริหารส่วนตำบล", "องค์การบริหารส่วนตําบล", "เทศบาลตำบล", "เทศบาลตําบล",
            "เทศบาลเมือง", "เทศบาลนคร", "องค์การบริหารส่วน", "เทศบาล", "ตำบล", "ตําบล",
            "อบต", "ทต", "อปท"
        ].map { normalizedCheckText($0) })

        return raw.compactMap { text in
            let display = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = normalizedCheckText(display)
            let relaxed = relaxedNormalizedCheckText(display)
            guard normalized.count >= 3, !genericWords.contains(normalized) else {
                return nil
            }
            return (display: display, normalized: normalized, relaxed: relaxed)
        }
    }

    private func appendUnique(_ text: String, to values: inout [String]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !values.contains(trimmed) {
            values.append(trimmed)
        }
    }

    private func relaxedNormalizedCheckText(_ text: String) -> String {
        let normalized = normalizedCheckText(text)
        var output = String.UnicodeScalarView()
        for scalar in normalized.unicodeScalars {
            switch scalar.value {
            case 0x0E31, 0x0E34...0x0E3A, 0x0E47...0x0E4E:
                continue
            default:
                output.append(scalar)
            }
        }
        return String(output)
    }

    private func normalizedCheckText(_ text: String) -> String {
        thaiDigitsToArabic(text)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
            .map(String.init)
            .joined()
    }

    private func thaiDigitsToArabic(_ text: String) -> String {
        let map: [Character: Character] = [
            "๐": "0", "๑": "1", "๒": "2", "๓": "3", "๔": "4",
            "๕": "5", "๖": "6", "๗": "7", "๘": "8", "๙": "9"
        ]
        return String(text.map { map[$0] ?? $0 })
    }

    private func extractNumbers(from text: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: #"(?<!\d)\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?"#) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return Double(text[range].replacingOccurrences(of: ",", with: ""))
        }
    }

    func approveBilling(for customer: Customer, note: String = "ตรวจพรีวิวแล้ว") -> BillingLine {
        var line = billingLine(for: customer)
        line.billingApprovedAt = ThaiDate.nowDateTimeText()
        line.billingApprovalNote = note
        updateBilling(line)
        return line
    }

    func clearBillingApproval(_ line: BillingLine) -> BillingLine {
        var updated = line
        updated.billingApprovedAt = ""
        updated.billingApprovalNote = ""
        return updated
    }

    func lineMessageText(for customer: Customer) -> String {
        let line = billingLine(for: customer)
        let lineId = customer.lineId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "wongsapust" : customer.lineId
        return """
        แจ้งเอกสารจาก บริษัท ธัญญวิชญ์ จำกัด
        ถึง: \(customer.documentName.isEmpty ? customer.agencyName : customer.documentName)
        LINE ID: \(lineId)
        เดือนงาน: \(servicePeriod)
        เอกสาร: ใบแจ้งหนี้ + ใบกำกับภาษี + ใบส่งมอบงาน + ตารางสรุปน้ำหนัก
        ยอดก่อน VAT: \(ThaiFormat.money(line.amountBeforeVAT))
        VAT: \(ThaiFormat.money(line.vatAmount))
        หัก ณ ที่จ่าย: \(ThaiFormat.money(line.withholdingAmount))
        ยอดสุทธิ: \(ThaiFormat.money(line.netAmount))
        เวลาเข้า-ออกใบชั่ง: \(line.weightTimeIn) - \(line.weightTimeOut)
        ส่งเมื่อ: \(ThaiDate.nowDateTimeText())
        """
    }

    func lineShareURL(for customer: Customer) -> URL? {
        let text = lineMessageText(for: customer)
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://line.me/R/share?text=\(encoded)")
    }

    func markLineSent(for customer: Customer) {
        let sentAt = ThaiDate.nowDateTimeText()
        var updated = customer
        if updated.lineId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.lineId = "wongsapust"
        }
        if updated.documentWorkCompletedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.documentWorkCompletedAt = sentAt
        }
        updated.lastLineSentAt = sentAt
        updateCustomer(updated)

        var docs = loadDocumentControls()
        for index in docs.indices where docs[index].customerCode == updated.customerCode {
            docs[index].lineRecipientId = updated.lineId
            docs[index].lineSentAt = sentAt
        }
        saveDocumentControls(docs)
    }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}


struct PDFDocumentFile: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ShareExportPayload: Identifiable {
    let id = UUID()
    let title: String
    let urls: [URL]
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let urls: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension CustomerStore {
    func makeShareExportPayload(title: String, files: [(filename: String, data: Data)]) throws -> ShareExportPayload {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ThanyawitExports", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let urls = try files.map { file in
            let url = folder.appendingPathComponent(file.filename)
            try file.data.write(to: url, options: .atomic)
            return url
        }

        return ShareExportPayload(title: title, urls: urls)
    }
}

extension CustomerStore {
    func pdfForBillingReport() -> Data {
        let title = "รายงานสรุปงวดออกบิล"
        let subtitle = "เดือนงาน: \(servicePeriod)   วันที่เอกสาร: \(documentDate)"
        let lines = customers.map { customer -> String in
            let result = precheck(for: customer)
            let line = billingLine(for: customer)
            return "\(customer.customerCode) | \(customer.agencyName) | ก่อน VAT \(formatNumber(line.amountBeforeVAT)) | VAT \(formatNumber(line.vatAmount)) | WHT \(formatNumber(line.withholdingAmount)) | สุทธิ \(formatNumber(line.netAmount)) | สถานะ \(result.status) | เหตุผล \(result.reasons.joined(separator: ", "))"
        }
        return renderPDF(title: title, subtitle: subtitle, lines: lines)
    }

    func pdfForCustomersReport() -> Data {
        let title = "รายงานฐานข้อมูลลูกค้า"
        let subtitle = "ลูกค้าทั้งหมด \(customers.count) ราย   พร้อมออก \(readyCount) ราย   รอตรวจ \(reviewCount) ราย"
        let lines = customers.map { customer -> String in
            let result = precheck(for: customer)
            return "\(customer.customerCode) | \(customer.agencyName) | ภาษี \(customer.taxId) | สัญญา \(customer.contractNo) | วันที่ \(customer.contractDate) | สถานะ \(result.status) | ขาด \(result.reasons.joined(separator: ", "))"
        }
        return renderPDF(title: title, subtitle: subtitle, lines: lines)
    }

    func renderPDF(title: String, subtitle: String, lines: [String]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let margin: CGFloat = 32
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20)
        ]
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10)
        ]
        let smallBold: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12)
        ]

        func drawHeader(page: Int, in ctx: UIGraphicsPDFRendererContext, y: inout CGFloat) {
            if let logo = UIImage.companyLogo {
                let maxW: CGFloat = 200
                let maxH: CGFloat = 95
                let ratio = min(maxW / logo.size.width, maxH / logo.size.height)
                let drawSize = CGSize(width: logo.size.width * ratio, height: logo.size.height * ratio)
                let logoRect = CGRect(x: margin, y: y, width: drawSize.width, height: drawSize.height)
                logo.draw(in: logoRect)
                y = logoRect.maxY + 10
            } else {
                y += 4
            }

            (title as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 28
            (subtitle as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
            y += 22

            let company = "บริษัท ธัญญวิชญ์ จำกัด"
            (company as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: smallBold)
            y += 18

            let pageText = "หน้า \(page)"
            let size = (pageText as NSString).size(withAttributes: subtitleAttrs)
            (pageText as NSString).draw(at: CGPoint(x: pageRect.width - margin - size.width, y: 18), withAttributes: subtitleAttrs)

            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: margin, y: y + 6))
            linePath.addLine(to: CGPoint(x: pageRect.width - margin, y: y + 6))
            UIColor.systemBlue.setStroke()
            linePath.lineWidth = 1.2
            linePath.stroke()
            y += 16
        }

        return renderer.pdfData { ctx in
            var y: CGFloat = margin
            var page = 1
            ctx.beginPage()
            drawHeader(page: page, in: ctx, y: &y)

            let maxWidth = pageRect.width - (margin * 2)
            for line in lines {
                let ns = line as NSString
                let rect = ns.boundingRect(
                    with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: textAttrs,
                    context: nil
                )

                if y + rect.height + 24 > pageRect.height - margin {
                    page += 1
                    ctx.beginPage()
                    y = margin
                    drawHeader(page: page, in: ctx, y: &y)
                }

                ns.draw(in: CGRect(x: margin, y: y, width: maxWidth, height: rect.height + 4), withAttributes: textAttrs)
                y += rect.height + 10
            }

            let footer = "Exported from ThanyawitCustomer v6 PDF Export"
            (footer as NSString).draw(
                at: CGPoint(x: margin, y: pageRect.height - margin + 4),
                withAttributes: subtitleAttrs
            )
        }
    }
}
