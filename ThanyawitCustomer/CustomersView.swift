import SwiftUI

struct CustomersView: View {
    @EnvironmentObject private var store: CustomerStore
    @State private var showAddCustomer = false

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ฐานลูกค้า")
                    .font(.title3.bold())
                Text("เพิ่มหรือแก้ข้อมูลหลักของ อปท. ที่อยู่ เลขภาษี สัญญา และ LINE ก่อนออกเอกสาร")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    showAddCustomer = true
                } label: {
                    Label("เพิ่มลูกค้าใหม่ / เพิ่มข้อมูล", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            HStack {
                TextField("ค้นหาหน่วยงาน / อำเภอ / รหัส / เลขภาษี / เลขสัญญา", text: $store.searchText)
                    .textFieldStyle(.roundedBorder)

                Picker("กลุ่ม", selection: $store.groupFilter) {
                    Text("ทั้งหมด").tag("ทั้งหมด")
                    Text("จ้างขน").tag("จ้างขน")
                    Text("เก็บขน").tag("เก็บขน")
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                Picker("สถานะ", selection: $store.statusFilter) {
                    Text("ทั้งหมด").tag("ทั้งหมด")
                    Text("พร้อมออก").tag("พร้อมออก")
                    Text("รอตรวจ").tag("รอตรวจ")
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)

            List {
                ForEach(store.filteredCustomers) { customer in
                    NavigationLink {
                        CustomerDetailView(customer: customer)
                    } label: {
                        CustomerRow(customer: customer)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        let customer = store.filteredCustomers[index]
                        store.deleteCustomer(customer)
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("ฐานลูกค้า")
        .toolbar {
            Button {
                showAddCustomer = true
            } label: {
                Label("เพิ่ม", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showAddCustomer) {
            NavigationStack {
                CustomerEditView(customer: Customer.blank(nextCode: store.nextCustomerCode()), mode: .add)
            }
            .environmentObject(store)
        }
    }
}

struct CustomerRow: View {
    @EnvironmentObject private var store: CustomerStore
    let customer: Customer

    var body: some View {
        let result = store.precheck(for: customer)

        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(customer.agencyName.isEmpty ? "(ยังไม่ใส่ชื่อหน่วยงาน)" : customer.agencyName)
                    .font(.headline)
                Text("\(customer.customerCode) · \(customer.customerGroup) · \(customer.districtName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("ภาษี: \(customer.taxId.isEmpty ? "-" : customer.taxId) · สัญญา: \(customer.contractNo.isEmpty ? "-" : customer.contractNo)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("LINE: \(customer.lineId.isEmpty ? "wongsapust" : customer.lineId) · ส่งล่าสุด: \(customer.lastLineSentAt.isEmpty ? "-" : customer.lastLineSentAt)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !result.reasons.isEmpty {
                    Text("ขาด: \(result.reasons.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()
            StatusBadge(status: result.status)
        }
        .padding(.vertical, 4)
    }
}

struct CustomerDetailView: View {
    @EnvironmentObject private var store: CustomerStore
    @Environment(\.openURL) private var openURL
    let customer: Customer
    @State private var showEdit = false
    @State private var showLineSent = false

    var liveCustomer: Customer {
        store.customers.first(where: { $0.id == customer.id }) ?? customer
    }

    var body: some View {
        let current = liveCustomer
        let result = store.precheck(for: current)
        let line = store.billingLine(for: current)

        Form {
            Section("ปุ่มทำงาน") {
                Button {
                    showEdit = true
                } label: {
                    Label("แก้ไขข้อมูลลูกค้านี้", systemImage: "pencil.circle.fill")
                }

                Button {
                    if let url = store.lineShareURL(for: current) {
                        openURL(url)
                        store.markLineSent(for: current)
                        showLineSent = true
                    }
                } label: {
                    Label("ส่งข้อความ LINE ให้ \(current.lineId.isEmpty ? "wongsapust" : current.lineId)", systemImage: "paperplane.circle.fill")
                }
            }

            Section("ข้อมูลหน่วยงาน") {
                LabeledContent("รหัส", value: current.customerCode)
                LabeledContent("หน่วยงาน", value: current.agencyName)
                LabeledContent("กลุ่ม", value: current.customerGroup)
                LabeledContent("อำเภอ", value: current.districtName)
                LabeledContent("จังหวัด", value: current.provinceName)
                LabeledContent("ที่อยู่", value: current.agencyAddress)
            }

            Section("ข้อมูลภาษี/สัญญา") {
                LabeledContent("เลขผู้เสียภาษี", value: current.taxId)
                LabeledContent("เลขสัญญา", value: current.contractNo)
                LabeledContent("วันที่สัญญา", value: current.contractDate)
                LabeledContent("เลขโครงการ", value: current.projectNo)
            }

            Section("งวดออกบิล") {
                LabeledContent("น้ำหนัก/จำนวน", value: ThaiFormat.plain(line.weight))
                LabeledContent("ยอดก่อน VAT", value: ThaiFormat.money(line.amountBeforeVAT))
                LabeledContent("VAT", value: ThaiFormat.money(line.vatAmount))
                LabeledContent("หัก ณ ที่จ่าย", value: ThaiFormat.money(line.withholdingAmount))
                LabeledContent("สุทธิ", value: ThaiFormat.money(line.netAmount))
            }

            Section("LINE / งานเอกสาร") {
                LabeledContent("LINE ID", value: current.lineId.isEmpty ? "wongsapust" : current.lineId)
                LabeledContent("งานเอกสารเสร็จ", value: current.documentWorkCompletedAt.isEmpty ? "-" : current.documentWorkCompletedAt)
                LabeledContent("ส่ง LINE ล่าสุด", value: current.lastLineSentAt.isEmpty ? "-" : current.lastLineSentAt)
                Text("ปุ่ม LINE จะเปิดหน้าส่งข้อความใน LINE ให้ตรวจอีกครั้งก่อนกดส่งจริง และระบบบันทึกเวลาที่กดส่งไว้ในฐานลูกค้า")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("สถานะ") {
                StatusBadge(status: result.status)
                if !result.reasons.isEmpty {
                    Text(result.reasons.joined(separator: ", "))
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle(current.agencyShort.isEmpty ? current.agencyName : current.agencyShort)
        .toolbar {
            Button {
                showEdit = true
            } label: {
                Label("แก้ไข", systemImage: "pencil")
            }
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                CustomerEditView(customer: current, mode: .edit)
            }
            .environmentObject(store)
        }
        .alert("บันทึกเวลาส่ง LINE แล้ว", isPresented: $showLineSent) {
            Button("ตกลง", role: .cancel) {}
        } message: {
            Text("ระบบบันทึกเวลาที่กดส่งไว้แล้ว กรุณาตรวจใน LINE อีกครั้งก่อนกดส่งข้อความจริง")
        }
    }
}

struct CustomerEditView: View {
    enum Mode { case add, edit }

    @EnvironmentObject private var store: CustomerStore
    @Environment(\.dismiss) private var dismiss

    @State var customer: Customer
    let mode: Mode

    var body: some View {
        Form {
            Section("ข้อมูลหลัก") {
                TextField("รหัสลูกค้า", text: $customer.customerCode)
                TextField("ชื่อหน่วยงาน", text: $customer.agencyName)
                TextField("ชื่อย่อ", text: $customer.agencyShort)
                Picker("กลุ่มงาน", selection: $customer.customerGroup) {
                    Text("จ้างขน").tag("จ้างขน")
                    Text("เก็บขน").tag("เก็บขน")
                }
                TextField("ประเภทหน่วยงาน", text: $customer.agencyType)
                TextField("อำเภอ", text: $customer.districtName)
                TextField("จังหวัด", text: $customer.provinceName)
            }

            Section("ข้อมูลออกเอกสาร — ช่องที่ต้องเพิ่ม") {
                TextField("ชื่อในเอกสาร", text: $customer.documentName)
                TextField("ที่อยู่", text: $customer.agencyAddress, axis: .vertical)
                    .lineLimit(2...5)
                TextField("เลขผู้เสียภาษี", text: $customer.taxId)
                    .keyboardType(.numberPad)
                TextField("เลขสัญญา", text: $customer.contractNo)
                TextField("วันที่สัญญา เช่น 28/01/2569", text: $customer.contractDate)
                TextField("เลขโครงการ", text: $customer.projectNo)
            }

            Section("ค่าตั้งต้นออกบิล") {
                TextField("รายได้ฐาน 2569", value: $customer.baseRevenue2569, format: .number)
                    .keyboardType(.decimalPad)
                TextField("น้ำหนักฐาน 2569", value: $customer.baseWeight2569, format: .number)
                    .keyboardType(.decimalPad)
                TextField("หน่วยราคา", value: $customer.unitRateDefault, format: .number)
                    .keyboardType(.decimalPad)
                TextField("VAT %", value: $customer.vatPercent, format: .number)
                    .keyboardType(.decimalPad)
                TextField("หัก ณ ที่จ่าย %", value: $customer.whtPercent, format: .number)
                    .keyboardType(.decimalPad)
            }

            Section("หมายเหตุ") {
                TextField("หมายเหตุภายใน", text: $customer.internalNote, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("LINE / งานเอกสารเสร็จแล้ว") {
                TextField("LINE ID ลูกค้า", text: $customer.lineId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("เวลางานเอกสารเสร็จ เช่น 15/04/2569 14:30", text: $customer.documentWorkCompletedAt)
                TextField("ส่ง LINE ล่าสุด", text: $customer.lastLineSentAt)

                Button("ตั้งเวลางานเสร็จเป็นตอนนี้") {
                    customer.documentWorkCompletedAt = ThaiDate.nowDateTimeText()
                }

                Text("ค่าเริ่มต้นตอนนี้ใช้ LINE ID wongsapust ก่อน เปลี่ยนเป็นของลูกค้าจริงได้ภายหลัง")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(mode == .add ? "เพิ่มลูกค้าใหม่" : "แก้ไขลูกค้า")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("ยกเลิก") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("บันทึก") {
                    if customer.id.isEmpty {
                        customer.id = customer.customerCode.isEmpty ? store.nextCustomerCode() : customer.customerCode
                    }
                    if customer.customerCode.isEmpty { customer.customerCode = customer.id }
                    if customer.documentName.isEmpty { customer.documentName = customer.agencyName }
                    if customer.agencyShort.isEmpty { customer.agencyShort = customer.agencyName }
                    if customer.lineId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        customer.lineId = "wongsapust"
                    }

                    switch mode {
                    case .add:
                        store.addCustomer(customer)
                    case .edit:
                        store.updateCustomer(customer)
                    }
                    dismiss()
                }
                .disabled(customer.agencyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
