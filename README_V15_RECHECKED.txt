V15 RECHECKED

ตรวจจาก V14 แล้วพบจุดที่ต้องระวัง:
- V14 แก้ MainActor แบบกว้างไป อาจใส่ @MainActor ในไฟล์ extension/utility ที่ไม่จำเป็น
- ตรวจซ้ำให้แล้ว และลบ @MainActor ที่ไม่ควรอยู่หน้า extension CustomerStore / FileDocument
- ยืนยันให้เฉพาะ View ที่เรียก PDF exporter อยู่บน MainActor

สิ่งที่ต้องเห็นหลังลง:
- ชื่อแอป: Thanyawit V15
- Dashboard มี V15
- เมนูมี:
  1) เพิ่ม/แก้ฐานลูกค้า
  2) ลูกค้า
  3) กรอกออกบิล
  4) สั่งงานเอกสาร
  5) รับส่งไปรษณีย์
  6) Timeline ภาษี
  7) ตั้งค่าขนส่ง
  8) ส่งออก

ปุ่มสั่งงานเอกสารต้องมี:
- ไปแจ้งหนี้ / ใบแจ้งหนี้
- ไปใบกำกับภาษี
- ไปใบส่งมอบงาน
- ออกเอกสารครบชุด
- บันทึกสำเนาเข้า Document Control

วิธีลง:
1) ปิด Xcode
2) แตก ZIP V15
3) เปิด ThanyawitCustomer.xcodeproj จากโฟลเดอร์ V15 เท่านั้น
4) Signing & Capabilities เลือก Team เดิม
5) Product > Clean Build Folder
6) Run
