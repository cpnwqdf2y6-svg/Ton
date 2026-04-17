import SwiftUI

struct MasterDataView: View {
    @EnvironmentObject private var store: CustomerStore
    @State private var showAdd = false
    @State private var showResetConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("กู้/รีเซ็ตฐานลูกค้า")
                    .font(.title2.bold())
                Text("ใช้เฉพาะกรณีฐานลูกค้าหายในเครื่อง หรือจำเป็นต้องดึงชุดข้อมูลซ่อมกลับมาใหม่")
                    .foregroundStyle(.secondary)

                HStack {
                    Button {
                        showAdd = true
                    } label: {
                        Label("เพิ่มข้อมูลลูกค้าใหม่", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("รีเซ็ตฐานในเครื่อง", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(.blue.opacity(0.08))

            List {
                ForEach(store.customers) { customer in
                    NavigationLink {
                        CustomerEditView(customer: customer, mode: .edit)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(customer.agencyName.isEmpty ? "(ยังไม่ใส่ชื่อหน่วยงาน)" : customer.agencyName)
                                .font(.headline)
                            Text("ภาษี: \(customer.taxId.isEmpty ? "ยังไม่กรอก" : customer.taxId) · สัญญา: \(customer.contractNo.isEmpty ? "ยังไม่กรอก" : customer.contractNo)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("ที่อยู่: \(customer.agencyAddress.isEmpty ? "ยังไม่กรอก" : customer.agencyAddress)")
                                .font(.caption2)
                                .foregroundStyle(customer.agencyAddress.isEmpty ? .orange : .secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        store.deleteCustomer(store.customers[index])
                    }
                }
            }
        }
        .navigationTitle("กู้ฐานลูกค้า")
        .toolbar {
            Button {
                showAdd = true
            } label: {
                Label("เพิ่ม", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                CustomerEditView(customer: Customer.blank(nextCode: store.nextCustomerCode()), mode: .add)
            }
            .environmentObject(store)
        }
        .alert("รีเซ็ตฐานในเครื่อง?", isPresented: $showResetConfirm) {
            Button("ยกเลิก", role: .cancel) {}
            Button("รีเซ็ต", role: .destructive) {
                store.resetLocalCustomersToBundledData()
            }
        } message: {
            Text("ใช้เมื่อคุณลงแอปใหม่แล้วข้อมูลยังเหมือนเดิม เพราะ iPad เก็บข้อมูลเก่าไว้ในเครื่อง")
        }
    }
}
