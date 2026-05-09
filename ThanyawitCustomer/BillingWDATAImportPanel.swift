#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers

struct BillingWDATAImportPanel: View {
    let isImporting: Bool
    let message: String
    let pendingRecordCount: Int
    let reviewNotes: [String]

    let onPickFiles: () -> Void
    let onApplyImport: () -> Void

    var body: some View {
        WDATAImportView(
            isImporting: isImporting,
            message: message,
            pendingRecordCount: pendingRecordCount,
            reviewNotes: reviewNotes,
            onPickFiles: onPickFiles,
            onApplyImport: onApplyImport
        )
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
}
#endif
