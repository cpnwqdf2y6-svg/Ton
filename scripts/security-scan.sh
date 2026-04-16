#!/usr/bin/env bash
set -euo pipefail

# Lightweight secret-pattern scan to catch common regressions.
# This intentionally focuses on high-signal patterns to reduce false positives.
patterns=(
  'AKIA[0-9A-Z]{16}'
  '-----BEGIN (RSA|EC|OPENSSH|DSA|PRIVATE) KEY-----'
  'ghp_[A-Za-z0-9]{36}'
  'xox[baprs]-[A-Za-z0-9-]{10,}'
)

for pattern in "${patterns[@]}"; do
  if rg -n --hidden --glob '!.git' -e "$pattern" .; then
    echo "Potential secret detected for pattern: $pattern" >&2
    exit 1
  fi
done

echo "Security scan passed (no high-signal secret patterns found)."
