import SwiftUI

struct PrecheckView: View {
    @EnvironmentObject private var store: CustomerStore

    var body: some View {
        List {
            ForEach(store.allPrecheckResults()) { result in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.customer.agencyName)
                            .font(.headline)

                        Text("ก่อน VAT \(ThaiFormat.money(result.billing.amountBeforeVAT)) · สุทธิ \(ThaiFormat.money(result.billing.netAmount))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !result.reasons.isEmpty {
                            Text(result.reasons.joined(separator: ", "))
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
        .navigationTitle("เช็กก่อนออก")
    }
}
