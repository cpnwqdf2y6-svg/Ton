ThanyawitCustomer iPad Xcode v8

เพิ่มใน v8:
1) Document Control เลือกขนส่งได้
   - ไปรษณีย์ไทย
   - Flash Express

2) ตั้งค่าขนส่ง
   - Thailand Post API Token
   - Flash API Endpoint / Gateway URL
   - Flash API Token

3) เช็กสถานะออนไลน์
   - ไปรษณีย์ไทย: ต่อ REST API Track & Trace ได้เมื่อใส่ Token
   - Flash Express: รองรับผ่าน endpoint/API gateway ที่บริษัทมี หรือเปิดเว็บติดตามจากแอป

4) เช็กสถานะครบกำหนด
   - ระบบยังตั้งวันเช็กหลัง 2 วันทำการเหมือน v7
   - เพิ่มปุ่ม "เช็กสถานะที่ครบกำหนด"
   - เมื่อเช็กแล้วบันทึก status + วันที่ตรวจไว้หลังบ้าน

ข้อจำกัดตรง ๆ:
- แอป iPad เช็กได้เมื่อเปิดแอปและกดเช็ก
- ถ้าต้องการดึงสถานะอัตโนมัติหลัง 2 วันโดยไม่เปิดแอป ต้องมี backend/server worker
- Flash Express official/open API ต้องใช้ credential/endpoint ของบัญชีธุรกิจหรือระบบกลาง จึงทำเป็นช่องตั้งค่า endpoint ไว้ให้

วิธีใช้:
1) เปิดเมนู ตั้งค่าขนส่ง
2) ใส่ Token ไปรษณีย์ไทย
3) ถ้าใช้ Flash ให้ใส่ endpoint/token ของระบบกลาง
4) เปิด Document Control
5) เลือกขนส่ง + กรอกเลขพัสดุ
6) กดบันทึก หรือ เช็กออนไลน์
