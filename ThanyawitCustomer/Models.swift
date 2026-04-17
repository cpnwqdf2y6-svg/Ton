import Foundation

struct Customer: Identifiable, Codable, Hashable {
    var id: String
    var customerCode: String
    var agencyName: String
    var agencyShort: String
    var agencyType: String
    var customerGroup: String
    var districtName: String
    var provinceName: String
    var procurementMethod: String
    var projectType: String
    var taxId: String
    var contractNo: String
    var contractDate: String
    var projectNo: String
    var documentName: String
    var attentionName: String
    var agencyAddress: String
    var baseRevenue2569: Double
    var baseWeight2569: Double
    var unitRateDefault: Double
    var vatPercent: Double
    var whtPercent: Double
    var readiness: String
    var missingItems: [String]
    var internalNote: String
    var lineId: String
    var documentWorkCompletedAt: String
    var lastLineSentAt: String

    enum CodingKeys: String, CodingKey {
        case id, customerCode, agencyName, agencyShort, agencyType, customerGroup, districtName, provinceName
        case procurementMethod, projectType, taxId, contractNo, contractDate, projectNo, documentName
        case attentionName, agencyAddress, baseRevenue2569, baseWeight2569, unitRateDefault, vatPercent
        case whtPercent, readiness, missingItems, internalNote, lineId, documentWorkCompletedAt, lastLineSentAt
    }

    init(
        id: String,
        customerCode: String,
        agencyName: String,
        agencyShort: String,
        agencyType: String,
        customerGroup: String,
        districtName: String,
        provinceName: String,
        procurementMethod: String,
        projectType: String,
        taxId: String,
        contractNo: String,
        contractDate: String,
        projectNo: String,
        documentName: String,
        attentionName: String,
        agencyAddress: String,
        baseRevenue2569: Double,
        baseWeight2569: Double,
        unitRateDefault: Double,
        vatPercent: Double,
        whtPercent: Double,
        readiness: String,
        missingItems: [String],
        internalNote: String,
        lineId: String = "wongsapust",
        documentWorkCompletedAt: String = "",
        lastLineSentAt: String = ""
    ) {
        self.id = id
        self.customerCode = customerCode
        self.agencyName = agencyName
        self.agencyShort = agencyShort
        self.agencyType = agencyType
        self.customerGroup = customerGroup
        self.districtName = districtName
        self.provinceName = provinceName
        self.procurementMethod = procurementMethod
        self.projectType = projectType
        self.taxId = taxId
        self.contractNo = contractNo
        self.contractDate = contractDate
        self.projectNo = projectNo
        self.documentName = documentName
        self.attentionName = attentionName
        self.agencyAddress = agencyAddress
        self.baseRevenue2569 = baseRevenue2569
        self.baseWeight2569 = baseWeight2569
        self.unitRateDefault = unitRateDefault
        self.vatPercent = vatPercent
        self.whtPercent = whtPercent
        self.readiness = readiness
        self.missingItems = missingItems
        self.internalNote = internalNote
        self.lineId = lineId
        self.documentWorkCompletedAt = documentWorkCompletedAt
        self.lastLineSentAt = lastLineSentAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        customerCode = try c.decodeIfPresent(String.self, forKey: .customerCode) ?? id
        agencyName = try c.decodeIfPresent(String.self, forKey: .agencyName) ?? ""
        agencyShort = try c.decodeIfPresent(String.self, forKey: .agencyShort) ?? agencyName
        agencyType = try c.decodeIfPresent(String.self, forKey: .agencyType) ?? ""
        customerGroup = try c.decodeIfPresent(String.self, forKey: .customerGroup) ?? ""
        districtName = try c.decodeIfPresent(String.self, forKey: .districtName) ?? ""
        provinceName = try c.decodeIfPresent(String.self, forKey: .provinceName) ?? ""
        procurementMethod = try c.decodeIfPresent(String.self, forKey: .procurementMethod) ?? ""
        projectType = try c.decodeIfPresent(String.self, forKey: .projectType) ?? ""
        taxId = try c.decodeIfPresent(String.self, forKey: .taxId) ?? ""
        contractNo = try c.decodeIfPresent(String.self, forKey: .contractNo) ?? ""
        contractDate = try c.decodeIfPresent(String.self, forKey: .contractDate) ?? ""
        projectNo = try c.decodeIfPresent(String.self, forKey: .projectNo) ?? ""
        documentName = try c.decodeIfPresent(String.self, forKey: .documentName) ?? agencyName
        attentionName = try c.decodeIfPresent(String.self, forKey: .attentionName) ?? ""
        agencyAddress = try c.decodeIfPresent(String.self, forKey: .agencyAddress) ?? ""
        baseRevenue2569 = try c.decodeIfPresent(Double.self, forKey: .baseRevenue2569) ?? 0
        baseWeight2569 = try c.decodeIfPresent(Double.self, forKey: .baseWeight2569) ?? 0
        unitRateDefault = try c.decodeIfPresent(Double.self, forKey: .unitRateDefault) ?? 0
        vatPercent = try c.decodeIfPresent(Double.self, forKey: .vatPercent) ?? 7
        whtPercent = try c.decodeIfPresent(Double.self, forKey: .whtPercent) ?? 1
        readiness = try c.decodeIfPresent(String.self, forKey: .readiness) ?? "รอตรวจ"
        missingItems = try c.decodeIfPresent([String].self, forKey: .missingItems) ?? []
        internalNote = try c.decodeIfPresent(String.self, forKey: .internalNote) ?? ""
        lineId = try c.decodeIfPresent(String.self, forKey: .lineId) ?? "wongsapust"
        documentWorkCompletedAt = try c.decodeIfPresent(String.self, forKey: .documentWorkCompletedAt) ?? ""
        lastLineSentAt = try c.decodeIfPresent(String.self, forKey: .lastLineSentAt) ?? ""
    }

