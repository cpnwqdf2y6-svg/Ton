import SwiftUI

struct TrackingSettingsView: View {
    @AppStorage("thanyawit.tracking.thailandpost.token") private var thaiPostToken: String = ""
    @AppStorage("thanyawit.tracking.flash.endpoint") private var flashEndpoint: String = ""
    @AppStorage("thanyawit.tracking.flash.token") private var flashToken: String = ""

    var body: some View {
        Form {
            Section("ไปรษณีย์ไทย") {
                SecureField("Thailand Post API Token", text: $thaiPostToken)
                Text("ใช้กับ Track & Trace REST API ของไปรษณีย์ไทย เมื่อมี Token แล้วกดเช็กสถานะจากหน้าทะเบียนคุมเอกสารได้")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Flash Express") {
                TextField("Flash API Endpoint / Gateway URL", text: $flashEndpoint)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                SecureField("Flash API Token / Bearer Token", text: $flashToken)
                Text("ถ้ายังไม่มี API ของ Flash ให้ใช้ปุ่มเปิดเว็บติดตามในหน้าทะเบียนคุมเอกสารก่อน หรือใช้ API gateway/ระบบกลางของบริษัท")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("หมายเหตุ") {
                Text("แอป iPad เช็กออนไลน์ได้เมื่อเปิดแอปและกดเช็กสถานะ หากต้องการให้ดึงสถานะอัตโนมัติหลัง 2 วันโดยไม่เปิดแอป ต้องมี backend/server worker เพิ่ม")
                    .foregroundStyle(.orange)
            }
        }
        .navigationTitle("ตั้งค่าขนส่ง")
    }
}
