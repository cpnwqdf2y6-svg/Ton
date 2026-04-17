ThanyawitCustomer iPad Xcode v5

แก้ตามคำสั่ง:
- โลโก้ไม่ขึ้น: v5 ฝังโลโก้เข้า Swift โดยตรง ไม่ต้องพึ่ง resource
- เพิ่ม/แก้ข้อมูลลูกค้าได้ในแอป:
  ที่อยู่, เลขสัญญา, วันที่สัญญา, เลขผู้เสียภาษี, เลขโครงการ, ชื่อหน่วยงาน
- เพิ่มลูกค้าใหม่ได้ด้วยปุ่ม + ในหน้าลูกค้า
- บันทึกข้อมูลลงเครื่อง iPad ผ่าน UserDefaults
- Export CSV ยังใช้ได้

วิธีใช้:
1) ปิด Xcode เดิม
2) แตก ZIP v5
3) เปิด ThanyawitCustomer.xcodeproj
4) Signing & Capabilities เลือก Team เดิม
5) Product > Clean Build Folder
6) กด Run

หมายเหตุ:
- CSV คือข้อมูลตารางสำหรับเปิด Excel/นำไปใช้ต่อ ไม่ใช่ฟอร์ม PDF
- ถ้าต้องการแบบฟอร์มใบแจ้งหนี้/ใบส่งมอบงานจริง ต้องทำ v6 PDF Export