    static func blank(nextCode: String) -> Customer {
        Customer(
            id: nextCode,
            customerCode: nextCode,
            agencyName: "",
            agencyShort: "",
            agencyType: "อบต.",
            customerGroup: "จ้างขน",
            districtName: "",
            provinceName: "ราชบุรี",
            procurementMethod: "e-bidding",
            projectType: "",
            taxId: "",
            contractNo: "",
            contractDate: "",
            projectNo: "",
            documentName: "",
            attentionName: "",
            agencyAddress: "",
            baseRevenue2569: 0,
            baseWeight2569: 0,
            unitRateDefault: 0,
            vatPercent: 7,
            whtPercent: 1,
            readiness: "รอตรวจ",
            missingItems: [],
            internalNote: "",
            lineId: "wongsapust",
            documentWorkCompletedAt: "",
            lastLineSentAt: ""
        )
    }
}

struct BillingLine: Identifiable, Codable, Hashable {
    var id: String
    var isSelected: Bool = true
    var weight: Double = 0
    var unitRate: Double = 0
    var amountBeforeVAT: Double = 0
    var vatPercent: Double = 7
    var withholdingPercent: Double = 1
    var note: String = ""
    var weightSlipSourceFilename: String = ""
    var weightSlipImageFilename: String = ""
    var weightSlipConfirmedAt: String = ""
    var weightEvidenceNote: String = ""
    var slipTicketNo: String = ""
    var weightTimeIn: String = ""
    var weightTimeOut: String = ""
    var weightSlipOCRText: String = ""
    var weightSlipOCRCheckedAt: String = ""
    var weightSlipAgencyMatched: Bool = false
    var weightSlipTotalWeightMatched: Bool = false
    var weightSlipAgencyCheckNote: String = ""
    var weightSlipWeightCheckNote: String = ""
    var weightTonFromTable: Double = 0
    var ocrTotalTon: Double = 0
    var ocrDetectedWeight: Double = 0
    var billingApprovedAt: String = ""
    var billingApprovalNote: String = ""

