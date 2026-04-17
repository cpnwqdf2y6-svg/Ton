import Foundation

enum ThaiFormat {
    static func displayText(_ value: String, empty: String = "-") -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? empty : trimmed
    }

    static func money(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "th_TH")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }

    static func plain(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "th_TH")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    static func displayDate(_ iso: String) -> String {
        guard !iso.isEmpty else { return "" }
        let input = ISO8601DateFormatter()
        guard let date = input.date(from: iso + "T00:00:00Z") else {
            return iso
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "th_TH")
        formatter.calendar = Calendar(identifier: .buddhist)
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
