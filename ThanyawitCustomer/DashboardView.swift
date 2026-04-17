import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject private var store: CustomerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CompanyLogoView(maxHeight: 150)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ระบบออกบิลและควบคุมเอกสาร")
                        .font(.largeTitle.bold())
                    Text("บริษัท ธัญญวิชญ์ จำกัด")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("ลำดับทำงานที่ปลอดภัย")
                        .font(.headline)
                    Text("1 ฐานลูกค้า → 2 ตรวจใบชั่งด้วย OCR และอนุมัติบิล → 3 สั่งปริ้นท์เอกสาร → 4 คุมส่งออก/รับเข้าในทะเบียนคุมเอกสาร → 5 สำรองข้อมูล")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    KPI(title: "ลูกค้าทั้งหมด", value: "\(store.customers.count)", systemImage: "building.2")
                    KPI(title: "พร้อมออก", value: "\(store.readyCount)", systemImage: "checkmark.seal")
                    KPI(title: "รอตรวจ", value: "\(store.reviewCount)", systemImage: "exclamationmark.triangle")
                    KPI(title: "ยอดก่อน VAT", value: ThaiFormat.money(store.totalAmountBeforeVAT), systemImage: "bahtsign.circle")
                }

                ProfitLossSummaryPanel()

                let docUpdateCount = store.documentsNeedingStatusUpdate().count
                if docUpdateCount > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(.orange)
                            Text("เอกสารต้องอัปเดตสถานะ")
                                .font(.headline)
                            Spacer()
                            Text("\(docUpdateCount)")
                                .font(.title3.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.orange.opacity(0.18))
                                .clipShape(Capsule())
                        }
                        Text("เข้าเมนูทะเบียนคุมเอกสาร แล้วกดปุ่มอัปเดตสถานะเอกสาร")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("รายการที่ต้องเติมก่อนออกเอกสาร")
                        .font(.headline)

                    let reviewItems = store.allPrecheckResults().filter { !$0.isReady }.prefix(8)
                    if reviewItems.isEmpty {
                        Label("พร้อมทั้งหมด", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        ForEach(Array(reviewItems), id: \.id) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading) {
                                    Text(item.customer.agencyName)
                                        .font(.subheadline.bold())
                                    Text(item.reasons.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                StatusBadge(status: item.status)
                            }
                            Divider()
                        }
                    }
                }
                .padding()
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .padding()
        }
        .navigationTitle("ภาพรวม")
    }
}

struct ProfitLossSummaryPanel: View {
    @EnvironmentObject private var store: CustomerStore
    @State private var costAmount: Double = 0
    @State private var savedMessage = ""

    private var draft: MonthlyProfitRecord {
        store.profitDraft(costAmount: costAmount)
    }

    private var chartRecords: [MonthlyProfitRecord] {
        var records = store.monthlyProfitRecords
        let current = draft
        if let index = records.firstIndex(where: { $0.servicePeriod == current.servicePeriod }) {
            records[index] = current
        } else {
            records.append(current)
        }
        return Array(records.suffix(12))
    }

    var body: some View {
        let current = draft

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("กำไรขาดทุนรายเดือน")
                        .font(.title2.bold())
                    Text("สรุปจากบิลเดือน \(store.servicePeriod) ใช้ยอดก่อน VAT เป็นยอดขาย และกรอกต้นทุนรวมเพื่อคำนวณกำไรโดยประมาณ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(current.profitAmount >= 0 ? "กำไร" : "ขาดทุน")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background((current.profitAmount >= 0 ? Color.green : Color.red).opacity(0.16))
                    .foregroundStyle(current.profitAmount >= 0 ? .green : .red)
                    .clipShape(Capsule())
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                ProfitKPI(title: "ยอดขาย", value: ThaiFormat.money(current.salesBeforeVAT), tint: .blue)
                ProfitKPI(title: "รายรับสุทธิ", value: ThaiFormat.money(current.netReceipt), tint: .teal)
                ProfitKPI(title: "ต้นทุน", value: ThaiFormat.money(current.costAmount), tint: .orange)
                ProfitKPI(title: current.profitAmount >= 0 ? "กำไร" : "ขาดทุน", value: ThaiFormat.money(abs(current.profitAmount)), tint: current.profitAmount >= 0 ? .green : .red)
                ProfitKPI(title: "Margin", value: "\(ThaiFormat.plain(current.profitMargin))%", tint: .purple)
            }

            HStack {
                TextField("ต้นทุนรวมเดือนนี้", value: $costAmount, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)

                Button {
                    let saved = store.upsertMonthlyProfitRecord(costAmount: costAmount)
                    savedMessage = "บันทึก \(saved.servicePeriod) ลงกราฟแล้ว"
                } label: {
                    Label("บันทึกเดือนนี้ลงกราฟ", systemImage: "chart.xyaxis.line")
                }
                .buttonStyle(.borderedProminent)

                if !savedMessage.isEmpty {
                    Text(savedMessage)
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()
            }

            Chart {
                ForEach(chartRecords) { record in
                    BarMark(
                        x: .value("เดือน", record.servicePeriod),
                        y: .value("บาท", record.salesBeforeVAT)
                    )
                    .foregroundStyle(by: .value("รายการ", "ยอดขาย"))

                    BarMark(
                        x: .value("เดือน", record.servicePeriod),
                        y: .value("บาท", record.costAmount)
                    )
                    .foregroundStyle(by: .value("รายการ", "ต้นทุน"))

                    LineMark(
                        x: .value("เดือน", record.servicePeriod),
                        y: .value("บาท", record.profitAmount)
                    )
                    .foregroundStyle(record.profitAmount >= 0 ? Color.green : Color.red)
                    .symbol(Circle())
                }

                RuleMark(y: .value("คุ้มทุน", 0))
                    .foregroundStyle(.secondary.opacity(0.45))
            }
            .frame(height: 260)
            .chartYAxisLabel("บาท")
            .chartLegend(position: .bottom)

            Text("หมายเหตุ: VAT และหัก ณ ที่จ่ายแสดงเพื่อดูเงินไหลเข้า-ออก แต่กำไรใช้ยอดขายก่อน VAT ลบต้นทุนรวม เพื่อไม่ปนภาษีที่เป็นเงินผ่าน")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.secondary.opacity(0.12))
        }
        .onAppear {
            costAmount = store.costForCurrentPeriod()
        }
        .onChange(of: store.servicePeriod) { _, _ in
            costAmount = store.costForCurrentPeriod()
            savedMessage = ""
        }
    }
}

struct ProfitKPI: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct KPI: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
            Text(value)
                .font(.title.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status)
            .font(.caption.bold())
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(status == "พร้อมออก" ? Color.green.opacity(0.16) : Color.orange.opacity(0.18))
            .foregroundStyle(status == "พร้อมออก" ? .green : .orange)
            .clipShape(Capsule())
    }
}
