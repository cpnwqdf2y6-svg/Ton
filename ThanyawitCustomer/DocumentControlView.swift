import SwiftUI

struct DocumentControlView: View {
    @EnvironmentObject private var store: CustomerStore
    @Environment(\.openURL) private var openURL

    @AppStorage("thanyawit.tracking.thailandpost.token") private var thaiPostToken: String = ""
    @AppStorage("thanyawit.tracking.flash.endpoint") private var flashEndpoint: String = ""
    @AppStorage("thanyawit.tracking.flash.token") private var flashToken: String = ""

    @State private var records: [DocumentControlRecord] = []
    @State private var showCreatedAlert = false
    @State private var message = ""
    @State private var showMessage = false
    @State private var checkingID: String?
    @State private var showOnlyNeedsUpdate = false

    var needsUpdateRecords: [DocumentControlRecord] {
        store.documentsNeedingStatusUpdate()
    }

    var displayRecords: [DocumentControlRecord] {
        showOnlyNeedsUpdate ? records.filter { item in
            needsUpdateRecords.contains(where: { $0.id == item.id })
        } : records
    }

    var body: some View {
        VStack(spacing: 0) {
            alertPanel

            HStack {
                Button {
                    store.registerDocumentControlForCurrentRun()
                    records = store.loadDocumentControls()
                    showCreatedAlert = true
                } label: {
                    Label("สร้างทะเบียนจากรายการที่อนุมัติแล้ว", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task { await checkNeedsUpdateItems() }
                } label: {
                    Label("กดอัปเดตสถานะเอกสาร", systemImage: "bell.badge")
                }
                .buttonStyle(.borderedProminent)
                .tint(needsUpdateRecords.isEmpty ? .gray : .orange)

                Toggle("โชว์เฉพาะที่ต้องกด", isOn: $showOnlyNeedsUpdate)
                    .toggleStyle(.button)

                Spacer()
            }
            .padding()

            List {
                if displayRecords.isEmpty {
                    ContentUnavailableView(
                        showOnlyNeedsUpdate ? "ไม่มีรายการที่ต้องกดอัปเดต" : "ยังไม่มีรายการเอกสาร",
                        systemImage: showOnlyNeedsUpdate ? "checkmark.circle" : "doc",
                        description: Text(showOnlyNeedsUpdate ? "ถ้าต้องการดูทั้งหมด ให้ปิดปุ่มโชว์เฉพาะที่ต้องกด" : "ให้สร้างชุดควบคุมเอกสารจากงวดก่อน")
                    )
                } else {
                    ForEach($records) { $record in
                        if !showOnlyNeedsUpdate || needsUpdateRecords.contains(where: { $0.id == record.id }) {
                            documentRow(record: $record)
                        }
                    }
                }
            }
        }
        .navigationTitle("ทะเบียนคุมเอกสาร")
        .toolbar {
            NavigationLink {
                TaxTimelineView()
            } label: {
                Label("ภาษี", systemImage: "bahtsign.circle")
            }

            NavigationLink {
                TrackingSettingsView()
            } label: {
                Label("ตั้งค่าขนส่ง", systemImage: "gear")
            }
        }
        .onAppear {
            records = store.loadDocumentControls()
        }
        .alert("สร้างชุดควบคุมเอกสารแล้ว", isPresented: $showCreatedAlert) {
            Button("ตกลง", role: .cancel) {}
        } message: {
            Text("ระบบสร้าง 1 แถวต่อ 1 อปท. แล้ว โดยควบคุมใบแจ้งหนี้ + ใบกำกับภาษี + ใบส่งมอบงาน + ตารางสรุปน้ำหนัก เป็นชุดเดียว ใช้เลขพัสดุเดียว")
        }
        .alert("สถานะ", isPresented: $showMessage) {
            Button("ตกลง", role: .cancel) {}
        } message: {
            Text(message)
        }
    }

    private var alertPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: needsUpdateRecords.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(needsUpdateRecords.isEmpty ? .green : .orange)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(needsUpdateRecords.isEmpty ? "สถานะเอกสารปกติ" : "ต้องกดอัปเดตสถานะเอกสาร")
                        .font(.headline)
                    Text(store.documentStatusAlertText())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !needsUpdateRecords.isEmpty {
                    Text("\(needsUpdateRecords.count)")
                        .font(.title2.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.orange.opacity(0.18))
                        .clipShape(Capsule())
                }
            }

