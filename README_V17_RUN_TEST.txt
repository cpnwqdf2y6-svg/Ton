V17 RUN TEST

ทดสอบแบบ static test แล้ว:
- แก้ warning: var calendar -> let calendar
- ไม่มี private let ค้างใน extension
- มีเมนูสั่งงานเอกสาร
- มีปุ่มไปแจ้งหนี้ / ใบกำกับภาษี / ใบส่งมอบงาน
- มีปุ่มเพิ่ม/แก้ฐานลูกค้า
- มีปุ่มอัปเดตสถานะเอกสาร
- Bundle ID ใหม่: com.wongsaphat.thanyawitcustomer.v17
- ชื่อแอป: Thanyawit V17

หมายเหตุ:
sandbox ไม่มี Xcode/iOS SDK จึง build จริงให้ไม่ได้ ต้องกด Product > Clean Build Folder แล้ว Run บน Mac
