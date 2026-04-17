import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ExportView: View {
    @EnvironmentObject private var store: CustomerStore
    @State private var sharePayload: ShareExportPayload?
    @State private var exportMessage = ""
    @State private var showExportMessage = false
    @State private var csvDocument = CSVDocument()
    @State private var csvFilename = "export.csv"
    @State private var showCSVExporter = false

    var body: some View {
        Form {
            Section("ส่งออกชุดงานสุดท้าย") {
                Button {
                    shareFinalPackage()
                } label: {
                    Label("แชร์ชุดไฟนอลไป Google Drive / Files", systemImage: "externaldrive.badge.checkmark")
                }

                Text("ใช้ปุ่มนี้หลังอนุมัติบิลแล้ว ระบบจะแนบเอกสารจริง PDF, Billing CSV, Customers CSV, ทะเบียนคุมเอกสาร CSV และตารางหัก ณ ที่จ่าย CSV ไปที่ Share Sheet เพื่อเลือก Google Drive หรือ Files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("สำรองข้อมูลตาราง") {
                Button {
                    exportCSV(filename: "thanyawit_billing.csv", text: store.csvForBilling())
                } label: {
                    Label("Billing CSV", systemImage: "tablecells")
                }

                Button {
                    exportCSV(filename: "thanyawit_customers.csv", text: store.csvForCustomers())
                } label: {
                    Label("Customers CSV", systemImage: "building.2.crop.circle")
                }

                Button {
                    exportCSV(filename: "thanyawit_document_control.csv", text: store.csvForDocumentControl())
                } label: {
                    Label("ทะเบียนคุมเอกสาร CSV", systemImage: "tray.full")
                }

                Button {
                    exportCSV(filename: "thanyawit_withholding_tax.csv", text: store.csvForWithholdingTax())
                } label: {
                    Label("หัก ณ ที่จ่าย CSV", systemImage: "bahtsign.circle")
                }
            }

            Section("รายงาน PDF หลังบ้าน") {
                Button {
                    shareFile(title: "รายงาน PDF", files: [
                        ("thanyawit_billing_report.pdf", store.pdfForBillingReport()),
                        ("thanyawit_customers_report.pdf", store.pdfForCustomersReport()),
                        ("thanyawit_document_control.pdf", store.pdfForDocumentControl()),
                        ("thanyawit_tax_timeline.pdf", store.pdfForTaxTimeline()),
                        ("thanyawit_weight_summary_forms.pdf", store.pdfForWeightSummaryForms())
                    ])
                } label: {
                    Label("แชร์รายงาน PDF", systemImage: "doc.richtext")
                }
            }

            Section("กู้ข้อมูลฉุกเฉิน") {
                Button {
                    if let folder = store.writeEmergencyExportFiles() {
                        showMessage("สร้างไฟล์กู้ข้อมูลแล้ว: \(folder.path)")
                    } else {
                        showMessage("สร้างไฟล์กู้ข้อมูลไม่สำเร็จ")
                    }
                } label: {
                    Label("สร้างไฟล์กู้ข้อมูลในเครื่อง", systemImage: "externaldrive.badge.timemachine")
                }

                Text("ปุ่มนี้จะเขียน CSV/JSON ลง Documents/ThanyawitEmergencyExport แล้วให้โหลด container จาก Xcode อีกครั้ง")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("สรุประบบ") {
                LabeledContent("ลูกค้าทั้งหมด", value: "\(store.customers.count)")
                LabeledContent("พร้อมออก", value: "\(store.readyCount)")
                LabeledContent("รอตรวจ", value: "\(store.reviewCount)")
                LabeledContent("เดือนงาน", value: store.servicePeriod)
                LabeledContent("วันที่เอกสาร", value: store.documentDate)
            }

            Section("คำเตือน") {
                Text("ปุ่มแชร์จะเปิด Share Sheet ของ iPad ให้เลือก Google Drive/Files เอง แอปตรวจได้ว่าไฟล์ถูกสร้างครบ แต่ตรวจสิทธิ์ปลายทาง Google Drive ไม่ได้ถ้าผู้ใช้ยังไม่ได้เลือกโฟลเดอร์ปลายทาง")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareSheet(urls: payload.urls)
        }
        .fileExporter(
            isPresented: $showCSVExporter,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: csvFilename
        ) { result in
            switch result {
            case .success:
                showMessage("บันทึกไฟล์ \(csvFilename) แล้ว")
            case .failure(let error):
                showMessage("บันทึก CSV ไม่สำเร็จ: \(error.localizedDescription)")
            }
        }
        .alert("สถานะ", isPresented: $showExportMessage) {
            Button("ตกลง", role: .cancel) {}
        } message: {
            Text(exportMessage)
        }
        .navigationTitle("ส่งออก")
    }

    private func shareFinalPackage() {
        guard !store.selectedReadyCustomersForDocuments().isEmpty else {
            showMessage("ยังไม่มีรายการที่อนุมัติพร้อมออกเอกสาร ให้กลับไปตรวจใบชั่งและกดอนุมัติบิลก่อน")
            return
        }

        shareFile(title: "Thanyawit Final Package", files: [
            ("thanyawit_final_documents.pdf", store.pdfForRealForms()),
            ("thanyawit_billing.csv", Data(("\u{FEFF}" + store.csvForBilling()).utf8)),
            ("thanyawit_customers.csv", Data(("\u{FEFF}" + store.csvForCustomers()).utf8)),
            ("thanyawit_document_control.csv", Data(("\u{FEFF}" + store.csvForDocumentControl()).utf8)),
            ("thanyawit_withholding_tax.csv", Data(("\u{FEFF}" + store.csvForWithholdingTax()).utf8))
        ])
    }

    private func exportCSV(filename: String, text: String) {
        csvFilename = filename
        csvDocument = CSVDocument(text: text)
        showCSVExporter = true
    }

    private func shareFile(title: String, files: [(String, Data)]) {
        do {
            sharePayload = try store.makeShareExportPayload(title: title, files: files)
        } catch {
            showMessage("เปิดหน้าต่างส่งออกไม่สำเร็จ: \(error.localizedDescription)")
        }
    }

    private func showMessage(_ text: String) {
        exportMessage = text
        showExportMessage = true
    }
}