    enum CodingKeys: String, CodingKey {
        case id, isSelected, weight, unitRate, amountBeforeVAT, vatPercent, withholdingPercent, note
        case weightSlipSourceFilename, weightSlipImageFilename, weightSlipConfirmedAt, weightEvidenceNote
        case slipTicketNo, weightTimeIn, weightTimeOut
        case weightSlipOCRText, weightSlipOCRCheckedAt, weightSlipAgencyMatched, weightSlipTotalWeightMatched
        case weightSlipAgencyCheckNote, weightSlipWeightCheckNote
        case weightTonFromTable, ocrTotalTon
        case ocrDetectedWeight, billingApprovedAt, billingApprovalNote
    }

    init(
        id: String,
        isSelected: Bool = true,
        weight: Double = 0,
        unitRate: Double = 0,
        amountBeforeVAT: Double = 0,
        vatPercent: Double = 7,
        withholdingPercent: Double = 1,
        note: String = "",
        weightSlipSourceFilename: String = "",
        weightSlipImageFilename: String = "",
        weightSlipConfirmedAt: String = "",
        weightEvidenceNote: String = "",
        slipTicketNo: String = "",
        weightTimeIn: String = "",
        weightTimeOut: String = "",
        weightSlipOCRText: String = "",
        weightSlipOCRCheckedAt: String = "",
        weightSlipAgencyMatched: Bool = false,
        weightSlipTotalWeightMatched: Bool = false,
        weightSlipAgencyCheckNote: String = "",
        weightSlipWeightCheckNote: String = "",
        weightTonFromTable: Double = 0,
        ocrTotalTon: Double = 0,
        ocrDetectedWeight: Double = 0,
        billingApprovedAt: String = "",
        billingApprovalNote: String = ""
    ) {
        self.id = id
        self.isSelected = isSelected
        self.weight = weight
        self.unitRate = unitRate
        self.amountBeforeVAT = amountBeforeVAT
        self.vatPercent = vatPercent
        self.withholdingPercent = withholdingPercent
        self.note = note
        self.weightSlipSourceFilename = weightSlipSourceFilename
        self.weightSlipImageFilename = weightSlipImageFilename
        self.weightSlipConfirmedAt = weightSlipConfirmedAt
        self.weightEvidenceNote = weightEvidenceNote
        self.slipTicketNo = slipTicketNo
        self.weightTimeIn = weightTimeIn
        self.weightTimeOut = weightTimeOut
        self.weightSlipOCRText = weightSlipOCRText
        self.weightSlipOCRCheckedAt = weightSlipOCRCheckedAt
        self.weightSlipAgencyMatched = weightSlipAgencyMatched
        self.weightSlipTotalWeightMatched = weightSlipTotalWeightMatched
        self.weightSlipAgencyCheckNote = weightSlipAgencyCheckNote
        self.weightSlipWeightCheckNote = weightSlipWeightCheckNote
        self.weightTonFromTable = weightTonFromTable
        self.ocrTotalTon = ocrTotalTon
        self.ocrDetectedWeight = ocrDetectedWeight
        self.billingApprovedAt = billingApprovedAt
        self.billingApprovalNote = billingApprovalNote
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        isSelected = try c.decodeIfPresent(Bool.self, forKey: .isSelected) ?? true
        weight = try c.decodeIfPresent(Double.self, forKey: .weight) ?? 0
        unitRate = try c.decodeIfPresent(Double.self, forKey: .unitRate) ?? 0
        amountBeforeVAT = try c.decodeIfPresent(Double.self, forKey: .amountBeforeVAT) ?? 0
        vatPercent = try c.decodeIfPresent(Double.self, forKey: .vatPercent) ?? 7
        withholdingPercent = try c.decodeIfPresent(Double.self, forKey: .withholdingPercent) ?? 1
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        weightSlipSourceFilename = try c.decodeIfPresent(String.self, forKey: .weightSlipSourceFilename) ?? ""
        weightSlipImageFilename = try c.decodeIfPresent(String.self, forKey: .weightSlipImageFilename) ?? ""
        weightSlipConfirmedAt = try c.decodeIfPresent(String.self, forKey: .weightSlipConfirmedAt) ?? ""
        weightEvidenceNote = try c.decodeIfPresent(String.self, forKey: .weightEvidenceNote) ?? ""
        slipTicketNo = try c.decodeIfPresent(String.self, forKey: .slipTicketNo) ?? ""
        weightTimeIn = try c.decodeIfPresent(String.self, forKey: .weightTimeIn) ?? ""
        weightTimeOut = try c.decodeIfPresent(String.self, forKey: .weightTimeOut) ?? ""
        weightSlipOCRText = try c.decodeIfPresent(String.self, forKey: .weightSlipOCRText) ?? ""
        weightSlipOCRCheckedAt = try c.decodeIfPresent(String.self, forKey: .weightSlipOCRCheckedAt) ?? ""
        weightSlipAgencyMatched = try c.decodeIfPresent(Bool.self, forKey: .weightSlipAgencyMatched) ?? false
        weightSlipTotalWeightMatched = try c.decodeIfPresent(Bool.self, forKey: .weightSlipTotalWeightMatched) ?? false
        weightSlipAgencyCheckNote = try c.decodeIfPresent(String.self, forKey: .weightSlipAgencyCheckNote) ?? ""
        weightSlipWeightCheckNote = try c.decodeIfPresent(String.self, forKey: .weightSlipWeightCheckNote) ?? ""
        weightTonFromTable = try c.decodeIfPresent(Double.self, forKey: .weightTonFromTable) ?? weight
        let decodedOCRTotal = try c.decodeIfPresent(Double.self, forKey: .ocrTotalTon)
        let legacyOCR = try c.decodeIfPresent(Double.self, forKey: .ocrDetectedWeight) ?? 0
        ocrTotalTon = decodedOCRTotal ?? legacyOCR
        ocrDetectedWeight = legacyOCR == 0 ? ocrTotalTon : legacyOCR
        billingApprovedAt = try c.decodeIfPresent(String.self, forKey: .billingApprovedAt) ?? ""
        billingApprovalNote = try c.decodeIfPresent(String.self, forKey: .billingApprovalNote) ?? ""
    }

