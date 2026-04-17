ใช้ตัวนี้เมื่อเจอ error:
The item at ThanyawitCustomer.app is not a valid bundle

v3 clean แก้โดย:
- ให้ Xcode สร้าง Info.plist เอง
- ลบ custom Info.plist ที่ทำให้ bundle เพี้ยน
- ปรับการอ่าน customers.json ให้หาได้ทั้ง root และ Resources
- ใช้ Bundle Identifier: com.wongsaphat.thanyawitcustomer

วิธีใช้แบบสะอาด:
1) ปิด Xcode
2) บน iPad ลบแอป ThanyawitCustomer/ธัญญวิชญ์ ถ้ามี
3) ใน Mac ลบโฟลเดอร์ DerivedData:
   Finder > Go > Go to Folder...
   ~/Library/Developer/Xcode/DerivedData
   แล้วลบโฟลเดอร์ที่ขึ้นต้น ThanyawitCustomer
4) แตก ZIP v3
5) เปิด ThanyawitCustomer.xcodeproj จากโฟลเดอร์ v3
6) เลือก Team ใน Signing & Capabilities
7) Product > Clean Build Folder
8) กด Run
