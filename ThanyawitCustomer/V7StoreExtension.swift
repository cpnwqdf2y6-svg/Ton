import Foundation
import UIKit
import UniformTypeIdentifiers

extension CustomerStore {
    private var docControlKey: String { "thanyawit.documentControl.v7" }
    private var whtKey: String { "thanyawit.withholdingTax.v7" }
    private var docSequenceKey: String { "thanyawit.docSequence.v7" }
    private var bundledDocumentTypeLabel: String { "ใบแจ้งหนี้ + ใบกำกับภาษี + ใบส่งมอบงาน + ตารางสรุปน้ำหนัก" }
    private var formPreparedName: String { "วงศพัทธ์ ลาภิศนิรันดร์กูล" }
    private var formReviewerName: String { "วงศพัทธ์ ลาภิศนิรันดร์กูล" }
    private var formApproverName: String { "นางสาวสุกัญญา ศรีเทพ" }

    @discardableResult
    func writeEmergencyExportFiles() -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let folder = documentsURL.appendingPathComponent("ThanyawitEmergencyExport", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            try writeUTF8WithBOM(csvForCustomers(), to: folder.appendingPathComponent("01_customers.csv"))
            try writeUTF8WithBOM(csvForBilling(), to: folder.appendingPathComponent("02_billing.csv"))
            try writeUTF8WithBOM(csvForDocumentControl(), to: folder.appendingPathComponent("03_document_control_post.csv"))
            try writeUTF8WithBOM(csvForWithholdingTax(), to: folder.appendingPathComponent("04_withholding_tax.csv"))

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(customers).write(to: folder.appendingPathComponent("customers_live.json"), options: .atomic)
            try encoder.encode(billing).write(to: folder.appendingPathComponent("billing_live.json"), options: .atomic)
            try encoder.encode(loadDocumentControls()).write(to: folder.appendingPathComponent("document_control_live.json"), options: .atomic)
            try encoder.encode(loadWithholdingRecords()).write(to: folder.appendingPathComponent("withholding_tax_live.json"), options: .atomic)

            try writeUserDefaultsSnapshot(to: folder)

            let summary = [
                "Thanyawit emergency export",
                "customers: \(customers.count)",
                "ready: \(readyCount)",
                "review: \(reviewCount)",
                "service_period: \(servicePeriod)",
                "document_date: \(documentDate)",
                "folder: \(folder.path)"
            ].joined(separator: "\n")
            try summary.write(to: folder.appendingPathComponent("00_README.txt"), atomically: true, encoding: .utf8)

            return folder
        } catch {
            print("Emergency export failed: \(error)")
            return nil
        }
    }

    private func writeUTF8WithBOM(_ text: String, to url: URL) throws {
        try ("\u{FEFF}" + text).write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeUserDefaultsSnapshot(to folder: URL) throws {
        let defaults = UserDefaults.standard.dictionaryRepresentation()
        let keys = defaults.keys
            .filter { $0.hasPrefix("thanyawit.") }
            .sorted()
        var lines: [String] = []

        for key in keys {
            let value = defaults[key]
            if let data = value as? Data {
                let dataURL = folder.appendingPathComponent("userdefaults_\(safeFilename(key)).data")
                try data.write(to: dataURL, options: .atomic)
                lines.append("\(key): Data \(data.count) bytes -> \(dataURL.lastPathComponent)")
            } else {
                lines.append("\(key): \(String(describing: value ?? ""))")
            }
        }

        if lines.isEmpty {
            lines.append("No thanyawit.* UserDefaults keys found.")
        }

        try lines.joined(separator: "\n").write(
            to: folder.appendingPathComponent("userdefaults_summary.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func safeFilename(_ text: String) -> String {
        text.map { character in
            character.isLetter || character.isNumber || character == "." || character == "-" ? character : "_"
        }
        .map(String.init)
        .joined()
    }

    var documentSequence: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: docSequenceKey)
            return value == 0 ? 16 : value
        }
        set {
            UserDefaults.standard.set(newValue, forKey: docSequenceKey)
        }
    }

    private func documentNo(for sequence: Int) -> String {
        let documentDateText = ThaiDate.slashDateText(from: documentDate)
        return "INV NO. \(String(format: "%03d", sequence))/\(documentDateText)"
    }

    private func currentDocumentRunEntries() -> [(customer: Customer, line: BillingLine, documentNo: String)] {
        let selected = selectedReadyCustomersForDocuments()
        let baseSequence = documentSequence
        return selected.enumerated().map { index, item in
            (
                customer: item.0,
                line: item.1,
                documentNo: documentNo(for: baseSequence + index)
            )
        }
    }

    func loadDocumentControls() -> [DocumentControlRecord] {
        guard let data = UserDefaults.standard.data(forKey: docControlKey),
              let items = try? JSONDecoder().decode([DocumentControlRecord].self, from: data) else {
            return []
        }
        return normalizeDocumentControls(items)
    }

    func saveDocumentControls(_ items: [DocumentControlRecord]) {
        let normalized = normalizeDocumentControls(items)
        if let data = try? JSONEncoder().encode(normalized) {
            UserDefaults.standard.set(data, forKey: docControlKey)
        }
    }

    private func normalizeDocumentControls(_ items: [DocumentControlRecord]) -> [DocumentControlRecord] {
        let grouped = Dictionary(grouping: items) { item in
            "\(item.customerCode)|\(item.documentNo)"
        }

        return grouped.values
            .map { group in
                guard let first = group.sorted(by: { $0.createdAt < $1.createdAt }).first else {
                    return DocumentControlRecord(
                        id: UUID().uuidString,
                        documentNo: "",
                        documentType: bundledDocumentTypeLabel,
                        customerCode: "",
                        agencyName: "",
                        createdAt: "",
                        sentDate: "",
                        carrier: "ไปรษณีย์ไทย",
                        trackingNo: "",
                        checkDueDate: "",
                        deliveryStatus: "รอกรอกเลขพัสดุ",
                        deliveryCheckedAt: "",
                        note: ""
                    )
                }

                if group.count == 1 {
                    return first
                }

                let mergedTypes = Array(Set(group.map(\.documentType))).sorted()
                let mergedTracking = group.first(where: { !$0.trackingNo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.trackingNo ?? first.trackingNo
                let mergedStatus = group.first(where: { $0.deliveryStatus != "รอกรอกเลขพัสดุ" })?.deliveryStatus ?? first.deliveryStatus
                let mergedCheckedAt = group.first(where: { !$0.deliveryCheckedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.deliveryCheckedAt ?? first.deliveryCheckedAt
                let mergedOutgoingBookNo = group.first(where: { !$0.outgoingBookNo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.outgoingBookNo ?? first.outgoingBookNo
                let mergedOutgoingDate = group.first(where: { !$0.outgoingDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.outgoingDate ?? first.outgoingDate
                let mergedOutgoingBy = group.first(where: { !$0.outgoingBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.outgoingBy ?? first.outgoingBy
                let mergedReceivedDate = group.first(where: { !$0.receivedDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.receivedDate ?? first.receivedDate
                let mergedReceiverName = group.first(where: { !$0.receiverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.receiverName ?? first.receiverName
                let mergedIncomingBookNo = group.first(where: { !$0.incomingBookNo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.incomingBookNo ?? first.incomingBookNo
                let mergedCopySetNote = group.first(where: { !$0.copySetNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.copySetNote ?? first.copySetNote
                let mergedLineRecipient = group.first(where: { !$0.lineRecipientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.lineRecipientId ?? first.lineRecipientId
                let mergedLineSentAt = group.first(where: { !$0.lineSentAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.lineSentAt ?? first.lineSentAt
                let mergedNote = group.first(where: { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.note ?? first.note

                return DocumentControlRecord(
                    id: first.id,
                    documentNo: first.documentNo,
                    documentType: mergedTypes.count >= 4 ? bundledDocumentTypeLabel : mergedTypes.joined(separator: " + "),
                    customerCode: first.customerCode,
                    agencyName: first.agencyName,
                    createdAt: first.createdAt,
                    sentDate: first.sentDate,
                    carrier: first.carrier,
                    trackingNo: mergedTracking,
                    checkDueDate: first.checkDueDate,
                    deliveryStatus: mergedStatus,
                    deliveryCheckedAt: mergedCheckedAt,
                    outgoingBookNo: mergedOutgoingBookNo,
                    outgoingDate: mergedOutgoingDate,
                    outgoingBy: mergedOutgoingBy,
                    receivedDate: mergedReceivedDate,
                    receiverName: mergedReceiverName,
                    incomingBookNo: mergedIncomingBookNo,
                    copySetNote: mergedCopySetNote,
                    lineRecipientId: mergedLineRecipient,
                    lineSentAt: mergedLineSentAt,
                    note: mergedNote
                )
            }
            .filter { !$0.documentNo.isEmpty || !$0.customerCode.isEmpty || !$0.agencyName.isEmpty }
            .sorted { lhs, rhs in
                if lhs.sentDate == rhs.sentDate {
                    return lhs.documentNo < rhs.documentNo
                }
                return lhs.sentDate > rhs.sentDate
            }
    }

    func loadWithholdingRecords() -> [WithholdingTaxRecord] {
        guard let data = UserDefaults.standard.data(forKey: whtKey),
              let items = try? JSONDecoder().decode([WithholdingTaxRecord].self, from: data) else {
            return []
        }
        return items
    }

    func saveWithholdingRecords(_ items: [WithholdingTaxRecord]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: whtKey)
        }
    }

    func nextDocumentNo() -> String {
        let seq = documentSequence
        documentSequence = seq + 1
        return documentNo(for: seq)
    }

    func selectedReadyCustomersForDocuments() -> [(Customer, BillingLine)] {
        customers.compactMap { customer in
            let line = billingLine(for: customer)
            let result = precheck(for: customer)
            guard line.isSelected, result.isReady else { return nil }
            return (customer, line)
        }
    }

    func registerDocumentControlForCurrentRun() {
        var docs = loadDocumentControls()
        var taxes = loadWithholdingRecords()

        let entries = currentDocumentRunEntries()
        guard !entries.isEmpty else { return }

        for entry in entries {
            docs.append(
                .make(
                    documentNo: entry.documentNo,
                    type: bundledDocumentTypeLabel,
                    customer: entry.customer,
                    sentDate: documentDate,
                    carrier: "ไปรษณีย์ไทย"
                )
            )
            taxes.append(
                .make(
                    customer: entry.customer,
                    line: entry.line,
                    servicePeriod: servicePeriod,
                    documentNo: entry.documentNo
                )
            )
        }

        documentSequence += entries.count
        saveDocumentControls(docs)
        saveWithholdingRecords(taxes)
    }

    func updateDocumentControl(_ record: DocumentControlRecord) {
        var docs = loadDocumentControls()
        if let index = docs.firstIndex(where: { $0.id == record.id }) {
            docs[index] = record
        } else {
            docs.append(record)
        }
        saveDocumentControls(docs)
    }

    func updateWithholdingTax(_ record: WithholdingTaxRecord) {
        var taxes = loadWithholdingRecords()
        if let index = taxes.firstIndex(where: { $0.id == record.id }) {
            taxes[index] = record
        } else {
            taxes.append(record)
        }
        saveWithholdingRecords(taxes)
    }

    func csvForDocumentControl() -> String {
        let header = ["document_no","document_type","customer_code","agency_name","attention_name","agency_address","district_name","tax_id","created_at","sent_date","outgoing_book_no","outgoing_date","outgoing_by","carrier","tracking_no","check_due_date","delivery_status","delivery_checked_at","received_date","receiver_name","incoming_book_no","copy_set_note","line_recipient_id","line_sent_at","note"]
        let customerByCode = Dictionary(uniqueKeysWithValues: customers.map { ($0.customerCode, $0) })
        let rows = loadDocumentControls().map { item in
            let customer = customerByCode[item.customerCode]
            return [
                item.documentNo,
                item.documentType,
                item.customerCode,
                item.agencyName,
                customer?.attentionName ?? "",
                csvSingleLine(customer?.agencyAddress ?? ""),
                customer?.districtName ?? "",
                customer?.taxId ?? "",
                item.createdAt,
                item.sentDate,
                item.outgoingBookNo,
                item.outgoingDate,
                item.outgoingBy,
                item.carrier,
                item.trackingNo,
                item.checkDueDate,
                item.deliveryStatus,
                item.deliveryCheckedAt,
                item.receivedDate,
                item.receiverName,
                item.incomingBookNo,
                item.copySetNote,
                item.lineRecipientId,
                item.lineSentAt,
                item.note
            ]
        }
        return ([header] + rows)
            .map { $0.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",") }
            .joined(separator: "\n")
    }

    private func csvSingleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func csvForWithholdingTax() -> String {
        let header = ["customer_code","agency_name","service_period","document_no","amount_before_vat","withholding_percent","withholding_amount","tax_status","evidence_note"]
        let rows = loadWithholdingRecords().map { item in
            [
                item.customerCode,
                item.agencyName,
                item.servicePeriod,
                item.documentNo,
                formatNumber(item.amountBeforeVAT),
                formatNumber(item.withholdingPercent),
                formatNumber(item.withholdingAmount),
                item.taxStatus,
                item.evidenceNote
            ]
        }
        return ([header] + rows)
            .map { $0.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",") }
            .joined(separator: "\n")
    }


    func documentsNeedingStatusUpdate() -> [DocumentControlRecord] {
        loadDocumentControls().filter { item in
            let status = item.deliveryStatus
            let hasTracking = !item.trackingNo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let isFinal = status.contains("สำเร็จ") ||
                          status.contains("นำจ่าย") ||
                          status.contains("ส่งสำเร็จ") ||
                          status.contains("รับแล้ว") ||
                          status.contains("Delivered") ||
                          status.contains("delivered")
            return hasTracking && !isFinal
        }
    }

    func documentStatusAlertText() -> String {
        let count = documentsNeedingStatusUpdate().count
        if count == 0 {
            return "ไม่มีเอกสารที่ต้องกดอัปเดตสถานะตอนนี้"
        }
        return "มีเอกสาร \(count) รายการที่ต้องกดอัปเดตสถานะ"
    }


    func pdfForInvoiceForms() -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let entries = currentDocumentRunEntries()
        return renderer.pdfData { ctx in
            if entries.isEmpty {
                ctx.beginPage()
                drawCenteredText("ยังไม่มีรายการพร้อมออกใบแจ้งหนี้", atY: 380)
                return
            }
            for entry in entries {
                ctx.beginPage()
                drawInvoiceLikeForm(titleThai: "ใบแจ้งหนี้", titleEN: "INVOICE", customer: entry.customer, line: entry.line, docNo: entry.documentNo, isReceiptTaxInvoice: false, copyLabel: "ต้นฉบับ - สำหรับลูกค้า/หน่วยงาน")
            }
        }
    }

    func pdfForTaxInvoiceForms() -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let entries = currentDocumentRunEntries()
        return renderer.pdfData { ctx in
            if entries.isEmpty {
                ctx.beginPage()
                drawCenteredText("ยังไม่มีรายการพร้อมออกใบกำกับภาษี", atY: 380)
                return
            }
            for entry in entries {
                ctx.beginPage()
                drawInvoiceLikeForm(titleThai: "ใบเสร็จรับเงิน / ใบกำกับภาษี", titleEN: "RECEIPT TAX INVOICE", customer: entry.customer, line: entry.line, docNo: entry.documentNo, isReceiptTaxInvoice: true, copyLabel: "ต้นฉบับ - สำหรับลูกค้า/หน่วยงาน")
            }
        }
    }

    func pdfForDeliveryForms() -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let entries = currentDocumentRunEntries()
        return renderer.pdfData { ctx in
            if entries.isEmpty {
                ctx.beginPage()
                drawCenteredText("ยังไม่มีรายการพร้อมออกใบส่งมอบงาน", atY: 380)
                return
            }
            for entry in entries {
                ctx.beginPage()
                drawDeliveryNote(customer: entry.customer, line: entry.line, docNo: entry.documentNo, copyLabel: "ต้นฉบับ - สำหรับลูกค้า/หน่วยงาน")
            }
        }
    }

    func pdfForWeightSummaryForms() -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let entries = currentDocumentRunEntries()
        return renderer.pdfData { ctx in
            if entries.isEmpty {
                ctx.beginPage()
                drawCenteredText("ยังไม่มีรายการพร้อมออกตารางสรุปน้ำหนัก", atY: 380)
                return
            }
            for entry in entries {
                ctx.beginPage()
                drawWeightSummaryTable(customer: entry.customer, line: entry.line, docNo: entry.documentNo, copyLabel: "ต้นฉบับ - สำหรับลูกค้า/หน่วยงาน")
            }
        }
    }

    func pdfForRealForms() -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let entries = currentDocumentRunEntries()

        return renderer.pdfData { ctx in
            if entries.isEmpty {
                ctx.beginPage()
                drawCenteredText("ยังไม่มีรายการพร้อมออกเอกสาร", atY: 380)
                return
            }

            for entry in entries {
                ctx.beginPage()
                drawInvoiceLikeForm(titleThai: "ใบแจ้งหนี้", titleEN: "INVOICE", customer: entry.customer, line: entry.line, docNo: entry.documentNo, isReceiptTaxInvoice: false, copyLabel: "ต้นฉบับ - สำหรับลูกค้า/หน่วยงาน")
                ctx.beginPage()
                drawInvoiceLikeForm(titleThai: "ใบแจ้งหนี้", titleEN: "INVOICE", customer: entry.customer, line: entry.line, docNo: entry.documentNo, isReceiptTaxInvoice: false, copyLabel: "สำเนา - สำหรับบริษัท")
                ctx.beginPage()
                drawInvoiceLikeForm(titleThai: "ใบเสร็จรับเงิน / ใบกำกับภาษี", titleEN: "RECEIPT TAX INVOICE", customer: entry.customer, line: entry.line, docNo: entry.documentNo, isReceiptTaxInvoice: true, copyLabel: "ต้นฉบับ - สำหรับลูกค้า/หน่วยงาน")
                ctx.beginPage()
                drawInvoiceLikeForm(titleThai: "ใบเสร็จรับเงิน / ใบกำกับภาษี", titleEN: "RECEIPT TAX INVOICE", customer: entry.customer, line: entry.line, docNo: entry.documentNo, isReceiptTaxInvoice: true, copyLabel: "สำเนา - สำหรับบริษัท")
                ctx.beginPage()
                drawDeliveryNote(customer: entry.customer, line: entry.line, docNo: entry.documentNo, copyLabel: "ต้นฉบับ - สำหรับลูกค้า/หน่วยงาน")
                ctx.beginPage()
                drawDeliveryNote(customer: entry.customer, line: entry.line, docNo: entry.documentNo, copyLabel: "สำเนา - สำหรับบริษัท")
                ctx.beginPage()
                drawWeightSummaryTable(customer: entry.customer, line: entry.line, docNo: entry.documentNo, copyLabel: "ต้นฉบับ - สำหรับลูกค้า/หน่วยงาน")
                ctx.beginPage()
                drawWeightSummaryTable(customer: entry.customer, line: entry.line, docNo: entry.documentNo, copyLabel: "สำเนา - สำหรับบริษัท")
            }
        }
    }

    func pdfForTaxTimeline() -> Data {
        let records = loadWithholdingRecords()
        let lines = records.map { item in
            "\(item.servicePeriod) | \(item.agencyName) | \(item.documentNo) | ฐาน \(formatNumber(item.amountBeforeVAT)) | หัก \(formatNumber(item.withholdingAmount)) | \(item.taxStatus) | \(item.evidenceNote)"
        }
        return renderPDF(title: "ตารางหลังบ้าน หัก ณ ที่จ่าย", subtitle: "ใช้เก็บข้อมูลเพื่อขอคืนภาษีและติดตามเอกสารหัก ณ ที่จ่าย", lines: lines.isEmpty ? ["ยังไม่มีข้อมูลภาษี ให้กดสร้างทะเบียนคุมเอกสารจากงวดออกเอกสารก่อน"] : lines)
    }

    func pdfForDocumentControl() -> Data {
        let records = loadDocumentControls()
        let lines = records.map { item in
            "\(item.documentNo) | \(item.documentType) | \(item.agencyName) | เลขหนังสือส่ง \(item.outgoingBookNo) | ส่ง \(item.sentDate) | พัสดุ \(item.trackingNo) | รับเข้า \(item.receivedDate) \(item.incomingBookNo) | LINE \(item.lineRecipientId) \(item.lineSentAt) | \(item.deliveryStatus) | \(item.copySetNote)"
        }
        return renderPDF(title: "ทะเบียนคุมเอกสาร / รับส่งไปรษณีย์", subtitle: "1 อปท. ต่อ 1 ซองและ 1 เลขพัสดุ หลังส่ง 2 วันทำการให้ตรวจสถานะ", lines: lines.isEmpty ? ["ยังไม่มีรายการทะเบียนคุมเอกสาร"] : lines)
    }

    func billingPreviewFiles(for customer: Customer) -> [(filename: String, data: Data)] {
        let line = billingLine(for: customer)
        let docNo = documentNo(for: documentSequence)
        let prefix = customer.customerCode.isEmpty ? "customer" : customer.customerCode
        return [
            ("\(prefix)_invoice_preview.pdf", pdfForSingleBillingDocument(customer: customer, line: line, docNo: docNo, kind: .invoice)),
            ("\(prefix)_tax_invoice_preview.pdf", pdfForSingleBillingDocument(customer: customer, line: line, docNo: docNo, kind: .taxInvoice)),
            ("\(prefix)_delivery_preview.pdf", pdfForSingleBillingDocument(customer: customer, line: line, docNo: docNo, kind: .delivery)),
            ("\(prefix)_weight_summary_preview.pdf", pdfForSingleBillingDocument(customer: customer, line: line, docNo: docNo, kind: .weightSummary))
        ]
    }

    private enum BillingPreviewKind {
        case invoice, taxInvoice, delivery, weightSummary
    }

    private func pdfForSingleBillingDocument(customer: Customer, line: BillingLine, docNo: String, kind: BillingPreviewKind) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            switch kind {
            case .invoice:
                drawInvoiceLikeForm(titleThai: "ใบแจ้งหนี้", titleEN: "INVOICE", customer: customer, line: line, docNo: docNo, isReceiptTaxInvoice: false, copyLabel: "ตัวอย่าง - สำหรับตรวจ")
            case .taxInvoice:
                drawInvoiceLikeForm(titleThai: "ใบเสร็จรับเงิน / ใบกำกับภาษี", titleEN: "RECEIPT TAX INVOICE", customer: customer, line: line, docNo: docNo, isReceiptTaxInvoice: true, copyLabel: "ตัวอย่าง - สำหรับตรวจ")
            case .delivery:
                drawDeliveryNote(customer: customer, line: line, docNo: docNo, copyLabel: "ตัวอย่าง - สำหรับตรวจ")
            case .weightSummary:
                drawWeightSummaryTable(customer: customer, line: line, docNo: docNo, copyLabel: "ตัวอย่าง - สำหรับตรวจ")
            }
        }
    }

    private func drawCompanyHeader() {
        drawCompanyLogo(in: CGRect(x: 48, y: 48, width: 98, height: 48))
        drawText("บริษัท ธัญญวิชญ์ จำกัด (สำนักงานใหญ่)", x: 48, y: 106, w: 286, h: 22, size: 15, bold: true)
        drawText("เลขที่ 77 ม.8 ต.บางยี่รงค์ อ.บางคนที จ.สมุทรสงคราม 75120", x: 48, y: 132, w: 340, h: 20, size: 10.5)
        drawText("เลขประจำตัวผู้เสียภาษี 0755563000935", x: 48, y: 154, w: 300, h: 20, size: 10.5)
    }

    private func drawBlueHeaderBand() {
        UIColor(red: 0.90, green: 0.95, blue: 0.98, alpha: 1).setFill()
        UIBezierPath(rect: CGRect(x: 36, y: 36, width: 523, height: 150)).fill()
        UIColor(red: 0.12, green: 0.36, blue: 0.58, alpha: 1).setStroke()
        let accent = UIBezierPath(rect: CGRect(x: 36, y: 36, width: 523, height: 3))
        accent.lineWidth = 3
        accent.stroke()
    }

    private func drawInvoiceLikeForm(titleThai: String, titleEN: String, customer: Customer, line: BillingLine, docNo: String, isReceiptTaxInvoice: Bool, copyLabel: String) {
        drawBlueHeaderBand()
        drawCompanyHeader()
        drawCopyLabel(copyLabel)

        drawText(titleThai, x: 350, y: 60, w: 180, h: 28, size: 20, bold: true, align: .center, color: .systemBlue)
        drawText(titleEN, x: 350, y: 90, w: 180, h: 20, size: 12, bold: true, align: .center, color: .systemBlue)
        drawText("เล่มที่ 01", x: 350, y: 120, w: 180, h: 18, size: 11)
        drawText("เลขที่ / \(docNo)", x: 350, y: 142, w: 180, h: 18, size: 11)
        drawText("วันที่ : \(documentDate)", x: 350, y: 164, w: 180, h: 18, size: 11)

        strokeRect(CGRect(x: 36, y: 200, width: 523, height: 78))
        drawText("ชื่อ - ที่อยู่ลูกค้า (Customer)", x: 42, y: 204, w: 230, h: 18, size: 11, bold: true)
        drawText(customer.documentName.isEmpty ? customer.agencyName : customer.documentName, x: 86, y: 226, w: 420, h: 18, size: 12, bold: true)
        drawText(customer.agencyAddress, x: 86, y: 244, w: 430, h: 18, size: 11)
        drawText("เลขประจำตัวผู้เสียภาษี: \(customer.taxId)", x: 86, y: 258, w: 240, h: 16, size: 10)

        let tableY: CGFloat = 314
        strokeRect(CGRect(x: 36, y: tableY, width: 523, height: 210))
        drawLine(x1: 36, y1: tableY + 34, x2: 559, y2: tableY + 34)
        drawLine(x1: 92, y1: tableY, x2: 92, y2: tableY + 210)
        drawLine(x1: 300, y1: tableY, x2: 300, y2: tableY + 210)
        drawLine(x1: 380, y1: tableY, x2: 380, y2: tableY + 210)
        drawLine(x1: 455, y1: tableY, x2: 455, y2: tableY + 210)

        drawText("ลำดับ\nITEM", x: 42, y: tableY + 6, w: 48, h: 30, size: 10, align: .center)
        drawText("รายละเอียด\nDESCRIPTION", x: 104, y: tableY + 6, w: 180, h: 30, size: 10, align: .center)
        drawText("จำนวน\nQUANTITY", x: 305, y: tableY + 6, w: 68, h: 30, size: 10, align: .center)
        drawText("ราคาต่อหน่วย\nUNIT PRICE", x: 385, y: tableY + 6, w: 66, h: 30, size: 10, align: .center)
        drawText("จำนวนเงินรวม\nTOTAL AMOUNT", x: 462, y: tableY + 6, w: 88, h: 30, size: 10, align: .center)

        drawText("1", x: 42, y: tableY + 60, w: 40, h: 20, size: 11, align: .center)
        let desc = "ค่าจ้างเหมาจัดเก็บและกำจัดขยะมูลฝอย\n\(customer.agencyName)\nงวดประจำเดือน \(servicePeriod)"
        drawText(desc, x: 110, y: tableY + 54, w: 180, h: 90, size: 12, align: .center)
        drawText(ThaiFormat.plain(line.weight), x: 306, y: tableY + 60, w: 68, h: 20, size: 12, bold: true, align: .center)
        drawText(ThaiFormat.money(line.unitRate), x: 386, y: tableY + 60, w: 66, h: 20, size: 12, bold: true, align: .center)
        drawText(ThaiFormat.money(line.amountBeforeVAT), x: 462, y: tableY + 60, w: 88, h: 20, size: 12, bold: true, align: .right)

        let grandTotal = line.amountBeforeVAT + line.vatAmount
        let totalY: CGFloat = 540
        drawText("จำนวนเงินรวม / TOTAL AMOUNT", x: 250, y: totalY, w: 200, h: 20, size: 12, align: .right)
        drawText(ThaiFormat.money(line.amountBeforeVAT), x: 462, y: totalY, w: 92, h: 20, size: 13, bold: true, align: .right)
        drawText("ภาษีมูลค่าเพิ่ม / VALUE ADDED TAX", x: 225, y: totalY + 26, w: 225, h: 20, size: 12, align: .right)
        drawText(ThaiFormat.money(line.vatAmount), x: 462, y: totalY + 26, w: 92, h: 20, size: 13, bold: true, align: .right)
        drawText("รวมเป็นเงิน / GRAND TOTAL", x: 255, y: totalY + 52, w: 195, h: 20, size: 12, bold: true, align: .right)
        drawText(ThaiFormat.money(grandTotal), x: 462, y: totalY + 52, w: 92, h: 20, size: 13, bold: true, align: .right)
        drawText("หัก ณ ที่จ่าย / WITHHOLDING TAX", x: 220, y: totalY + 78, w: 230, h: 20, size: 12, align: .right)
        drawText(ThaiFormat.money(line.withholdingAmount), x: 462, y: totalY + 78, w: 92, h: 20, size: 13, bold: true, align: .right)
        drawText("รับชำระสุทธิ / NET PAYABLE", x: 245, y: totalY + 104, w: 205, h: 20, size: 12, bold: true, align: .right)
        drawText(ThaiFormat.money(line.netAmount), x: 462, y: totalY + 104, w: 92, h: 20, size: 13, bold: true, align: .right)

        strokeRect(CGRect(x: 36, y: totalY - 8, width: 523, height: 132))
        drawLine(x1: 455, y1: totalY - 8, x2: 455, y2: totalY + 124)
        drawLine(x1: 455, y1: totalY + 18, x2: 559, y2: totalY + 18)
        drawLine(x1: 455, y1: totalY + 44, x2: 559, y2: totalY + 44)
        drawLine(x1: 455, y1: totalY + 70, x2: 559, y2: totalY + 70)
        drawLine(x1: 455, y1: totalY + 96, x2: 559, y2: totalY + 96)

        UIColor(red: 0.90, green: 0.95, blue: 0.98, alpha: 1).setFill()
        UIBezierPath(rect: CGRect(x: 36, y: 692, width: 250, height: 26)).fill()
        strokeRect(CGRect(x: 36, y: 692, width: 250, height: 26))
        drawText(isReceiptTaxInvoice ? "ใช้เป็นหลักฐานวางบิลและรับเงิน" : "ใช้เป็นหลักฐานวางบิล", x: 52, y: 698, w: 220, h: 16, size: 11)

        drawSignoffSection(y: 718)
        drawDocumentControlFooter(kindCode: isReceiptTaxInvoice ? "TAX" : "INV", docNo: docNo, copyLabel: copyLabel)
    }

    private func drawDeliveryNote(customer: Customer, line: BillingLine, docNo: String, copyLabel: String) {
        drawDeliveryHeaderBand()
        drawCopyLabel(copyLabel)
        drawText("ใบส่งมอบงานจ้าง", x: 220, y: 70, w: 160, h: 26, size: 18, bold: true, align: .center)
        drawText("เลขที่ \(docNo)", x: 360, y: 72, w: 170, h: 18, size: 10, align: .right)
        drawCompanyLogo(in: CGRect(x: 70, y: 108, width: 92, height: 50))

        drawText("บริษัท ธัญญวิชญ์ จำกัด", x: 350, y: 105, w: 160, h: 22, size: 14, bold: true, align: .center)
        drawText("77 ม.8 ต.บางยี่รงค์ อ.บางคนที", x: 325, y: 140, w: 210, h: 18, size: 12, align: .center)
        drawText("จ.สมุทรสงคราม 75120", x: 325, y: 170, w: 210, h: 18, size: 12, align: .center)

        drawText(documentDate, x: 260, y: 225, w: 150, h: 20, size: 12)
        drawText("เรื่อง ขอส่งมอบงานจ้าง", x: 70, y: 270, w: 200, h: 20, size: 13, bold: true)
        drawText("เรียน นายกเทศมนตรี\(customer.agencyName)", x: 70, y: 305, w: 360, h: 20, size: 13)

        let body = "ตามที่ \(customer.agencyName) ได้ทำการจ้างเหมางานกับ บริษัท ธัญญวิชญ์ จำกัด ให้ทำการกำจัดขยะมูลฝอย ในเขตพื้นที่ \(customer.agencyName) ประจำเดือน \(servicePeriod) ตามสัญญาจ้างเลขที่ \(customer.contractNo) ลงวันที่ \(customer.contractDate) วงเงินค่าจ้าง \(ThaiFormat.money(line.amountBeforeVAT)) บาท บัดนี้ ผู้รับจ้างได้ดำเนินการดังกล่าวแล้วเสร็จเป็นที่เรียบร้อย ตามรูปแบบสัญญาจ้างทุกประการ จึงเรียนมาเพื่อขอส่งมอบงานดังกล่าว และขอรับเงินตามสัญญาจ้าง"
        drawText(body, x: 70, y: 350, w: 455, h: 140, size: 13, lineSpacing: 8)

        drawText("ขอแสดงความนับถือ", x: 365, y: 570, w: 130, h: 20, size: 13, align: .center)
        drawSignoffSection(y: 620)
        drawDocumentControlFooter(kindCode: "DEL", docNo: docNo, copyLabel: copyLabel)
    }

    private func drawWeightSummaryTable(customer: Customer, line: BillingLine, docNo: String, copyLabel: String) {
        drawBlueHeaderBand()
        drawCompanyHeader()
        drawCopyLabel(copyLabel)

        drawText("ตารางสรุปน้ำหนัก", x: 336, y: 62, w: 220, h: 28, size: 20, bold: true, align: .center, color: .systemBlue)
        drawText("WEIGHT SUMMARY", x: 336, y: 92, w: 220, h: 20, size: 12, bold: true, align: .center, color: .systemBlue)
        drawText("เลขที่อ้างอิง \(docNo)", x: 336, y: 120, w: 220, h: 18, size: 11, align: .center)
        drawText("วันที่เอกสาร : \(documentDate)", x: 336, y: 142, w: 220, h: 18, size: 11, align: .center)

        strokeRect(CGRect(x: 36, y: 202, width: 523, height: 70))
        drawText("หน่วยงาน", x: 48, y: 212, w: 80, h: 20, size: 11, bold: true)
        drawText(customer.agencyName, x: 132, y: 212, w: 390, h: 20, size: 12, bold: true)
        drawText("เดือนงาน", x: 48, y: 236, w: 80, h: 18, size: 11, bold: true)
        drawText(servicePeriod, x: 132, y: 236, w: 210, h: 18, size: 11)
        drawText("เลขใบชั่ง", x: 350, y: 236, w: 70, h: 18, size: 11, bold: true)
        drawText(line.slipTicketNo.isEmpty ? "-" : line.slipTicketNo, x: 420, y: 236, w: 120, h: 18, size: 11)

        let tableY: CGFloat = 292
        strokeRect(CGRect(x: 36, y: tableY, width: 523, height: 300))
        drawLine(x1: 36, y1: tableY + 34, x2: 559, y2: tableY + 34)
        drawLine(x1: 86, y1: tableY, x2: 86, y2: tableY + 300)
        drawLine(x1: 286, y1: tableY, x2: 286, y2: tableY + 300)
        drawLine(x1: 432, y1: tableY, x2: 432, y2: tableY + 300)

        drawText("ลำดับ", x: 42, y: tableY + 8, w: 40, h: 20, size: 10, align: .center)
        drawText("รายการ", x: 90, y: tableY + 8, w: 188, h: 20, size: 10, align: .center)
        drawText("ข้อมูล", x: 290, y: tableY + 8, w: 138, h: 20, size: 10, align: .center)
        drawText("หมายเหตุ", x: 436, y: tableY + 8, w: 118, h: 20, size: 10, align: .center)

        let rows: [(String, String, String, String)] = [
            ("1", "เวลาเข้า", line.weightTimeIn.isEmpty ? "-" : line.weightTimeIn, "จาก OCR/ผู้กรอก"),
            ("2", "เวลาออก", line.weightTimeOut.isEmpty ? "-" : line.weightTimeOut, "จาก OCR/ผู้กรอก"),
            ("3", "น้ำหนักจากตาราง (ตัน)", line.weightTonFromTable > 0 ? ThaiFormat.plain(line.weightTonFromTable) : "-", "ใช้เป็นค่าจริงของบิล"),
            ("4", "ยอดรวม OCR (ตัน)", line.ocrTotalTon > 0 ? ThaiFormat.plain(line.ocrTotalTon) : "-", "ใช้เพื่อเทียบความถูกต้อง"),
            ("5", "ตารางน้ำหนักผ่าน/ไม่ผ่าน", line.weightSlipTotalWeightMatched ? "ผ่าน" : "ไม่ผ่าน", line.weightSlipWeightCheckNote),
            ("6", "ตรวจชื่อ อปท.", line.weightSlipAgencyMatched ? "ตรง" : "ไม่ตรง", line.weightSlipAgencyCheckNote),
            ("7", "หลักฐานไฟล์", line.weightSlipSourceFilename.isEmpty ? "-" : line.weightSlipSourceFilename, line.weightSlipConfirmedAt),
            ("8", "หมายเหตุหลักฐาน", line.weightEvidenceNote.isEmpty ? "-" : line.weightEvidenceNote, "")
        ]

        var rowY = tableY + 40
        for row in rows {
            drawLine(x1: 36, y1: rowY + 30, x2: 559, y2: rowY + 30)
            drawText(row.0, x: 42, y: rowY + 7, w: 40, h: 22, size: 11, align: .center)
            drawText(row.1, x: 92, y: rowY + 7, w: 188, h: 22, size: 11)
            drawText(row.2, x: 292, y: rowY + 7, w: 136, h: 22, size: 11)
            drawText(row.3, x: 436, y: rowY + 7, w: 116, h: 22, size: 9.5, color: .darkGray)
            rowY += 30
        }

        drawSignoffSection(y: 628)
        drawDocumentControlFooter(kindCode: "WGT", docNo: docNo, copyLabel: copyLabel)
    }

    private func drawDeliveryHeaderBand() {
        UIColor(red: 0.96, green: 0.98, blue: 0.99, alpha: 1).setFill()
        UIBezierPath(rect: CGRect(x: 36, y: 36, width: 523, height: 160)).fill()
        UIColor(red: 0.12, green: 0.36, blue: 0.58, alpha: 1).setStroke()
        let topLine = UIBezierPath(rect: CGRect(x: 36, y: 36, width: 523, height: 3))
        topLine.lineWidth = 3
        topLine.stroke()
        strokeRect(CGRect(x: 36, y: 36, width: 523, height: 160), color: UIColor(red: 0.72, green: 0.82, blue: 0.88, alpha: 1), lineWidth: 0.8)
    }

    private func drawCompanyLogo(in maxRect: CGRect) {
        guard let logo = UIImage.companyLogo, logo.size.width > 0, logo.size.height > 0 else { return }
        let ratio = min(maxRect.width / logo.size.width, maxRect.height / logo.size.height)
        let drawSize = CGSize(width: logo.size.width * ratio, height: logo.size.height * ratio)
        let drawRect = CGRect(
            x: maxRect.midX - drawSize.width / 2,
            y: maxRect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        logo.draw(in: drawRect)
    }

    private func drawSignoffSection(y: CGFloat) {
        drawRoleBlock(x: 42, y: y, width: 160, signerName: formPreparedName, role: "ผู้พิมพ์")
        drawRoleBlock(x: 218, y: y, width: 160, signerName: formReviewerName, role: "ผู้ตรวจทาน")
        drawRoleBlock(x: 394, y: y, width: 160, signerName: formApproverName, role: "ผู้อนุมัติ")
    }

    private func drawRoleBlock(x: CGFloat, y: CGFloat, width: CGFloat, signerName: String, role: String) {
        drawText("..........................................", x: x, y: y, w: width, h: 18, size: 10.5, align: .center)
        drawText("(\(signerName))", x: x, y: y + 18, w: width, h: 18, size: 9.5, align: .center)
        drawText(role, x: x, y: y + 36, w: width, h: 16, size: 9.5, bold: true, align: .center)
        drawText("วันที่ \(documentDate)", x: x, y: y + 54, w: width, h: 14, size: 8.5, align: .center)
    }

    private func drawDocumentControlFooter(kindCode: String, docNo: String, copyLabel: String) {
        UIColor(white: 0.55, alpha: 1).setStroke()
        let line = UIBezierPath()
        line.move(to: CGPoint(x: 36, y: 816))
        line.addLine(to: CGPoint(x: 559, y: 816))
        line.lineWidth = 0.5
        line.stroke()

        let controlCode = "TW-\(kindCode)-\(sanitizedControlCodePart(docNo))-\(copyCode(for: copyLabel))"
        drawText("รหัสควบคุมเอกสาร: \(controlCode) | Rev.01 | วันที่เอกสาร: \(documentDate)", x: 42, y: 820, w: 360, h: 12, size: 7.5, color: .darkGray)
        drawText("เอกสารควบคุมภายในบริษัท", x: 402, y: 820, w: 150, h: 12, size: 7.5, align: .right, color: .darkGray)
    }

    private func sanitizedControlCodePart(_ text: String) -> String {
        text
            .replacingOccurrences(of: "INV NO.", with: "")
            .replacingOccurrences(of: " ", with: "")
            .map { character in
                character.isLetter || character.isNumber ? String(character) : "-"
            }
            .joined()
    }

    private func copyCode(for label: String) -> String {
        if label.contains("ตัวอย่าง") { return "PREVIEW" }
        if label.contains("สำเนา") { return "COPY" }
        return "ORIGINAL"
    }

    private func drawText(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, size: CGFloat, bold: Bool = false, align: NSTextAlignment = .left, color: UIColor = .black, lineSpacing: CGFloat = 2) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = align
        paragraph.lineSpacing = lineSpacing
        let attrs: [NSAttributedString.Key: Any] = [
            .font: formFont(size: size, bold: bold),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        (text as NSString).draw(in: CGRect(x: x, y: y, width: w, height: h), withAttributes: attrs)
    }

    private func drawCopyLabel(_ text: String) {
        UIColor(red: 0.12, green: 0.36, blue: 0.58, alpha: 1).setFill()
        UIBezierPath(roundedRect: CGRect(x: 380, y: 28, width: 170, height: 22), cornerRadius: 6).fill()
        drawText(text, x: 386, y: 32, w: 158, h: 14, size: 9, bold: true, align: .center, color: .white)
    }

    private func formFont(size: CGFloat, bold: Bool) -> UIFont {
        let preferredNames = bold
            ? ["Thonburi-Bold", "HelveticaNeue-Medium"]
            : ["Thonburi", "HelveticaNeue"]
        for name in preferredNames {
            if let font = UIFont(name: name, size: size) {
                return font
            }
        }
        return bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
    }

    private func drawCenteredText(_ text: String, atY y: CGFloat) {
        drawText(text, x: 60, y: y, w: 475, h: 40, size: 16, bold: true, align: .center)
    }

    private func strokeRect(_ rect: CGRect) {
        strokeRect(rect, color: .black, lineWidth: 1)
    }

    private func strokeRect(_ rect: CGRect, color: UIColor, lineWidth: CGFloat) {
        color.setStroke()
        let path = UIBezierPath(rect: rect)
        path.lineWidth = lineWidth
        path.stroke()
    }

    private func drawLine(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) {
        UIColor.black.setStroke()
        let p = UIBezierPath()
        p.move(to: CGPoint(x: x1, y: y1))
        p.addLine(to: CGPoint(x: x2, y: y2))
        p.lineWidth = 1
        p.stroke()
    }
}
