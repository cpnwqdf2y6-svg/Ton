import XCTest
@testable import ThanyawitCustomer

final class WindaFolderImporterTests: XCTestCase {
    func testCollectingTRKTicketCODFiles() throws {
        let importer = WindaFolderImporter()
        let folder = try makeTempFolder()
        try "a".write(to: folder.appendingPathComponent("TRK001.TXT"), atomically: true, encoding: .utf8)
        try "a".write(to: folder.appendingPathComponent("ticket_01.txt"), atomically: true, encoding: .utf8)
        try "a".write(to: folder.appendingPathComponent("COD123.TXT"), atomically: true, encoding: .utf8)
        try "a".write(to: folder.appendingPathComponent("ignore.csv"), atomically: true, encoding: .utf8)

        let files = try importer.collectCandidateFiles(in: folder)
        let names = files.map { $0.lastPathComponent }
        XCTAssertEqual(names, ["COD123.TXT", "TRK001.TXT", "ticket_01.txt"])
    }

    func testParseGrossTareAndCalculateNet() throws {
        let importer = WindaFolderImporter()
        let folder = try makeTempFolder()
        let text = """
        Ticket: TK-100
        Gross: 24,500
        Tare: 8,250
        """
        try text.write(to: folder.appendingPathComponent("TRK100.TXT"), atomically: true, encoding: .utf8)

        let result = try importer.importFiles(from: folder)
        let row = try XCTUnwrap(result.weightSlips.first)
        XCTAssertEqual(row.grossKg, 24500)
        XCTAssertEqual(row.tareKg, 8250)
        XCTAssertEqual(row.netKg, 16250)
        XCTAssertEqual(row.netTon, 16.25)
    }

    func testParseExplicitNetWhenGrossTareMissing() throws {
        let importer = WindaFolderImporter()
        let folder = try makeTempFolder()
        let text = """
        Ticket: TK-200
        Net: 12,340
        """
        try text.write(to: folder.appendingPathComponent("ticket200.txt"), atomically: true, encoding: .utf8)

        let result = try importer.importFiles(from: folder)
        let row = try XCTUnwrap(result.weightSlips.first)
        XCTAssertNil(row.grossKg)
        XCTAssertNil(row.tareKg)
        XCTAssertEqual(row.netKg, 12340)
        XCTAssertEqual(row.netTon, 12.34)
    }

    func testPreserveAuditFieldsAndSourceType() throws {
        let importer = WindaFolderImporter()
        let folder = try makeTempFolder()
        let text = "Ticket: TK-300\nNet: 1000"
        let fileURL = folder.appendingPathComponent("TRK300.TXT")
        try text.write(to: fileURL, atomically: true, encoding: .utf8)

        let result = try importer.importFiles(from: folder)
        let row = try XCTUnwrap(result.weightSlips.first)
        XCTAssertEqual(row.sourceType, "Winda")
        XCTAssertEqual(row.sourceFileName, "TRK300.TXT")
        XCTAssertEqual(row.sourceFilePath, fileURL.path)
        XCTAssertEqual(row.sourceRawText, text)
    }

