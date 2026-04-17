แอป iPad จริง | บริษัท ธัญญวิชญ์ จำกัด
เวอร์ชัน: Xcode Project v1

ไฟล์นี้ไม่ใช่ PWA แล้ว เป็น Xcode Project สำหรับติดตั้งลง iPad จริง

วิธีติดตั้งลง iPad:
1) แตก ZIP
2) เปิดไฟล์ ThanyawitCustomer.xcodeproj ด้วย Xcode บน Mac
3) เลือก Target: ThanyawitCustomer
4) ไปที่ Signing & Capabilities
5) เลือก Apple Developer Team ของคุณ
6) ต่อ iPad mini 7 ด้วยสาย USB-C
7) บน iPad เปิด Developer Mode ถ้าเครื่องถาม
8) กด Run ▶ ใน Xcode เพื่อติดตั้งลงเครื่อง

ค่าโครงการ:
- Bundle ID: com.thanyawit.customerdb
- Platform: iPad / iOS
- Minimum iOS: 17.0
- Framework: SwiftUI
- ฐานข้อมูลตั้งต้น: Resources/customers.json
- ลูกค้าทั้งหมด: 20
- พร้อมออกตั้งต้น: 4
- รอตรวจตั้งต้น: 16

ข้อจำกัดตรง ๆ:
- ยังไม่ได้ build/sign เป็น IPA เพราะต้องใช้ Mac + Xcode + Apple Developer Team
- ถ้าจะกระจายในองค์กร แนะนำ TestFlight / Apple Business Manager / MDM
- ถ้าจะเพิ่ม PDF ใบแจ้งหนี้จริง ให้ทำต่อเป็น v2 module PDF Export
