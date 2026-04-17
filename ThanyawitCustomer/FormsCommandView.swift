import SwiftUI
import PDFKit

@MainActor
struct FormsCommandView: View {
    @EnvironmentObject private var store: CustomerStore
    @State private var showRegistered = false
    @State private var sharePayload: ShareExportPayload?
    @State private var previewPayload: DocumentPreviewPayload?
    @State private var exportMessage = ""
    @State private var showExportMessage = false

    var readyDocsCount: Int {
        store.selectedReadyCustomersForDocuments().count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ศูนย์สั่งงานเอกสาร")
                        .font(.largeTitle.bold())
                    Text("กดตรงนี้เพื่อไปงานที่ต้องการทันที ไม่ต้องไล่หาในเมนูส่งออก ถ้า PDF ใช้งานไม่ได้ให้ยึดทะเบียนคุมเอกสารและไปรษณีย์ CSV เป็นงานจริง")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("อนุมัติพร้อมปริ้นท์ \(readyDocsCount) รายการ")
                        .font(.headline)
                    Text("ถ้าเป็น 0 แปลว่ายังไม่ผ่านข้อมูลลูกค้า, OCR ใบชั่ง, ยอดคำนวณ หรือยังไม่ได้กดอนุมัติหลังตรวจพรีวิวในหน้ากรอกบิล")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        PrecheckView()
                    } label: {
                        Label("ตรวจความพร้อมก่อนออกเอกสาร", systemImage: "checklist.checked")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                commandButton(
                    title: "ไปแจ้งหนี้ / ใบแจ้งหนี้",
                    subtitle: "Export PDF ใบแจ้งหนี้อย่างเดียว",
                    systemImage: "doc.text.fill"
                ) {
                    exportInvoiceOnly()
                }

                commandButton(
                    title: "ไปใบกำกับภาษี",
                    subtitle: "Export PDF ใบเสร็จรับเงิน / ใบกำกับภาษี",
                    systemImage: "doc.richtext.fill"
                ) {
                    exportTaxInvoiceOnly()
                }

                commandButton(
                    title: "ไปใบส่งมอบงาน",
                    subtitle: "Export PDF ใบส่งมอบงานจ้างอย่างเดียว",
                    systemImage: "doc.append.fill"
                ) {
                    exportDeliveryOnly()
                }

                commandButton(
                    title: "ไปตารางสรุปน้ำหนัก",
                    subtitle: "Export PDF ตารางน้ำหนักพร้อมเวลาเข้า-ออก",
                    systemImage: "list.bullet.rectangle.portrait.fill"
                ) {
                    exportWeightSummaryOnly()
                }

                commandButton(
                    title: "ออกเอกสารครบชุด",
                    subtitle: "ใบแจ้งหนี้ + ใบกำกับภาษี + ใบส่งมอบงาน + ตารางสรุปน้ำหนัก",
                    systemImage: "doc.on.doc.fill"
                ) {
                    exportFullSet()
                }

                commandButton(
                    title: "บันทึกสำเนาเข้าทะเบียนคุมเอกสาร",
                    subtitle: "สร้าง 1 แถวต่อ 1 ลูกค้า สำหรับเอกสาร 4 ใบใน 1 ซอง",
                    systemImage: "tray.and.arrow.down.fill"
                ) {
                    guard readyDocsCount > 0 else {
                        showMessage("ยังไม่มีรายการพร้อมออก จึงยังไม่สร้างทะเบียนคุมเอกสาร")
                        return
                    }
                    store.registerDocumentControlForCurrentRun()
                    showRegistered = true
                }

                NavigationLink {
                    DocumentControlView()
                } label: {
                    navCard(
                        title: "ทะเบียนคุมเอกสาร/ไปรษณีย์",
                        subtitle: "กรอกเลขพัสดุ 1 อปท. ต่อ 1 ซอง / กดอัปเดตสถานะเอกสาร",
                        systemImage: "shippingbox.fill",
                        tint: .orange
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    TaxTimelineView()
                } label: {
                    navCard(
                        title: "ภาษี/หัก ณ ที่จ่าย",
                        subtitle: "อัปเดตสถานะหัก ณ ที่จ่าย / หลักฐานขอคืนภาษี",
                        systemImage: "bahtsign.circle.fill",
                        tint: .green
                    )
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .navigationTitle("สั่งงานเอกสาร")
        .sheet(item: $previewPayload) { payload in
            DocumentPreviewSheet(
                payload: payload,
                onPrintOrSave: { commitPreviewToShare($0) },
                onRegister: { registerAfterPreview($0) }
            )
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareSheet(urls: payload.urls)
        }
        .alert("บันทึกสำเนาแล้ว", isPresented: $showRegistered) {
            Button("ตกลง", role: .cancel) {}
        } message: {
            Text("ระบบบันทึก 1 แถวต่อ 1 อปท. แล้ว โดยถือว่าใบแจ้งหนี้ + ใบกำกับภาษี + ใบส่งมอบงาน + ตารางสรุปน้ำหนัก อยู่ในซองเดียวกันและใช้เลขพัสดุเดียว")
        }
        .alert("สถานะ", isPresented: $showExportMessage) {
            Button("ตกลง", role: .cancel) {}
        } message: {
            Text(exportMessage)
        }
    }

    private func commandButton(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            navCard(title: title, subtitle: subtitle, systemImage: systemImage, tint: .blue)
        }
        .buttonStyle(.plain)
    }

    private func navCard(title: String, subtitle: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func exportInvoiceOnly() {
        previewPDFs(
            title: "ใบแจ้งหนี้",
            files: [("invoice_forms.pdf", store.pdfForInvoiceForms())]
        )
    }

    private func exportTaxInvoiceOnly() {
        previewPDFs(
            title: "ใบกำกับภาษี",
            files: [("tax_invoice_forms.pdf", store.pdfForTaxInvoiceForms())]
        )
    }

    private func exportDeliveryOnly() {
        previewPDFs(
            title: "ใบส่งมอบงาน",
            files: [("delivery_forms.pdf", store.pdfForDeliveryForms())]
        )
    }

    private func exportWeightSummaryOnly() {
        previewPDFs(
            title: "ตารางสรุปน้ำหนัก",
            files: [("weight_summary_forms.pdf", store.pdfForWeightSummaryForms())]
        )
    }

    private func exportFullSet() {
        previewPDFs(
            title: "เอกสารครบชุด",
            files: [("document_full_set.pdf", store.pdfForRealForms())],
            canRegister: true
        )
    }

    private func previewPDFs(title: String, files: [(String, Data)], canRegister: Bool = false) {
        guard readyDocsCount > 0 else {
            showMessage("ยังไม่มีรายการพร้อมออกเอกสาร กรุณาเติมข้อมูลให้ผ่านเช็กลิสต์ก่อน")
            return
        }

        previewPayload = DocumentPreviewPayload(title: title, files: files, canRegister: canRegister)
    }

    private func commitPreviewToShare(_ payload: DocumentPreviewPayload) {
        previewPayload = nil
        do {
            sharePayload = try store.makeShareExportPayload(title: payload.title, files: payload.files)
        } catch {
            showMessage("เปิดหน้าต่างส่งออกไม่สำเร็จ: \(error.localizedDescription)")
        }
    }

    private func registerAfterPreview(_ payload: DocumentPreviewPayload) {
        guard payload.canRegister else { return }
        guard readyDocsCount > 0 else {
            showMessage("ยังไม่มีรายการพร้อมออก จึงยังไม่สร้างทะเบียนคุมเอกสาร")
            return
        }

        store.registerDocumentControlForCurrentRun()
        previewPayload = nil
        showRegistered = true
    }

    private func showMessage(_ text: String) {
        exportMessage = text
        showExportMessage = true
    }
}

struct DocumentPreviewPayload: Identifiable {
    let id = UUID()
    let title: String
    let files: [(filename: String, data: Data)]
    let canRegister: Bool
}

struct DocumentPreviewSheet: View {
    let payload: DocumentPreviewPayload
    let onPrintOrSave: (DocumentPreviewPayload) -> Void
    let onRegister: (DocumentPreviewPayload) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if payload.files.count > 1 {
                    Picker("ไฟล์ตัวอย่าง", selection: $selectedIndex) {
                        ForEach(payload.files.indices, id: \.self) { index in
                            Text(payload.files[index].filename).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                Text("ตรวจตัวอย่างก่อน แล้วค่อยเลือก Print / บันทึก / แชร์")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                PDFPreviewPane(data: payload.files[min(selectedIndex, payload.files.count - 1)].data)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
            }
            .navigationTitle(payload.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ปิด") { dismiss() }
                }

                ToolbarItemGroup(placement: .confirmationAction) {
                    if payload.canRegister {
                        Button("บันทึกคุมเอกสาร") {
                            onRegister(payload)
                        }
                    }

                    Button("Print / บันทึก") {
                        onPrintOrSave(payload)
                    }
                }
            }
        }
    }
}

struct PDFPreviewPane: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .systemGroupedBackground
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(data: data)
    }
}
