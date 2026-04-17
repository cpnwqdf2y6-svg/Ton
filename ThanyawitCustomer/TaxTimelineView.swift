import SwiftUI

struct TaxTimelineView: View {
    @EnvironmentObject private var store: CustomerStore
    @State private var records: [WithholdingTaxRecord] = []

    var totalWithholding: Double {
        records.reduce(0) { $0 + $1.withholdingAmount }
    }

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text("ยอดหัก ณ ที่จ่ายรวม")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ThaiFormat.money(totalWithholding))
                        .font(.title.bold())
                }
                Spacer()
            }
            .padding()

            List {
                ForEach($records) { $record in
                    DisclosureGroup {
                        TextField("สถานะภาษี", text: $record.taxStatus)
                        TextField("หมายเหตุ/หลักฐาน", text: $record.evidenceNote, axis: .vertical)
                            .lineLimit(2...4)
                        Button("บันทึก") {
                            store.updateWithholdingTax(record)
                            records = store.loadWithholdingRecords()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.agencyName)
                                .font(.headline)
                            Text("\(record.servicePeriod) · \(record.documentNo)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("ฐาน \(ThaiFormat.money(record.amountBeforeVAT)) · หัก \(ThaiFormat.money(record.withholdingAmount))")
                                .font(.caption)
                            Text(record.taxStatus)
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("ภาษี/หัก ณ ที่จ่าย")
        .onAppear {
            records = store.loadWithholdingRecords()
        }
    }
}
