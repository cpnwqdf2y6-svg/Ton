#!/usr/bin/env bash
set -euo pipefail

# Ensure repository has a non-empty README with a top-level heading.
test -s README.md
rg -n '^#\s+.+$' README.md >/dev/null

echo "Repository structure checks passed."
