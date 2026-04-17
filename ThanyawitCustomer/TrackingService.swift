import Foundation
import UIKit

enum TrackingServiceError: LocalizedError {
    case missingTrackingNo
    case missingThaiPostToken
    case missingFlashEndpoint
    case invalidURL
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingTrackingNo:
            return "ยังไม่ได้กรอกเลขพัสดุ"
        case .missingThaiPostToken:
            return "ยังไม่ได้ใส่ Token ไปรษณีย์ไทย"
        case .missingFlashEndpoint:
            return "Flash Express ต้องใส่ API endpoint หรือใช้ปุ่มเปิดเว็บติดตาม"
        case .invalidURL:
            return "URL ไม่ถูกต้อง"
        case .server(let text):
            return text
        }
    }
}

enum TrackingService {
    static func trackingURL(for record: DocumentControlRecord) -> URL? {
        guard !record.trackingNo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        if record.carrier == "Flash Express" {
            return URL(string: "https://www.flashexpress.com/fle/tracking")
        } else {
            return URL(string: "https://track.thailandpost.co.th/")
        }
    }

    static func track(
        record: DocumentControlRecord,
        thaiPostToken: String,
        flashEndpoint: String,
        flashToken: String
    ) async throws -> String {
        let trackingNo = record.trackingNo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trackingNo.isEmpty else { throw TrackingServiceError.missingTrackingNo }

        if record.carrier == "Flash Express" {
            return try await trackFlash(trackingNo: trackingNo, endpoint: flashEndpoint, token: flashToken)
        } else {
            return try await trackThaiPost(trackingNo: trackingNo, token: thaiPostToken)
        }
    }

    private static func trackThaiPost(trackingNo: String, token: String) async throws -> String {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else { throw TrackingServiceError.missingThaiPostToken }

        guard let url = URL(string: "https://trackapi.thailandpost.co.th/post/api/v1/track") else {
            throw TrackingServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(cleanToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "status": "all",
            "language": "TH",
            "barcode": [trackingNo]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TrackingServiceError.server("ไม่ได้รับ response จากไปรษณีย์ไทย")
        }

        let raw = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(http.statusCode) else {
            throw TrackingServiceError.server("ThaiPost API error \(http.statusCode): \(raw.prefix(300))")
        }

        if let json = try? JSONSerialization.jsonObject(with: data),
           let summary = summarizeThaiPost(json) {
            return summary
        }

        return raw.isEmpty ? "เช็กสำเร็จ แต่ไม่มีข้อความสถานะ" : String(raw.prefix(500))
    }

    private static func summarizeThaiPost(_ object: Any) -> String? {
        var found: [String] = []

        func walk(_ value: Any) {
            if let dict = value as? [String: Any] {
                let keys = ["status_description", "status", "location", "postcode", "delivery_datetime", "status_date", "description"]
                let parts = keys.compactMap { key -> String? in
                    if let s = dict[key] as? String, !s.isEmpty { return s }
                    if let n = dict[key] as? NSNumber { return n.stringValue }
                    return nil
                }
                if !parts.isEmpty {
                    found.append(parts.joined(separator: " · "))
                }
                for v in dict.values { walk(v) }
            } else if let arr = value as? [Any] {
                for item in arr { walk(item) }
            }
        }

        walk(object)
        if let latest = found.last {
            return "ไปรษณีย์ไทย: \(latest)"
        }
        return nil
    }

    private static func trackFlash(trackingNo: String, endpoint: String, token: String) async throws -> String {
        let cleanEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEndpoint.isEmpty else { throw TrackingServiceError.missingFlashEndpoint }
        guard let url = URL(string: cleanEndpoint) else { throw TrackingServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "tracking_no": trackingNo,
            "trackingNo": trackingNo,
            "carrier": "flash"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let raw = String(data: data, encoding: .utf8) ?? ""

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw TrackingServiceError.server("Flash API error \(http.statusCode): \(raw.prefix(300))")
        }

        if raw.isEmpty {
            return "Flash Express: เช็กสำเร็จ แต่ไม่มีข้อความสถานะ"
        }
        return "Flash Express: \(raw.prefix(500))"
    }
}