            if !needsUpdateRecords.isEmpty {
                Button {
                    showOnlyNeedsUpdate = true
                    Task { await checkNeedsUpdateItems() }
                } label: {
                    Label("กดเพื่ออัปเดตสถานะทั้งหมดที่ต้องเช็ก", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding()
        .background(needsUpdateRecords.isEmpty ? Color.green.opacity(0.08) : Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding([.horizontal, .top])
    }

    @ViewBuilder
    private func documentRow(record: Binding<DocumentControlRecord>) -> some View {
        let needsUpdate = needsUpdateRecords.contains(where: { $0.id == record.wrappedValue.id })

        DisclosureGroup {
            Picker("ขนส่ง", selection: record.carrier) {
                Text("ไปรษณีย์ไทย").tag("ไปรษณีย์ไทย")
                Text("Flash Express").tag("Flash Express")
            }
            .pickerStyle(.segmented)

            TextField("เลขพัสดุ", text: record.trackingNo)
                .textInputAutocapitalization(.characters)

            TextField("เลขหนังสือส่งออก / เลขที่นำส่ง", text: record.outgoingBookNo)
            TextField("วันที่ส่งออก", text: record.outgoingDate)
            TextField("ผู้ส่ง / ผู้บันทึกส่งออก", text: record.outgoingBy)
            TextField("สถานะจัดส่ง", text: record.deliveryStatus)
            TextField("วันที่ตรวจสถานะ", text: record.deliveryCheckedAt)
            TextField("วันที่หน่วยงานรับเข้า", text: record.receivedDate)
            TextField("ผู้รับเอกสาร", text: record.receiverName)
            TextField("เลขรับเข้าของหน่วยงาน", text: record.incomingBookNo)
            TextField("ชุดเอกสาร/สำเนา", text: record.copySetNote, axis: .vertical)
                .lineLimit(1...3)
            TextField("LINE ID ผู้รับเอกสาร", text: record.lineRecipientId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("วันที่เวลาส่ง LINE", text: record.lineSentAt)
            TextField("หมายเหตุ", text: record.note, axis: .vertical)
                .lineLimit(2...4)

            HStack {
                Button("บันทึกสถานะ") {
                    save(record.wrappedValue)
                }

                Button("บันทึกว่าส่ง LINE แล้ว") {
                    var edited = record.wrappedValue
                    if edited.lineRecipientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        edited.lineRecipientId = "wongsapust"
                    }
                    edited.lineSentAt = ThaiDate.nowDateTimeText()
                    save(edited)
                }

                Button {
                    Task { await checkStatus(for: record.wrappedValue) }
                } label: {
                    if checkingID == record.wrappedValue.id {
                        ProgressView()
                    } else {
                        Label(needsUpdate ? "ต้องกดอัปเดต" : "เช็กออนไลน์", systemImage: needsUpdate ? "bell.badge" : "network")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(needsUpdate ? .orange : .blue)
                .disabled(checkingID != nil)

                Button {
                    openTrackingURL(record.wrappedValue)
                } label: {
                    Label("เปิดเว็บติดตาม", systemImage: "safari")
                }
            }
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(record.wrappedValue.documentNo) · \(record.wrappedValue.documentType)")
                        .font(.headline)
                    Text(record.wrappedValue.agencyName)
                        .font(.subheadline)
                    Text("\(record.wrappedValue.carrier) · ส่ง: \(record.wrappedValue.sentDate) · เช็กหลัง: \(record.wrappedValue.checkDueDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("เลขส่ง: \(record.wrappedValue.outgoingBookNo.isEmpty ? "-" : record.wrappedValue.outgoingBookNo) · รับเข้า: \(record.wrappedValue.receivedDate.isEmpty ? "-" : record.wrappedValue.receivedDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("พัสดุ: \(record.wrappedValue.trackingNo.isEmpty ? "-" : record.wrappedValue.trackingNo)")
                        .font(.caption)
                    Text("LINE: \(record.wrappedValue.lineRecipientId.isEmpty ? "wongsapust" : record.wrappedValue.lineRecipientId) · ส่ง: \(record.wrappedValue.lineSentAt.isEmpty ? "-" : record.wrappedValue.lineSentAt)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(record.wrappedValue.deliveryStatus)
                        .font(.caption.bold())
                        .foregroundStyle(statusColor(record.wrappedValue.deliveryStatus))
                }

                Spacer()

                if needsUpdate {
                    VStack(spacing: 4) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(.orange)
                        Text("ต้องกด")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        if status.contains("สำเร็จ") || status.contains("นำจ่าย") || status.contains("Delivered") || status.contains("delivered") {
            return .green
        }
        if status.contains("ล้มเหลว") || status.contains("error") || status.contains("Error") {
            return .red
        }
        return .orange
    }

    private func save(_ record: DocumentControlRecord) {
        var edited = record
        if edited.deliveryCheckedAt.isEmpty && !edited.trackingNo.isEmpty {
            edited.deliveryCheckedAt = ThaiDate.todayText()
        }
        if !edited.trackingNo.isEmpty && edited.deliveryStatus == "รอกรอกเลขพัสดุ" {
            edited.deliveryStatus = "รอตรวจสถานะหลัง 2 วันทำการ"
        }
        if edited.outgoingDate.isEmpty {
            edited.outgoingDate = edited.sentDate
        }
        if !edited.receivedDate.isEmpty && edited.deliveryStatus != "เอกสารรับเข้าแล้ว" {
            edited.deliveryStatus = "เอกสารรับเข้าแล้ว"
        }
        store.updateDocumentControl(edited)
        records = store.loadDocumentControls()
    }

    private func openTrackingURL(_ record: DocumentControlRecord) {
        if let url = TrackingService.trackingURL(for: record) {
            openURL(url)
        } else {
            message = "กรุณากรอกเลขพัสดุก่อน"
            showMessage = true
        }
    }

    private func checkStatus(for record: DocumentControlRecord) async {
        checkingID = record.id
        defer { checkingID = nil }

        do {
            let status = try await TrackingService.track(
                record: record,
                thaiPostToken: thaiPostToken,
                flashEndpoint: flashEndpoint,
                flashToken: flashToken
            )
            var edited = record
            edited.deliveryStatus = status
            edited.deliveryCheckedAt = ThaiDate.todayText()
            store.updateDocumentControl(edited)
            records = store.loadDocumentControls()
            message = "อัปเดตสถานะแล้ว"
            showMessage = true
        } catch {
            message = error.localizedDescription
            showMessage = true
        }
    }

    private func checkNeedsUpdateItems() async {
        let items = needsUpdateRecords
        if items.isEmpty {
            message = "ยังไม่มีรายการที่ต้องกดอัปเดตสถานะ"
            showMessage = true
            return
        }

        for item in items {
            await checkStatus(for: item)
        }
    }
}
