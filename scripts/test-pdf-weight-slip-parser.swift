import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("❌ \(message)\n", stderr)
        exit(1)
    }
}

func expectClose(_ actual: Double?, _ expected: Double, tolerance: Double = 0.0001, _ message: String) {
    guard let actual else {
        fputs("❌ \(message) (actual=nil)\n", stderr)
        exit(1)
    }
    if abs(actual - expected) > tolerance {
        fputs("❌ \(message) (actual=\(actual), expected=\(expected), tolerance=\(tolerance))\n", stderr)
        exit(1)
    }
}

let thaiSlipText = """
เลขที่ใบชั่ง 670123
เวลาเข้า 13:55
เวลาออก 14:10
น้ำหนักรวม 26,540 kg
น้ำหนักรถ 8,320 kg
น้ำหนักสุทธิ 18,220 kg
"""

let parsed = PDFWeightSlipParser.parse(thaiSlipText)
expectClose(parsed.grossTon, 26.54, "gross should parse to 26.54 ton")
expectClose(parsed.tareTon, 8.32, "tare should parse to 8.32 ton")
expectClose(parsed.netTon, 18.22, "net should parse to 18.22 ton")
expect(parsed.timeIn == "13:55", "timeIn should be 13:55")
expect(parsed.timeOut == "14:10", "timeOut should be 14:10")
expect(parsed.timeIn != parsed.timeOut, "timeIn/timeOut should not duplicate")

let rows = PDFWeightSlipParser.parseRows(thaiSlipText)
let flattenedNumbers = rows.flatMap(\.numbers)
expect(!flattenedNumbers.contains(13), "13 from 13:55 must not be treated as weight")
expect(!flattenedNumbers.contains(55), "55 from 13:55 must not be treated as weight")

let dottedTimeText = """
ชั่งเข้า 13.55 26,540 kg
ชั่งออก 14.10 8,320 kg
"""
let dottedRows = PDFWeightSlipParser.parseRows(dottedTimeText)
let dottedNumbers = dottedRows.flatMap(\.numbers)
expect(!dottedNumbers.contains(13), "13 from 13.55 must not be treated as weight")
expect(!dottedNumbers.contains(55), "55 from 13.55 must not be treated as weight")
expect(!dottedNumbers.contains(14), "14 from 14.10 must not be treated as weight")
expect(!dottedNumbers.contains(10), "10 from 14.10 must not be treated as weight")

let noSeparatorTimeRows = PDFWeightSlipParser.parseRows("เวลาเข้า 1355\nน้ำหนักรวม 26540 kg")
let noSeparatorNumbers = noSeparatorTimeRows.flatMap(\.numbers)
expect(!noSeparatorNumbers.contains(13), "13 from 1355 must not be treated as weight")
expect(!noSeparatorNumbers.contains(55), "55 from 1355 must not be treated as weight")

expectClose(PDFWeightSlipParser.parse("น้ำหนักรวม 26540 kg").grossTon, 26.54, "weight without comma should normalize to ton")
expectClose(PDFWeightSlipParser.parse("น้ำหนักรวม 2654 kg").grossTon, 2.654, "4-digit weight should not be stripped as time")
expectClose(PDFWeightSlipParser.parse("เลขที่เอกสาร 2654\nน้ำหนักรวม 26540 kg").grossTon, 26.54, "document number-like 4 digits must not strip valid 5-digit weight")

let noisyTimeRows = PDFWeightSlipParser.parseRows("เวลาเข้า 13-55\nเวลาออก 13 55\nน้ำหนักรวม 26,540 kg")
let noisyTimeNumbers = noisyTimeRows.flatMap(\.numbers)
expect(!noisyTimeNumbers.contains(13), "13 from 13-55/13 55 must not be treated as weight")
expect(!noisyTimeNumbers.contains(55), "55 from 13-55/13 55 must not be treated as weight")

let noSeparatorInOut = PDFWeightSlipParser.parse("""
เวลาเข้า 1355
เวลาออก 1410
น้ำหนักรวม 26540 kg
""")
expectClose(noSeparatorInOut.grossTon, 26.54, "weight should parse correctly with 1355/1410 time lines")
let noSeparatorInOutRows = PDFWeightSlipParser.parseRows("""
เวลาเข้า 1355
เวลาออก 1410
น้ำหนักรวม 26540 kg
""")
let noSeparatorInOutNumbers = noSeparatorInOutRows.flatMap(\.numbers)
expect(!noSeparatorInOutNumbers.contains(13), "13 from 1355 must not be treated as weight in in/out case")
expect(!noSeparatorInOutNumbers.contains(55), "55 from 1355 must not be treated as weight in in/out case")
expect(!noSeparatorInOutNumbers.contains(14), "14 from 1410 must not be treated as weight in in/out case")
expect(!noSeparatorInOutNumbers.contains(10), "10 from 1410 must not be treated as weight in in/out case")

let mixedUnitParsed = PDFWeightSlipParser.parse("น้ำหนักรวม 26.54 t\nน้ำหนักสุทธิ 26540 kg")
expectClose(mixedUnitParsed.grossTon, 26.54, "26.54 t should remain 26.54 ton")
expectClose(mixedUnitParsed.netTon, 26.54, "26540 kg should normalize to 26.54 ton")

let thaiOcrVariant1 = PDFWeightSlipParser.parse("นํ้าหนักสุทธิ 18,220 kg")
expectClose(thaiOcrVariant1.netTon, 18.22, "n\u{e4d}a variant should parse net")
let thaiOcrVariant2 = PDFWeightSlipParser.parse("น้ําหนักสุทธิ 18,220 kg")
expectClose(thaiOcrVariant2.netTon, 18.22, "n\u{e49}\u{e4d}a variant should parse net")

expectClose(parsed.confidence, 1.0, tolerance: 0.000001, "confidence should be clamped to 1.0 for high quality slips")

print("✅ PDFWeightSlipParser Thai OCR parsing tests passed")
