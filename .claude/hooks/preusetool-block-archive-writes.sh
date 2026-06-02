#!/usr/bin/env bash

set -euo pipefail

# CCB v0.3.2 PreToolUse hook: hook_block_archive_writes_before_review
# 真相源：references/kernel/guard-registry.md L4。
# 只在 Write/Edit 试图把 status 从非 archived 改为 archived 且 review_status != passed 时拒绝。

INPUT_JSON="$(cat)"

json_string() {
  local key="$1"
  printf '%s' "$INPUT_JSON" |
    tr '\n' ' ' |
    sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" |
    head -n 1
}

decode_json_text() {
  printf '%s' "$1" |
    sed 's/\\r//g; s/\\n/\
/g; s/\\"/"/g; s/\\t/	/g'
}

status_from_text() {
  awk -F: '
    /^[[:space:]-]*status[[:space:]]*:/ {
      value=$2
      sub(/#.*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^["'"'"']|["'"'"']$/, "", value)
      print value
      exit
    }
  '
}

state_value() {
  local key="$1"
  local file="$2"
  awk -F: -v key="$key" '
    $1 ~ "^[[:space:]-]*" key "[[:space:]]*$" {
      value=$2
      sub(/#.*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^["'"'"']|["'"'"']$/, "", value)
      print value
      exit
    }
  ' "$file"
}

tool_name="$(json_string tool_name)"
case "$tool_name" in
  Write|Edit) ;;
  *) exit 0 ;;
esac

cwd="$(json_string cwd)"
if [[ -z "$cwd" ]]; then
  cwd="$(pwd)"
fi

file_path="$(json_string file_path)"
if [[ -z "$file_path" ]]; then
  file_path="$(json_string path)"
fi
if [[ -z "$file_path" ]]; then
  exit 0
fi

case "$file_path" in
  /*) target_path="$file_path" ;;
  *) target_path="$cwd/$file_path" ;;
esac
target_path="${target_path//\\//}"

case "$target_path" in
  */docs/.ccb/specs/archive/*|*/docs/.ccb/state/*) ;;
  *) exit 0 ;;
esac

content="$(decode_json_text "$(json_string content)")"
old_string="$(decode_json_text "$(json_string old_string)")"
new_string="$(decode_json_text "$(json_string new_string)")"

old_status=""
new_status=""

if [[ "$tool_name" == "Edit" ]]; then
  old_status="$(printf '%s\n' "$old_string" | status_from_text || true)"
  new_status="$(printf '%s\n' "$new_string" | status_from_text || true)"
else
  if [[ -f "$target_path" ]]; then
    old_status="$(status_from_text < "$target_path" || true)"
  fi
  new_status="$(printf '%s\n' "$content" | status_from_text || true)"
fi

if [[ "$new_status" != "archived" || "$old_status" == "archived" ]]; then
  exit 0
fi

state_dir="$cwd/docs/.ccb/state"
state_file=""

case "$target_path" in
  */docs/.ccb/state/*)
    state_file="$target_path"
    ;;
  *)
    base_name="$(basename "$target_path")"
    task_key="${base_name%.*}"
    for candidate in "$state_dir/$task_key.md" "$state_dir/$task_key.yaml" "$state_dir/$task_key.yml"; do
      if [[ -f "$candidate" ]]; then
        state_file="$candidate"
        break
      fi
    done
    if [[ -z "$state_file" && -d "$state_dir" ]]; then
      state_file="$(grep -rl "task_id:[[:space:]]*$task_key" "$state_dir" 2>/dev/null | head -n 1 || true)"
    fi
    ;;
esac

review_status=""
if [[ -n "$state_file" && -f "$state_file" ]]; then
  review_status="$(state_value review_status "$state_file")"
  if [[ -z "$review_status" ]]; then
    review_status="$(state_value reviewStatus "$state_file")"
  fi
fi

if [[ "$review_status" != "passed" ]]; then
  echo "归档前必须 review passed。" >&2
  exit 2
fi

exit 0
