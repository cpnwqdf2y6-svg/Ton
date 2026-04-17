แก้ปัญหา Xcode: The item at ThanyawitCustomer.app is not a valid bundle

สาเหตุ:
โปรเจกต์ v1 มี Info.plist แบบสั้นเกินไป ทำให้ตอนติดตั้งลง iPad บางเครื่อง Xcode มอง .app เป็น bundle ไม่สมบูรณ์

สิ่งที่แก้ใน v2:
- เพิ่ม CFBundleExecutable
- เพิ่ม CFBundleIdentifier
- เพิ่ม CFBundleInfoDictionaryVersion
- เพิ่ม CFBundleName
- เพิ่ม CFBundlePackageType = APPL
- เพิ่ม CFBundleVersion / ShortVersion
- เปลี่ยน Bundle Identifier เป็น com.wongsaphat.thanyawitcustomer
- ตัดการบังคับ AppIcon ที่ยังไม่มี asset catalog จริง

วิธีใช้:
1) ปิด Xcode
2) ลบแอป ThanyawitCustomer/ธัญญวิชญ์ บน iPad ถ้ามี
3) เปิดโปรเจกต์ v2
4) Signing & Capabilities เลือก Team เดิม
5) Product > Clean Build Folder
6) กด Run ใหม่