    var vatAmount: Double {
        amountBeforeVAT * vatPercent / 100
    }

    var withholdingAmount: Double {
        amountBeforeVAT * withholdingPercent / 100
    }

    var netAmount: Double {
        amountBeforeVAT + vatAmount - withholdingAmount
    }
}

struct MonthlyProfitRecord: Identifiable, Codable, Hashable {
    var id: String
    var servicePeriod: String
    var recordedAt: String
    var salesBeforeVAT: Double
    var vatAmount: Double
    var withholdingAmount: Double
    var netReceipt: Double
    var costAmount: Double
    var profitAmount: Double
    var totalWeight: Double
    var readyDocuments: Int

    var profitMargin: Double {
        guard salesBeforeVAT > 0 else { return 0 }
        return profitAmount / salesBeforeVAT * 100
    }
}

struct PrecheckResult: Identifiable, Hashable {
    let id: String
    let customer: Customer
    let billing: BillingLine
    let status: String
    let reasons: [String]

    var isReady: Bool {
        status == "พร้อมออก"
    }
}

struct BulkWeightSlipImportResult: Identifiable, Hashable {
    var id = UUID()
    var index: Int
    var customerName: String
    var status: String
    var detectedWeight: Double
    var note: String

    var isSuccess: Bool {
        status == "แยกสำเร็จ"
    }
}


struct WithholdingTaxRecord: Identifiable, Codable, Hashable {
    var id: String
    var customerCode: String
    var agencyName: String
    var servicePeriod: String
    var documentNo: String
    var amountBeforeVAT: Double
    var withholdingPercent: Double
    var withholdingAmount: Double
    var taxStatus: String
    var evidenceNote: String

