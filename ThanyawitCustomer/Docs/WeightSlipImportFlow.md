# Weight Slip Import Flow

```text
User selects WDATA / CSV / TXT
        |
        v
BillingView
(choose file + preview + result UI only)
        |
        v
Data
        |
        v
Thai decode fallback
UTF-8 -> CP874 -> TIS-620 -> CP1252
        |
        v
String
        |
        v
CodableCSVTableReader
        |
        v
WDATARecord[]
        |
        v
WDATAImportValidator
        |
        v
PASS / NEEDS REVIEW / REJECT
        |
        v
WeightSlipRecord preview rows
        |
        v
User confirms import
        |
        v
CustomerStore.importWeightSlipRecords
- duplicate detection
- customer matching
- save billing line
```

Boundary rules:
- BillingView = choose files, preview, result UI only.
- WindaWDATAParser = WDATA/CSV/TXT parsing.
- CodableCSVTableReader = CSV engine only.
- CustomerStore = duplicate detection, customer matching, saving.
