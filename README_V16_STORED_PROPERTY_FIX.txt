V16 STORED PROPERTY FIX

แก้ error:
Extensions must not contain stored properties

สาเหตุ:
ใน Swift ห้ามใส่ property แบบเก็บค่าไว้จริง เช่น private let companyTaxId = "..."
ไว้ใน extension CustomerStore

สิ่งที่แก้:
- เปลี่ยน private let ใน extension ให้เป็น computed property เช่น
  private var companyTaxId: String { "0755563000935" }
- เปลี่ยน Bundle ID ใหม่เป็น com.wongsaphat.thanyawitcustomer.v16
- เปลี่ยนชื่อแอปเป็น Thanyawit V16

วิธีใช้:
1) ปิด Xcode
2) แตก ZIP V16
3) เปิด ThanyawitCustomer.xcodeproj จากโฟลเดอร์ V16
4) Signing & Capabilities เลือก Team เดิม
5) Product > Clean Build Folder
6) Run
