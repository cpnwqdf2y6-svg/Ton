from pathlib import Path
content = "customer_code,customer_name,ticket_no,net_weight,date\nA004,อบต.ตัวอย่าง,TK-1004,900,02/05/2569\n"
Path('ThanyawitCustomer/ParserFixtures/wdata_cp874.csv').write_bytes(content.encode('cp874'))
print('wrote ThanyawitCustomer/ParserFixtures/wdata_cp874.csv in cp874')