    static func make(customer: Customer, line: BillingLine, servicePeriod: String, documentNo: String) -> WithholdingTaxRecord {
        WithholdingTaxRecord(
            id: UUID().uuidString,
            customerCode: customer.customerCode,
            agencyName: customer.agencyName,
            servicePeriod: servicePeriod,
            documentNo: documentNo,
            amountBeforeVAT: line.amountBeforeVAT,
            withholdingPercent: line.withholdingPercent,
            withholdingAmount: line.withholdingAmount,
            taxStatus: "รอเอกสารหัก ณ ที่จ่าย",
            evidenceNote: ""
        )
    }
}

struct DocumentControlRecord: Identifiable, Codable, Hashable {
    var id: String
    var documentNo: String
    var documentType: String
    var customerCode: String
    var agencyName: String
    var createdAt: String
    var sentDate: String
    var carrier: String
    var trackingNo: String
    var checkDueDate: String
    var deliveryStatus: String
    var deliveryCheckedAt: String
    var outgoingBookNo: String
    var outgoingDate: String
    var outgoingBy: String
    var receivedDate: String
    var receiverName: String
    var incomingBookNo: String
    var copySetNote: String
    var lineRecipientId: String
    var lineSentAt: String
    var note: String

    enum CodingKeys: String, CodingKey {
        case id, documentNo, documentType, customerCode, agencyName, createdAt, sentDate, carrier, trackingNo, checkDueDate, deliveryStatus, deliveryCheckedAt
        case outgoingBookNo, outgoingDate, outgoingBy, receivedDate, receiverName, incomingBookNo, copySetNote
        case lineRecipientId, lineSentAt, note
    }

    init(
        id: String,
        documentNo: String,
        documentType: String,
        customerCode: String,
        agencyName: String,
        createdAt: String,
        sentDate: String,
        carrier: String,
        trackingNo: String,
        checkDueDate: String,
        deliveryStatus: String,
        deliveryCheckedAt: String,
        outgoingBookNo: String = "",
        outgoingDate: String = "",
        outgoingBy: String = "",
        receivedDate: String = "",
        receiverName: String = "",
        incomingBookNo: String = "",
        copySetNote: String = "",
        lineRecipientId: String = "wongsapust",
        lineSentAt: String = "",
        note: String
    ) {
        self.id = id
        self.documentNo = documentNo
        self.documentType = documentType
        self.customerCode = customerCode
        self.agencyName = agencyName
        self.createdAt = createdAt
        self.sentDate = sentDate
        self.carrier = carrier
        self.trackingNo = trackingNo
        self.checkDueDate = checkDueDate
        self.deliveryStatus = deliveryStatus
        self.deliveryCheckedAt = deliveryCheckedAt
        self.outgoingBookNo = outgoingBookNo
        self.outgoingDate = outgoingDate
        self.outgoingBy = outgoingBy
        self.receivedDate = receivedDate
        self.receiverName = receiverName
        self.incomingBookNo = incomingBookNo
        self.copySetNote = copySetNote
        self.lineRecipientId = lineRecipientId
        self.lineSentAt = lineSentAt
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        documentNo = try c.decodeIfPresent(String.self, forKey: .documentNo) ?? ""
        documentType = try c.decodeIfPresent(String.self, forKey: .documentType) ?? ""
        customerCode = try c.decodeIfPresent(String.self, forKey: .customerCode) ?? ""
        agencyName = try c.decodeIfPresent(String.self, forKey: .agencyName) ?? ""
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        sentDate = try c.decodeIfPresent(String.self, forKey: .sentDate) ?? ""
        carrier = try c.decodeIfPresent(String.self, forKey: .carrier) ?? "ไปรษณีย์ไทย"
        trackingNo = try c.decodeIfPresent(String.self, forKey: .trackingNo) ?? ""
        checkDueDate = try c.decodeIfPresent(String.self, forKey: .checkDueDate) ?? ""
        deliveryStatus = try c.decodeIfPresent(String.self, forKey: .deliveryStatus) ?? "รอกรอกเลขพัสดุ"
        deliveryCheckedAt = try c.decodeIfPresent(String.self, forKey: .deliveryCheckedAt) ?? ""
        outgoingBookNo = try c.decodeIfPresent(String.self, forKey: .outgoingBookNo) ?? ""
        outgoingDate = try c.decodeIfPresent(String.self, forKey: .outgoingDate) ?? sentDate
        outgoingBy = try c.decodeIfPresent(String.self, forKey: .outgoingBy) ?? ""
        receivedDate = try c.decodeIfPresent(String.self, forKey: .receivedDate) ?? ""
        receiverName = try c.decodeIfPresent(String.self, forKey: .receiverName) ?? ""
        incomingBookNo = try c.decodeIfPresent(String.self, forKey: .incomingBookNo) ?? ""
        copySetNote = try c.decodeIfPresent(String.self, forKey: .copySetNote) ?? "ต้นฉบับสำหรับลูกค้า/หน่วยงาน, สำเนาสำหรับบริษัท"
        lineRecipientId = try c.decodeIfPresent(String.self, forKey: .lineRecipientId) ?? "wongsapust"
        lineSentAt = try c.decodeIfPresent(String.self, forKey: .lineSentAt) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }

