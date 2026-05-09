#!/usr/bin/env bash
set -euo pipefail

# Ensure repository has a non-empty README with a top-level heading.
test -s README.md
rg -n '^#\s+.+$' README.md >/dev/null

# Parser regression checks for Thai OCR weight slips.
swift ThanyawitCustomer/PDFWeightSlipParser.swift scripts/test-pdf-weight-slip-parser.swift

echo "Repository structure checks passed."
