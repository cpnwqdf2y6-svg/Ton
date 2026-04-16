#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$repo_root/scripts/ci-check.sh"
"$repo_root/scripts/security-scan.sh"

echo "All checks passed. Repository is ready for upload."