    func testImportApril2026WDATARealHeaderMappingAndMonthFilter() throws {
        let importer = WindaFolderImporter()
        let folder = try makeTempFolder()
        let csv = """
        record_id,stat,status_name,truck,company_code,company_name,product_code,product_name,ticket1,dayin,tmin,w1,ticket2,dayout,tmout,w2,net_weight_kg,source_month
        RID-1,0,รอตรวจ,70-1111,COMP1,เทศบาล A,P001,หินคลุก,TK1,2026-04-01,08:00,25000,TK1B,2026-04-01,10:00,10000,14900,2569-04
        RID-2,0,รอตรวจ,70-2222,COMP1,เทศบาล A,P001,หินคลุก,TK2,2026-04-02,08:00,24000,,2026-04-02,10:00,10000,,2569-04
        RID-3,0,รอตรวจ,70-3333,COMP2,เทศบาล B,P002,ทราย,TK3,2026-05-01,08:00,26000,,2026-05-01,10:00,12000,14000,2569-05
        """
        try csv.write(to: folder.appendingPathComponent("WDATA_NORMALIZED_WITH_STATUS.csv"), atomically: true, encoding: .utf8)

        let result = try importer.importApril2026WDATA(from: folder)
        XCTAssertEqual(result.sourceMonth, "2569-04")
        XCTAssertEqual(result.records.count, 2)
        XCTAssertEqual(result.records[0].id, "RID-1")
        XCTAssertEqual(result.records[0].truckPlate, "70-1111")
        XCTAssertEqual(result.records[0].ticketNo, "TK1")
        XCTAssertEqual(result.records[0].netKg, 14900) // net_weight_kg priority
        XCTAssertEqual(result.records[0].parserConfidence, 1.0)
        XCTAssertEqual(result.records[1].netKg, 14000) // fallback abs(w1-w2)
        XCTAssertEqual(result.records[1].parserConfidence, 0.9)
        XCTAssertEqual(result.netTonTotal, 28.9, accuracy: 0.0001)
        XCTAssertNotNil(result.groupedByCustomerCompany["|COMP1|2569-04"])
        XCTAssertFalse(result.records[0].isReviewed)
    }

    func testImportApril2026WDATAQuotedCSVValue() throws {
        let importer = WindaFolderImporter()
        let folder = try makeTempFolder()
        let csv = """
        record_id,stat,status_name,truck,company_code,company_name,product_code,product_name,ticket1,dayin,tmin,w1,ticket2,dayout,tmout,w2,net_weight_kg,source_month
        RID-Q,0,รอตรวจ,70-9999,COMPQ,"เทศบาล, เมือง Q",P009,"หิน, ทราย",TKQ,2026-04-03,09:00,20000,,2026-04-03,11:00,9000,11000,2569-04
        """
        try csv.write(to: folder.appendingPathComponent("WDATA_NORMALIZED_WITH_STATUS.csv"), atomically: true, encoding: .utf8)
        let result = try importer.importApril2026WDATA(from: folder)
        XCTAssertEqual(result.records.count, 1)
        XCTAssertEqual(result.records.first?.customerName, "เทศบาล, เมือง Q")
        XCTAssertEqual(result.records.first?.productName, "หิน, ทราย")
        XCTAssertEqual(result.records.first?.sourceFileName, "WDATA_NORMALIZED_WITH_STATUS.csv")
        XCTAssertTrue(result.records.first?.sourceRawText.contains("RID-Q") == true)
    }



    func testWeightParsingPrefersLastLargeNumberAndIgnoresSmallNumbers() throws {
        let importer = WindaFolderImporter()
        let folder = try makeTempFolder()
        let text = """
        Ticket: T-7788
        Truck: 70-1234
        Gross 70-1234 950 25,400
        Tare lane2 550 8,400
        """
        try text.write(to: folder.appendingPathComponent("TRK777.TXT"), atomically: true, encoding: .utf8)

        let result = try importer.importFiles(from: folder)
        let row = try XCTUnwrap(result.weightSlips.first)
        XCTAssertEqual(row.grossKg, 25400)
        XCTAssertEqual(row.tareKg, 8400)
        XCTAssertEqual(row.netKg, 17000)
    }