    static func make(documentNo: String, type: String, customer: Customer, sentDate: String, carrier: String = "ไปรษณีย์ไทย") -> DocumentControlRecord {
        DocumentControlRecord(
            id: UUID().uuidString,
            documentNo: documentNo,
            documentType: type,
            customerCode: customer.customerCode,
            agencyName: customer.agencyName,
            createdAt: ThaiDate.todayText(),
            sentDate: sentDate,
            carrier: carrier,
            trackingNo: "",
            checkDueDate: ThaiDate.addBusinessDaysText(from: sentDate, days: 2),
            deliveryStatus: "รอกรอกเลขพัสดุ",
            deliveryCheckedAt: "",
            outgoingBookNo: "",
            outgoingDate: sentDate,
            outgoingBy: "",
            receivedDate: "",
            receiverName: "",
            incomingBookNo: "",
            copySetNote: "ต้นฉบับสำหรับลูกค้า/หน่วยงาน, สำเนาสำหรับบริษัท",
            lineRecipientId: customer.lineId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "wongsapust" : customer.lineId,
            lineSentAt: "",
            note: ""
        )
    }
}

enum ThaiDate {
    private static func buddhistFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "th_TH")
        formatter.calendar = Calendar(identifier: .buddhist)
        formatter.dateFormat = format
        return formatter
    }

    static func parse(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formats = [
            "dd/MM/yyyy",
            "d/M/yyyy",
            "dd-MM-yyyy",
            "d-M-yyyy",
            "d MMMM yyyy",
            "dd MMMM yyyy",
            "d MMM yyyy",
            "dd MMM yyyy"
        ]

        for format in formats {
            let formatter = buddhistFormatter(format)
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }

    static func slashDateText(from text: String) -> String {
        guard let date = parse(text) else {
            return text.replacingOccurrences(of: " ", with: "/")
        }
        return buddhistFormatter("dd/MM/yyyy").string(from: date)
    }

    static func todayText() -> String {
        buddhistFormatter("dd/MM/yyyy").string(from: Date())
    }

    static func nowDateTimeText() -> String {
        buddhistFormatter("dd/MM/yyyy HH:mm").string(from: Date())
    }

    static func addBusinessDaysText(from text: String, days: Int) -> String {
        var start = parse(text) ?? Date()
        var added = 0
        let calendar = Calendar(identifier: .gregorian)
        while added < days {
            start = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            let weekday = calendar.component(.weekday, from: start)
            if weekday != 1 && weekday != 7 {
                added += 1
            }
        }

        return buddhistFormatter("dd/MM/yyyy").string(from: start)
    }
}
