#if canImport(SwiftUI)
import SwiftUI

struct WDATAImportView: View {
    let isImporting: Bool
    let message: String
    let pendingRecordCount: Int
    let reviewNotes: [String]
    let onPickFiles: () -> Void
    let onApplyImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("แนบใบชั่งหลายใบ แล้วให้ระบบแยก อปท.")
                        .font(.headline)
                    Text("นำเข้าไฟล์ WDATA/CSV/TXT จาก Files เพื่อแยกข้อมูลน้ำหนักและจับคู่เข้าบิล")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onPickFiles) {
                    Label("Import TXT/CSV from Files", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImporting)
            }

            if isImporting {
                ProgressView("กำลัง OCR และแยกใบชั่ง...")
                    .font(.caption)
            }

            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if pendingRecordCount > 0 {
                HStack {
                    Text("Preview: พบ \(pendingRecordCount) records รอยืนยันบันทึก")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("ยืนยันนำเข้าไฟล์", action: onApplyImport)
                        .buttonStyle(.borderedProminent)
                        .disabled(isImporting)
                }
            }

            if !reviewNotes.isEmpty {
                DisclosureGroup("รายการที่ต้องตรวจสอบก่อนนำเข้า") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(reviewNotes.enumerated()), id: \.offset) { _, note in
                            Text("• \(note)")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
}
#endif