    func testCustomerMasterImporterPreservesAuditFields() throws {
        let importer = CustomerMasterImporter()
        let folder = try makeTempFolder()
        let file = folder.appendingPathComponent("MASTER_COMPANY.csv")
        try "customer_code,company_code,customer_name,agency_name\nC001,COMP1,ลูกค้า A,หน่วยงาน A".write(to: file, atomically: true, encoding: .utf8)
        let rows = try importer.importCSV(from: file)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].sourceFileName, "MASTER_COMPANY.csv")
        XCTAssertTrue(rows[0].sourceRawText.contains("C001"))
    }

    func testCustomerMasterImporterRealMasterCompanyHeadersAndThaiNames() throws {
        let importer = CustomerMasterImporter()
        let folder = try makeTempFolder()
        let file = folder.appendingPathComponent("MASTER_COMPANY.csv")
        let csv = """
        COMPANY_CODE,COMPANY_NAME,CUSTOMER_CODE,AGENCY_NAME,DISTRICT_NAME,CUSTOMER_GROUP,BILLING_NAME
        COMP9,บริษัท ทดสอบ จำกัด,C009,เทศบาลเมืองตัวอย่าง,เมือง,จ้างขน,บริษัท ทดสอบ จำกัด (สำนักงานใหญ่)
        """
        try csv.write(to: file, atomically: true, encoding: .utf8)
        let rows = try importer.importCSV(from: file)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].companyCode, "COMP9")
        XCTAssertEqual(rows[0].customerName, "บริษัท ทดสอบ จำกัด")
        XCTAssertEqual(rows[0].agencyName, "เทศบาลเมืองตัวอย่าง")
    }

    func testCustomerMasterImporterBlankCustomerCodeWithCompanyCode() throws {
        let importer = CustomerMasterImporter()
        let folder = try makeTempFolder()
        let file = folder.appendingPathComponent("MASTER_COMPANY.csv")
        try "company_code,company_name,customer_code\nCOMPX,บริษัท X,".write(to: file, atomically: true, encoding: .utf8)
        let rows = try importer.importCSV(from: file)
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows[0].customerCode.isEmpty)
        XCTAssertEqual(rows[0].companyCode, "COMPX")
    }

    func testCustomerMasterRecordIdStableForDuplicateLikeRows() {
        let a = CustomerMasterRecord(customerCode: "", companyCode: "COMPX", customerName: "A", agencyName: "", districtName: "", customerGroup: "", billingName: "", sourceFileName: "MASTER_COMPANY.csv", sourceRawText: "COMPX,A")
        let b = CustomerMasterRecord(customerCode: "", companyCode: "COMPX", customerName: "A", agencyName: "", districtName: "", customerGroup: "", billingName: "", sourceFileName: "MASTER_COMPANY.csv", sourceRawText: "COMPX,A ")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testWeightSlipMatcherMatchesByCompanyCode() {
        let slip = WeightSlipRecord(id: "1", customerCode: "", customerName: "", companyCode: "COMP1", productCode: "", productName: "", ticketNo: "", truckPlate: "", dateIn: "", timeIn: "", grossKg: nil, dateOut: "", timeOut: "", tareKg: nil, netKg: 1000, netTon: 1, sourceType: "Winda", sourceFileName: "", sourceFilePath: "", sourceRawText: "", evidenceImagePath: "", signatureImagePath: "", parserConfidence: 1, parserNote: "", isReviewed: false, reviewedAt: "", reviewerNote: "")
        let master = CustomerMasterRecord(customerCode: "C001", companyCode: "COMP1", customerName: "ลูกค้า A", agencyName: "หน่วยงาน A", districtName: "", customerGroup: "", billingName: "", sourceFileName: "", sourceRawText: "")
        let matched = WeightSlipMatcher().match([slip], with: [master])
        XCTAssertEqual(matched[0].matchStatus, "matched")
        XCTAssertEqual(matched[0].matchedCustomerCode, "C001")
        XCTAssertEqual(matched[0].customerName, "ลูกค้า A")
        XCTAssertEqual(matched[0].netKg, 1000) // preserve original Winda value
    }

    func testWeightSlipMatcherUnmatched() {
        let slip = WeightSlipRecord(id: "1", customerCode: "", customerName: "", companyCode: "X", productCode: "", productName: "", ticketNo: "", truckPlate: "", dateIn: "", timeIn: "", grossKg: nil, dateOut: "", timeOut: "", tareKg: nil, netKg: 900, netTon: 0.9, sourceType: "Winda", sourceFileName: "", sourceFilePath: "", sourceRawText: "", evidenceImagePath: "", signatureImagePath: "", parserConfidence: 1, parserNote: "", isReviewed: false, reviewedAt: "", reviewerNote: "")
        let matched = WeightSlipMatcher().match([slip], with: [])
        XCTAssertEqual(matched[0].matchStatus, "unmatched")
    }

    func testWeightSlipMatcherNameMismatchWarning() {
        let slip = WeightSlipRecord(id: "1", customerCode: "C001", customerName: "ชื่อจาก Winda", companyCode: "", productCode: "", productName: "", ticketNo: "", truckPlate: "", dateIn: "", timeIn: "", grossKg: nil, dateOut: "", timeOut: "", tareKg: nil, netKg: 1000, netTon: 1, sourceType: "Winda", sourceFileName: "", sourceFilePath: "", sourceRawText: "", evidenceImagePath: "", signatureImagePath: "", parserConfidence: 1, parserNote: "", isReviewed: false, reviewedAt: "", reviewerNote: "")
        let master = CustomerMasterRecord(customerCode: "C001", companyCode: "COMP1", customerName: "ชื่อจาก Master", agencyName: "", districtName: "", customerGroup: "", billingName: "", sourceFileName: "", sourceRawText: "")
        let matched = WeightSlipMatcher().match([slip], with: [master])
        XCTAssertEqual(matched[0].matchStatus, "warning")
        XCTAssertEqual(matched[0].conflictReason, "รหัสตรงกันแต่ชื่อลูกค้าไม่ตรง (ยึดรหัส)")
    }

    func testParseCustomerNameDoesNotUseCustomerCodeLine() throws {
        let importer = WindaFolderImporter()
        let folder = try makeTempFolder()
        let text = """
        CUSTOMER CODE: C003
        CUSTOMER: Example Customer Co., Ltd.
        """
        try text.write(to: folder.appendingPathComponent("TRK-CUSTOMER.TXT"), atomically: true, encoding: .utf8)

        let result = try importer.importFiles(from: folder)
        let row = try XCTUnwrap(result.weightSlips.first)
        XCTAssertEqual(row.customerCode, "C003")
        XCTAssertEqual(row.customerName, "Example Customer Co., Ltd.")
    }

    func testParseCustomerNameFromCustomerNameLineAfterCustomerCode() throws {
        let importer = WindaFolderImporter()
        let folder = try makeTempFolder()
        let text = """
        CUSTOMER CODE: C002
        CUSTOMER NAME: Example Customer Co., Ltd.
        """
        try text.write(to: folder.appendingPathComponent("TRK-CUSTOMER-NAME.TXT"), atomically: true, encoding: .utf8)

        let result = try importer.importFiles(from: folder)
        let row = try XCTUnwrap(result.weightSlips.first)
        XCTAssertEqual(row.customerCode, "C002")
        XCTAssertEqual(row.customerName, "Example Customer Co., Ltd.")
    }

    func testParseCustomerCodeWithoutColonFormat() throws {
        let importer = WindaFolderImporter()
        let folder = try makeTempFolder()
        let text = "CUSTOMER CODE C003"
        try text.write(to: folder.appendingPathComponent("TRK-CUSTOMER-CODE-NOCOLON.TXT"), atomically: true, encoding: .utf8)

        let result = try importer.importFiles(from: folder)
        let row = try XCTUnwrap(result.weightSlips.first)
        XCTAssertEqual(row.customerCode, "C003")
    }

    func testParseCustomerNameWithoutColonFormat() throws {
        let importer = WindaFolderImporter()
        let folder = try makeTempFolder()
        let text = "CUSTOMER Example Customer Co., Ltd."
        try text.write(to: folder.appendingPathComponent("TRK-CUSTOMER-NAME-NOCOLON.TXT"), atomically: true, encoding: .utf8)

        let result = try importer.importFiles(from: folder)
        let row = try XCTUnwrap(result.weightSlips.first)
        XCTAssertEqual(row.customerName, "Example Customer Co., Ltd.")
    }

    func testColonFormatsStillParseCustomerCodeAndName() throws {
        let importer = WindaFolderImporter()
        let folder = try makeTempFolder()
        let text = """
        CUSTOMER CODE: C003
        CUSTOMER: Example Customer Co., Ltd.
        """
        try text.write(to: folder.appendingPathComponent("TRK-CUSTOMER-COLON.TXT"), atomically: true, encoding: .utf8)

        let result = try importer.importFiles(from: folder)
        let row = try XCTUnwrap(result.weightSlips.first)
        XCTAssertEqual(row.customerCode, "C003")
        XCTAssertEqual(row.customerName, "Example Customer Co., Ltd.")
    }

    func testParseProductCodeWithoutColonFormatDoesNotCorruptProductName() throws {
        let importer = WindaFolderImporter()
        let folder = try makeTempFolder()
        let text = "PRODUCT CODE P001"
        try text.write(to: folder.appendingPathComponent("TRK-PRODUCT-CODE-NOCOLON.TXT"), atomically: true, encoding: .utf8)

        let result = try importer.importFiles(from: folder)
        let row = try XCTUnwrap(result.weightSlips.first)
        XCTAssertEqual(row.productCode, "P001")
        XCTAssertNotEqual(row.productName, "CODE P001")
        XCTAssertTrue(row.productName.isEmpty)
    }

    func testColonFormatsStillParseProductCodeAndName() throws {
        let importer = WindaFolderImporter()
        let folder = try makeTempFolder()
        let text = """
        PRODUCT CODE: P001
        PRODUCT: หินคลุก
        """
        try text.write(to: folder.appendingPathComponent("TRK-PRODUCT-COLON.TXT"), atomically: true, encoding: .utf8)

        let result = try importer.importFiles(from: folder)
        let row = try XCTUnwrap(result.weightSlips.first)
        XCTAssertEqual(row.productCode, "P001")
        XCTAssertEqual(row.productName, "หินคลุก")
    }

    func testWeightSlipMatcherHandlesDuplicateMasterKeysWithoutCrash() {
        let slip = WeightSlipRecord(id: "1", customerCode: "C001", customerName: "", companyCode: "COMP1", productCode: "", productName: "", ticketNo: "", truckPlate: "", dateIn: "", timeIn: "", grossKg: nil, dateOut: "", timeOut: "", tareKg: nil, netKg: 1200, netTon: 1.2, sourceType: "Winda", sourceFileName: "", sourceFilePath: "", sourceRawText: "", evidenceImagePath: "", signatureImagePath: "", parserConfidence: 1, parserNote: "", isReviewed: false, reviewedAt: "", reviewerNote: "")
        let first = CustomerMasterRecord(customerCode: "C001", companyCode: "COMP1", customerName: "ลูกค้าแรก", agencyName: "", districtName: "", customerGroup: "", billingName: "", sourceFileName: "", sourceRawText: "")
        let duplicate = CustomerMasterRecord(customerCode: "C001", companyCode: "COMP1", customerName: "ลูกค้าซ้ำ", agencyName: "", districtName: "", customerGroup: "", billingName: "", sourceFileName: "", sourceRawText: "")

        let matched = WeightSlipMatcher().match([slip], with: [first, duplicate])
        XCTAssertEqual(matched.count, 1)
        XCTAssertEqual(matched[0].matchedCustomerName, "ลูกค้าแรก")
        XCTAssertEqual(matched[0].matchStatus, "matched")
    }

    private func makeTempFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
