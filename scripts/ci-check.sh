#!/usr/bin/env bash
set -euo pipefail

# Ensure repository has a non-empty README with a top-level heading.
test -s README.md
rg -n '^#\s+.+$' README.md >/dev/null

# Validate helper scripts.
shopt -s nullglob
scripts=(scripts/*.sh)

if [ ${#scripts[@]} -eq 0 ]; then
  echo "No shell scripts found in scripts/." >&2
  exit 1
fi

for script in "${scripts[@]}"; do
  if [ ! -x "$script" ]; then
    echo "Script is not executable: $script" >&2
    exit 1
  fi

  read -r first_line < "$script"
  if [[ "$first_line" != '#!'* ]]; then
    echo "Missing shebang in script: $script" >&2
    exit 1
  fi
done

echo "Repository structure checks passed."
