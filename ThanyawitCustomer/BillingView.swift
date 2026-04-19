import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct BillingView: View {
    @EnvironmentObject private var store: CustomerStore
    @State private var billingSearchText = ""
    @State private var billingGroupFilter = "ทั้งหมด"
    @State private var billingStatusFilter = "ทั้งหมด"
    @State private var selectedBulkSlipItems: [PhotosPickerItem] = []
    @State private var bulkSlipResults: [BulkWeightSlipImportResult] = []
    @State private var bulkSlipMessage = ""
    @State private var isBulkSlipImporting = false

    private var filteredBillingCustomers: [Customer] {
        store.customers.filter { customer in
            let query = billingSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let searchableText = [
                customer.customerCode,
                customer.agencyName,
                customer.agencyShort,
                customer.districtName,
                customer.customerGroup
            ].joined(separator: " ").lowercased()

            let matchesSearch = query.isEmpty || searchableText.contains(query)
            let matchesGroup = billingGroupFilter == "ทั้งหมด" || customer.customerGroup == billingGroupFilter
            let matchesStatus = billingStatusFilter == "ทั้งหมด" || store.precheck(for: customer).status == billingStatusFilter
            return matchesSearch && matchesGroup && matchesStatus
        }
    }

    private var validationSummaryPanel: some View {
        let summary = store.customerCSVValidationSummary()
        return VStack(alignment: .leading, spacing: 6) {
            Text("Validation Summary (CSV Master)")
                .font(.headline)
            Text("รวม \(summary.totalRows) หน่วยงาน")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Tax ID ขาด \(summary.missingTaxIdCount) · เลขสัญญาขาด \(summary.missingContractNoCount) · วันที่สัญญาขาด \(summary.missingContractDateCount) · ที่อยู่ขาด \(summary.missingAddressCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if summary.duplicateCodes.isEmpty {
                Text("รหัสลูกค้าไม่ซ้ำ")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else {
                Text("รหัสลูกค้าซ้ำ: \(summary.duplicateCodes.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.orange.opacity(0.2))
        }
    }

    private var bulkWeightSlipImportPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("แนบใบชั่งหลายใบ แล้วให้ระบบแยก อปท.")
                        .font(.headline)
                    Text("เลือกรูปใบชั่งพร้อมกันได้ เช่น 17 ใบ ระบบจะ OCR หา อปท. จากชื่อบางส่วน แล้วกรอกน้ำหนักเข้าบิลของแต่ละหน่วยงานให้")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                PhotosPicker(selection: $selectedBulkSlipItems, maxSelectionCount: 30, matching: .images) {
                    Label("เลือกใบชั่งหลายใบ", systemImage: "text.viewfinder")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBulkSlipImporting)
            }

            if isBulkSlipImporting {
                ProgressView("กำลัง OCR และแยกใบชั่ง...")
                    .font(.caption)
            }

            if !bulkSlipMessage.isEmpty {
                Text(bulkSlipMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !bulkSlipResults.isEmpty {
                DisclosureGroup("ผลการแยกใบชั่งล่าสุด") {
                    VStack(spacing: 8) {
                        ForEach(bulkSlipResults) { result in
                            BulkWeightSlipResultRow(result: result)
                        }
                    }
                    .padding(.top, 6)
                }
            }
        }
        .padding()
        .background(.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.green.opacity(0.18))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("ตั้งค่างวด") {
                    TextField("เดือนงาน", text: $store.servicePeriod)
                    TextField("วันที่เอกสาร", text: $store.documentDate)
                }
            }
            .frame(height: 150)

            VStack(alignment: .leading, spacing: 10) {
                Text("เลือก อปท. ที่จะออกบิล")
                    .font(.headline)
                Text("กดการ์ดเหมือนเปิดโฟลเดอร์ของแต่ละหน่วยงาน แล้วเข้าไปกรอกน้ำหนัก แนบใบชั่ง พรีวิวเอกสาร และอนุมัติบิล")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("ค้นหา อปท. / ชื่อย่อ / อำเภอ / รหัส", text: $billingSearchText)
                        .textFieldStyle(.roundedBorder)

                    Picker("กลุ่ม", selection: $billingGroupFilter) {
                        Text("ทั้งหมด").tag("ทั้งหมด")
                        Text("จ้างขน").tag("จ้างขน")
                        Text("เก็บขน").tag("เก็บขน")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)

                    Picker("สถานะ", selection: $billingStatusFilter) {
                        Text("ทั้งหมด").tag("ทั้งหมด")
                        Text("พร้อมออก").tag("พร้อมออก")
                        Text("รอตรวจ").tag("รอตรวจ")
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding()

            bulkWeightSlipImportPanel
                .padding(.horizontal)
                .padding(.bottom, 10)

            validationSummaryPanel
                .padding(.horizontal)
                .padding(.bottom, 10)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                    ForEach(filteredBillingCustomers) { customer in
                        NavigationLink {
                            BillingLineView(customer: customer)
                                .navigationTitle(customer.agencyShort.isEmpty ? customer.agencyName : customer.agencyShort)
                        } label: {
                            BillingCustomerFolderCard(customer: customer)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding([.horizontal, .bottom])

                if filteredBillingCustomers.isEmpty {
                    ContentUnavailableView(
                        "ไม่พบ อปท.",
                        systemImage: "folder.badge.questionmark",
                        description: Text("ลองล้างคำค้นหา หรือเปลี่ยนตัวกรองกลุ่ม/สถานะ")
                    )
                    .padding()
                }
            }
        }
        .toolbar {
            Button("บันทึก") {
                store.saveBilling()
            }

            Button("ล้างค่าที่กรอก") {
                store.resetBilling()
            }
        }
        .navigationTitle("กรอกออกบิล")
        .onChange(of: selectedBulkSlipItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await importBulkWeightSlips(items)
            }
        }
    }

    private func importBulkWeightSlips(_ items: [PhotosPickerItem]) async {
        isBulkSlipImporting = true
        bulkSlipMessage = "กำลังอ่านรูป \(items.count) ใบ"
        var imageDatas: [Data] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                imageDatas.append(data)
            }
        }

        if imageDatas.isEmpty {
            bulkSlipMessage = "ยังอ่านรูปใบชั่งไม่ได้ กรุณาเลือกใหม่อีกครั้ง"
            isBulkSlipImporting = false
            selectedBulkSlipItems = []
            return
        }

        let results = store.importBulkWeightSlipImages(imageDatas)
        bulkSlipResults = results
        let successCount = results.filter(\.isSuccess).count
        let reviewCount = results.count - successCount
        bulkSlipMessage = "แยกสำเร็จ \(successCount)/\(results.count) ใบ" + (reviewCount > 0 ? " · รอตรวจ \(reviewCount) ใบ" : "")
        isBulkSlipImporting = false
        selectedBulkSlipItems = []
    }
}

struct BulkWeightSlipResultRow: View {
    let result: BulkWeightSlipImportResult

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(result.isSuccess ? .green : .orange)

            VStack(alignment: .leading, spacing: 3) {
                Text("ใบที่ \(result.index): \(result.customerName)")
                    .font(.caption.bold())
                Text("น้ำหนักจากตาราง: \(result.detectedWeight > 0 ? ThaiFormat.plain(result.detectedWeight) : "-")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(result.note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(result.status)
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((result.isSuccess ? Color.green : Color.orange).opacity(0.16))
                .foregroundStyle(result.isSuccess ? .green : .orange)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BillingCustomerFolderCard: View {
    @EnvironmentObject private var store: CustomerStore
    let customer: Customer

    var body: some View {
        let line = store.billingLine(for: customer)
        let result = store.precheck(for: customer)
        let title = customer.agencyShort.isEmpty ? customer.agencyName : customer.agencyShort

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundStyle(result.isReady ? .green : .blue)

                Spacer()

                StatusBadge(status: result.status)
            }

            Text(title.isEmpty ? "(ยังไม่ใส่ชื่อ อปท.)" : title)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text("\(customer.customerCode) · \(customer.customerGroup) · \(customer.districtName)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Divider()

            LabeledContent("น้ำหนัก", value: ThaiFormat.plain(line.weight))
                .font(.caption)
            LabeledContent("ยอดก่อน VAT", value: ThaiFormat.money(line.amountBeforeVAT))
                .font(.caption)
            LabeledContent("ใบชั่ง", value: store.isWeightSlipApprovalReady(line) ? "ผ่าน" : "รอตรวจ")
                .font(.caption)
            LabeledContent("อนุมัติ", value: line.billingApprovedAt.isEmpty ? "ยัง" : "แล้ว")
                .font(.caption)

            Label("เปิดแฟ้มกรอกบิล", systemImage: "chevron.right.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.blue)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(result.isReady ? Color.green.opacity(0.35) : Color.secondary.opacity(0.16), lineWidth: 1)
        }
    }
}

struct BillingLineView: View {
    @EnvironmentObject private var store: CustomerStore
    let customer: Customer

    @State private var line: BillingLine = BillingLine(id: "")
    @State private var selectedSlipItem: PhotosPickerItem?
    @State private var showSlipFileImporter = false
    @State private var slipPreviewImage: UIImage?
    @State private var slipMessage = ""
    @State private var previewPayload: DocumentPreviewPayload?
    @State private var sharePayload: ShareExportPayload?
    @FocusState private var focusedField: Field?

    enum Field {
        case weight, unitRate, amount, vat, wht
    }

    var body: some View {
        let result = store.precheck(for: customer)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(customer.agencyName)
                        .font(.headline)
                    Text("\(customer.customerCode) · \(customer.customerGroup)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Toggle("ออก", isOn: Binding(
                    get: { line.isSelected },
                    set: {
                        line.isSelected = $0
                        store.updateBilling(line)
                    }
                ))
                .labelsHidden()

                StatusBadge(status: result.status)
            }

            Grid(horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    NumberField(title: "น้ำหนัก/จำนวน", value: $line.weight, focused: $focusedField, field: .weight)
                    NumberField(title: "หน่วยราคา", value: $line.unitRate, focused: $focusedField, field: .unitRate)
                    NumberField(title: "ยอดก่อน VAT", value: $line.amountBeforeVAT, focused: $focusedField, field: .amount)
                }

                GridRow {
                    NumberField(title: "VAT %", value: $line.vatPercent, focused: $focusedField, field: .vat)
                    NumberField(title: "หัก ณ ที่จ่าย %", value: $line.withholdingPercent, focused: $focusedField, field: .wht)

                    VStack(alignment: .leading) {
                        Text("สุทธิ")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(ThaiFormat.money(line.netAmount))
                            .font(.headline)
                    }
                }
            }

            Button {
                line.amountBeforeVAT = store.expectedAmount(for: line)
            } label: {
                Label("คำนวณยอดก่อน VAT = น้ำหนัก x หน่วยราคา", systemImage: "equal.circle")
            }
            .buttonStyle(.bordered)

            if let warning = store.amountMismatchWarning(for: line) {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    PhotosPicker(selection: $selectedSlipItem, matching: .images) {
                        Label(line.weightSlipImageFilename.isEmpty ? "แนบภาพสแกนใบชั่งน้ำหนัก" : "เปลี่ยนภาพใบชั่งน้ำหนัก", systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showSlipFileImporter = true
                    } label: {
                        Label("แนบไฟล์รูป/PDF", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.bordered)

                    if !line.weightSlipConfirmedAt.isEmpty {
                        Text("ยืนยัน: \(line.weightSlipConfirmedAt)")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                TextField("หมายเหตุหลักฐาน เช่น เลขใบชั่ง / ผู้ตรวจ / เหตุผลยอดต่าง", text: $line.weightEvidenceNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)

                HStack(spacing: 8) {
                    TextField("เลขใบชั่ง/อ้างอิง", text: $line.slipTicketNo)
                    TextField("เวลาเข้า HH:mm", text: $line.weightTimeIn)
                    TextField("เวลาออก HH:mm", text: $line.weightTimeOut)
                }
                .textFieldStyle(.roundedBorder)

                if !line.weightSlipSourceFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("หลักฐานล่าสุด: \(line.weightSlipSourceFilename)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let slipPreviewImage {
                    Image(uiImage: slipPreviewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.secondary.opacity(0.3))
                        }
                }

                if !store.hasWeightEvidence(line) {
                    Text("ต้องมีภาพใบชั่งหรือหมายเหตุหลักฐานก่อนระบบจะถือว่าพร้อมออกบิล")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !line.weightSlipOCRCheckedAt.isEmpty {
                    HStack(spacing: 8) {
                        Label(
                            line.weightSlipAgencyMatched ? "ชื่อ อปท. ตรง" : "ชื่อ อปท. ไม่ตรง",
                            systemImage: line.weightSlipAgencyMatched ? "checkmark.seal.fill" : "xmark.seal.fill"
                        )
                        .foregroundStyle(line.weightSlipAgencyMatched ? .green : .red)

                        Label(
                            line.weightSlipTotalWeightMatched ? "ตารางน้ำหนักผ่าน" : "ตารางน้ำหนักไม่ผ่าน",
                            systemImage: line.weightSlipTotalWeightMatched ? "checkmark.seal.fill" : "xmark.seal.fill"
                        )
                        .foregroundStyle(line.weightSlipTotalWeightMatched ? .green : .red)
                    }
                    .font(.caption.bold())

                    Text(line.weightSlipAgencyCheckNote)
                        .font(.caption)
                        .foregroundStyle(line.weightSlipAgencyMatched ? .green : .red)
                    Text(line.weightSlipWeightCheckNote)
                        .font(.caption)
                        .foregroundStyle(line.weightSlipTotalWeightMatched ? .green : .red)

                    if store.requiresReviewerWeightNote(line) && !store.hasReviewerWeightNote(line) {
                        Text("ตารางน้ำหนักไม่ตรงยอดรวม OCR: ต้องกรอกหมายเหตุผู้ตรวจก่อนอนุมัติ")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    let tableWeightText = line.weightTonFromTable > 0 ? "\(ThaiFormat.plain(line.weightTonFromTable)) ตัน" : "-"
                    let ocrTotalText = line.ocrTotalTon > 0 ? "\(ThaiFormat.plain(line.ocrTotalTon)) ตัน" : "ไม่พบ"
                    HStack(spacing: 8) {
                        Text("จากตาราง: \(tableWeightText)")
                        Text("ยอดรวม OCR: \(ocrTotalText)")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    DisclosureGroup("ข้อความที่ OCR อ่านได้") {
                        Text(line.weightSlipOCRText.isEmpty ? "OCR ไม่พบข้อความ" : line.weightSlipOCRText)
                            .font(.caption2)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if !line.weightSlipImageFilename.isEmpty {
                    Text("มีภาพใบชั่งแล้ว แต่ยังไม่ได้ตรวจ OCR")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !line.weightSlipImageFilename.isEmpty {
                    Button {
                        rerunOCRFromSavedSlip()
                    } label: {
                        Label("ตรวจ OCR จากภาพใบชั่งอีกครั้ง", systemImage: "text.viewfinder")
                    }
                    .buttonStyle(.bordered)
                }

                if !slipMessage.isEmpty {
                    Text(slipMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Button {
                    previewPayload = DocumentPreviewPayload(
                        title: "\(customer.agencyShort.isEmpty ? customer.agencyName : customer.agencyShort) - พรีวิวเอกสาร",
                        files: store.billingPreviewFiles(for: customer),
                        canRegister: false
                    )
                } label: {
                    Label("พรีวิวใบแจ้งหนี้ / ใบกำกับ / ใบส่งมอบ / สรุปน้ำหนัก", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)

                Button {
                    line = store.approveBilling(for: customer, note: "ตรวจ OCR + ตารางน้ำหนัก และพรีวิวเอกสารแล้ว")
                    slipMessage = "อนุมัติบิลแล้ว รายการนี้จะไปพร้อมปริ้นท์ในสั่งงานเอกสาร"
                } label: {
                    Label(line.billingApprovedAt.isEmpty ? "อนุมัติบิลหลังตรวจพรีวิว" : "อนุมัติแล้ว \(line.billingApprovedAt)", systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(line.billingApprovedAt.isEmpty ? .blue : .green)
                .disabled(!canApproveBilling)
            }

            if !line.billingApprovedAt.isEmpty {
                Text("ผ่านแล้ว: รายการนี้จะถูกยกไปหมวดสั่งงานเอกสาร เพื่อเตรียมปริ้นท์รวม")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            } else if !canApproveBilling {
                Text("ยังอนุมัติไม่ได้: ต้องผ่านชื่อ อปท., ต้องพบตารางน้ำหนัก (และถ้า mismatch กับยอดรวม OCR ต้องมีหมายเหตุผู้ตรวจ), เวลาเข้า/ออก และยอดคำนวณไม่ขัดกัน")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 6)
        .sheet(item: $previewPayload) { payload in
            DocumentPreviewSheet(
                payload: payload,
                onPrintOrSave: { commitPreviewToShare($0) },
                onRegister: { _ in }
            )
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareSheet(urls: payload.urls)
        }
        .fileImporter(
            isPresented: $showSlipFileImporter,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await importWeightSlipFile(url)
                }
            case .failure(let error):
                slipMessage = "เปิดไฟล์หลักฐานไม่สำเร็จ: \(error.localizedDescription)"
            }
        }
        .onAppear {
            line = store.billingLine(for: customer)
            loadSlipPreview()
        }
        .onChange(of: line) { oldValue, newValue in
            var updated = newValue
            if !oldValue.billingApprovedAt.isEmpty && approvalSensitiveFieldsChanged(oldValue, updated) {
                updated = store.clearBillingApproval(updated)
                line = updated
                return
            }
            store.updateBilling(updated)
        }
        .onChange(of: selectedSlipItem) { _, item in
            guard let item else { return }
            Task {
                await attachWeightSlip(item)
            }
        }
    }

    private func attachWeightSlip(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                slipMessage = "อ่านภาพใบชั่งไม่สำเร็จ"
                return
            }

            let analyzedLine = try store.analyzeWeightSlipDocument(data, fileName: "photo_pick.jpg", for: customer, baseLine: line)
            line = analyzedLine
            slipPreviewImage = UIImage(data: data)
            slipMessage = slipValidationMessage(for: analyzedLine, successText: "บันทึกภาพและคำนวณตารางน้ำหนักผ่านแล้ว")
        } catch {
            slipMessage = "บันทึกภาพใบชั่งไม่สำเร็จ: \(error.localizedDescription)"
        }
    }

    private func loadSlipPreview() {
        guard let url = store.weightSlipImageURL(for: line),
              let data = try? Data(contentsOf: url) else {
            slipPreviewImage = nil
            return
        }
        slipPreviewImage = UIImage(data: data)
    }

    private func rerunOCRFromSavedSlip() {
        guard let url = store.weightSlipImageURL(for: line),
              let data = try? Data(contentsOf: url) else {
            slipMessage = "ยังไม่พบไฟล์ภาพใบชั่งที่บันทึกไว้"
            return
        }

        do {
            line = try store.analyzeWeightSlipImage(data, for: customer, baseLine: line)
            slipMessage = slipValidationMessage(for: line, successText: "ตรวจ OCR + ตารางน้ำหนักผ่านแล้ว")
        } catch {
            slipMessage = "ตรวจ OCR ไม่สำเร็จ: \(error.localizedDescription)"
        }
    }

    private func importWeightSlipFile(_ url: URL) async {
        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let analyzedLine = try store.analyzeWeightSlipDocument(data, fileName: url.lastPathComponent, for: customer, baseLine: line)
            line = analyzedLine
            if url.pathExtension.lowercased() == "pdf" {
                slipPreviewImage = nil
            } else {
                slipPreviewImage = UIImage(data: data)
            }
            slipMessage = slipValidationMessage(for: analyzedLine, successText: "แนบไฟล์และคำนวณตารางน้ำหนักผ่านแล้ว")
        } catch {
            slipMessage = "แนบไฟล์หลักฐานไม่สำเร็จ: \(error.localizedDescription)"
        }
    }

    private var canApproveBilling: Bool {
        store.isWeightSlipApprovalReady(line) &&
        store.amountMismatchWarning(for: line) == nil &&
        !line.weightTimeIn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !line.weightTimeOut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        line.weight > 0 &&
        line.unitRate > 0 &&
        line.amountBeforeVAT > 0
    }

    private func slipValidationMessage(for line: BillingLine, successText: String) -> String {
        if store.isWeightSlipApprovalReady(line) {
            return successText
        }
        if line.weightTonFromTable <= 0 {
            return "OCR ยังไม่พบบรรทัดตารางน้ำหนัก จึงยังไม่เติมน้ำหนักและยังอนุมัติไม่ได้"
        }
        if store.requiresReviewerWeightNote(line) && !store.hasReviewerWeightNote(line) {
            return "ตารางน้ำหนักไม่ตรงยอดรวม OCR กรุณากรอกหมายเหตุผู้ตรวจก่อนอนุมัติ"
        }
        return "OCR/ตารางน้ำหนักยังไม่ผ่าน กรุณาตรวจชื่อ อปท. และตัวเลขที่อ่านได้"
    }

    private func commitPreviewToShare(_ payload: DocumentPreviewPayload) {
        previewPayload = nil
        do {
            sharePayload = try store.makeShareExportPayload(title: payload.title, files: payload.files)
        } catch {
            slipMessage = "เปิดหน้าต่าง Print / บันทึก ไม่สำเร็จ: \(error.localizedDescription)"
        }
    }

    private func approvalSensitiveFieldsChanged(_ oldValue: BillingLine, _ newValue: BillingLine) -> Bool {
        oldValue.weight != newValue.weight ||
        oldValue.unitRate != newValue.unitRate ||
        oldValue.amountBeforeVAT != newValue.amountBeforeVAT ||
        oldValue.vatPercent != newValue.vatPercent ||
        oldValue.withholdingPercent != newValue.withholdingPercent ||
        oldValue.weightSlipSourceFilename != newValue.weightSlipSourceFilename ||
        oldValue.weightSlipImageFilename != newValue.weightSlipImageFilename ||
        oldValue.weightSlipOCRCheckedAt != newValue.weightSlipOCRCheckedAt ||
        oldValue.weightEvidenceNote != newValue.weightEvidenceNote ||
        oldValue.slipTicketNo != newValue.slipTicketNo ||
        oldValue.weightTimeIn != newValue.weightTimeIn ||
        oldValue.weightTimeOut != newValue.weightTimeOut
    }
}

struct NumberField: View {
    let title: String
    @Binding var value: Double
    var focused: FocusState<BillingLineView.Field?>.Binding
    let field: BillingLineView.Field

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, value: $value, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .focused(focused, equals: field)
        }
    }
}
