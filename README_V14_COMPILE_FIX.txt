V14 COMPILE FIX

แก้ error:
Call to main actor-isolated instance method 'pdfForInvoiceForms()' in a synchronous nonisolated context
Call to main actor-isolated instance method 'pdfForTaxInvoiceForms()' in a synchronous nonisolated context
Call to main actor-isolated instance method 'pdfForDeliveryForms()' in a synchronous nonisolated context
Call to main actor-isolated instance method 'pdfForRealForms()' in a synchronous nonisolated context

สิ่งที่แก้:
- เพิ่ม @MainActor ให้ View ที่เรียก pdfFor...()
- เปลี่ยน Bundle ID ใหม่เป็น com.wongsaphat.thanyawitcustomer.v14
- เปลี่ยนชื่อแอปเป็น Thanyawit V14

วิธีใช้:
1) ปิด Xcode
2) แตก ZIP V14
3) เปิด ThanyawitCustomer.xcodeproj จากโฟลเดอร์ V14
4) Signing & Capabilities เลือก Team เดิม
5) Product > Clean Build Folder
6) Run
