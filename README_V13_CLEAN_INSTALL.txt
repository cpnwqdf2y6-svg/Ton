V13 CLEAN INSTALL

แก้ปัญหา:
- Failed to install the app on the device
- The item at ThanyawitCustomer.app is not a valid bundle

สิ่งที่แก้:
- ใช้ Xcode generated Info.plist เท่านั้น
- ตัด custom INFOPLIST_FILE ที่อาจทำให้ bundle เพี้ยน
- ใช้ Bundle ID ใหม่: com.wongsaphat.thanyawitcustomer.v13
- ใช้ Display Name แบบปลอดภัย: Thanyawit V13
- ตั้ง iPad orientations ครบ 4 ทิศทาง
- ลดปัญหา cache โดยให้เป็นแอปใหม่ชัดเจน

วิธีลง:
1) กด Cancel หน้า Feedback for Xcode
2) ปิด Xcode
3) ลบแอปเก่าบน iPad
4) ลบ DerivedData อีกครั้ง
5) แตก ZIP V13
6) เปิด ThanyawitCustomer.xcodeproj จากโฟลเดอร์ V13
7) เลือก Team เดิม
8) Product > Clean Build Folder
9) Run

หลังลงสำเร็จ บน iPad ต้องเห็นชื่อแอป: Thanyawit V13
