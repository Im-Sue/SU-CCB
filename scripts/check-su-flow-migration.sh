#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f "README.md" || ! -d "docs" ]]; then
  echo "ERROR: run scripts/check-su-flow-migration.sh from the repository root." >&2
  exit 2
fi

include_paths=(
  "README.md"
  "docs/install.md"
  "docs/requirements.md"
  "docs/release-notes"
  "docs/.ccb/templates/prompts"
)

allowed_pattern='(\[Deprecated\]|\(now /ccb:su-flow\)|历史|legacy)'
unexpected=()

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  if [[ ! "$line" =~ $allowed_pattern ]]; then
    unexpected+=("$line")
  fi
done < <(
  rg --line-number --with-filename --no-heading \
    --glob '*.md' \
    --glob '!docs/.ccb/decisions/**' \
    '/ccb:su-plan' \
    "${include_paths[@]}" || true
)

if (( ${#unexpected[@]} > 0 )); then
  echo "ERROR: unexpected /ccb:su-plan references remain:" >&2
  printf '%s\n' "${unexpected[@]}" >&2
  echo "Use /ccb:su-flow for user-facing entry references, or mark the line as deprecated/history." >&2
  exit 1
fi

echo "OK: no unexpected /ccb:su-plan references remain in user-facing migration paths."
