#!/usr/bin/env bash

set -euo pipefail

# CCB v0.3.3 PreToolUse hook: hook_block_mutation_on_forbidden_paths
# 规则：禁止无授权修改 canonical / manifest / hotfix / archived artifacts。

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

normalize_path() {
  local raw="${1//\\//}"
  if [[ "$raw" =~ ^([A-Za-z]):/(.*)$ ]]; then
    local drive
    drive="$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')"
    printf '/mnt/%s/%s' "$drive" "${BASH_REMATCH[2]}"
  else
    printf '%s' "$raw"
  fi
}

repo_rel_path() {
  local cwd="$1"
  local raw="$2"
  local path
  path="$(normalize_path "$raw")"
  if [[ "$path" != /* ]]; then
    path="$cwd/$path"
  fi
  path="${path//\/.\//\/}"
  if [[ "$path" == "$cwd/"* ]]; then
    printf '%s' "${path#"$cwd/"}"
  else
    printf '%s' "$path"
  fi
}

yaml_value() {
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

state_file_for_task() {
  local state_dir="$1"
  local task_id="$2"
  if [[ -n "$task_id" && -f "$state_dir/$task_id.md" ]]; then
    printf '%s' "$state_dir/$task_id.md"
    return 0
  fi
  if [[ -n "$task_id" && -d "$state_dir" ]]; then
    local matched
    # state 文件名可能带日期前缀，必须按 frontmatter task_id 精确匹配。
    matched="$(grep -rl "^[[:space:]]*task_id:[[:space:]]*$task_id[[:space:]]*$" "$state_dir"/*.md 2>/dev/null | head -n 1 || true)"
    if [[ -n "$matched" ]]; then
      printf '%s' "$matched"
      return 0
    fi
  fi
  if [[ -d "$state_dir" ]]; then
    local candidate status
    while IFS= read -r candidate; do
      status="$(yaml_value status "$candidate")"
      if [[ "$status" != "archived" && "$status" != "completed" ]]; then
        printf '%s' "$candidate"
        return 0
      fi
    done < <(ls -t "$state_dir"/*.md 2>/dev/null || true)
  fi
}

state_file_with_override_for_rel() {
  local state_dir="$1"
  local rel="$2"
  [[ -d "$state_dir" ]] || return 1
  local candidate status
  while IFS= read -r candidate; do
    status="$(yaml_value status "$candidate")"
    if [[ "$status" == "archived" || "$status" == "completed" ]]; then
      continue
    fi
    if override_allows "$candidate" "$rel"; then
      printf '%s' "$candidate"
      return 0
    fi
  done < <(ls -t "$state_dir"/*.md 2>/dev/null || true)
  return 1
}

override_allows() {
  local state_file="$1"
  local rel="$2"
  [[ -f "$state_file" ]] || return 1
  local pattern
  while IFS= read -r pattern; do
    pattern="${pattern%%#*}"
    pattern="${pattern//\"/}"
    pattern="${pattern//\'/}"
    pattern="$(printf '%s' "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    pattern="${pattern#-}"
    pattern="$(printf '%s' "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$pattern" ]] && continue
    case "$rel" in
      $pattern) return 0 ;;
    esac
  done < <(awk '
    /^forbidden_paths_override[[:space:]]*:/ { in_block=1; next }
    in_block && /^[[:space:]]*-/ { print }
    in_block && /^[^[:space:]-]/ { exit }
  ' "$state_file")
  return 1
}

is_archived_state() {
  local cwd="$1"
  local rel="$2"
  case "$rel" in
    docs/.ccb/state/*.md) ;;
    *) return 1 ;;
  esac
  local state_file="$cwd/$rel"
  [[ -f "$state_file" ]] || return 1
  local status current_node
  status="$(yaml_value status "$state_file")"
  current_node="$(yaml_value currentNode "$state_file")"
  [[ "$status" == "archived" || "$status" == "completed" || "$current_node" == "archive" ]]
}

is_forbidden_rel() {
  local cwd="$1"
  local rel="$2"
  case "$rel" in
    references/kernel/capabilities/*|references/kernel/nodes/*|\
    references/kernel/capability-registry-schema.yaml|\
    references/kernel/node-manifest-schema.yaml|\
    references/kernel/state-schema.yaml|\
    references/kernel/guard-registry.md|\
    references/kernel/transition-table.md|\
    references/kernel/primitive-executor-contract.md|\
    references/kernel/hotfixes/*|\
    docs/.ccb/specs/archive/*)
      return 0
      ;;
    docs/.ccb/state/*.md)
      is_archived_state "$cwd" "$rel"
      return $?
      ;;
  esac
  return 1
}

archive_workflow_allows() {
  local cwd="$1"
  local rel="$2"
  local source_rel="${3:-}"
  case "$rel" in
    docs/.ccb/specs/archive/*.md) ;;
    *) return 1 ;;
  esac
  local file_name task_id active_rel state_file review_status current_node node_substate
  file_name="$(basename "$rel")"
  task_id="${file_name%.md}"
  active_rel="docs/.ccb/specs/active/$file_name"
  if [[ -n "$source_rel" && "$source_rel" != "$active_rel" ]]; then
    return 1
  fi
  [[ -f "$cwd/$active_rel" ]] || return 1
  state_file="$cwd/docs/.ccb/state/$task_id.md"
  [[ -f "$state_file" ]] || return 1
  review_status="$(yaml_value review_status "$state_file")"
  current_node="$(yaml_value currentNode "$state_file")"
  node_substate="$(yaml_value nodeSubstate "$state_file")"
  [[ "$review_status" == "passed" || "$current_node" == "archive" || "$node_substate" == "review_passed" ]]
}

block_path() {
  local rel="$1"
  local task_id="$2"
  echo "CCB forbidden path guard blocked mutation: path=$rel task_id=${task_id:-unknown}. Use a scoped slice/spec flow, or declare forbidden_paths_override in the active state with rationale." >&2
  exit 2
}

is_mutating_bash_command() {
  local command_lower
  command_lower="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$command_lower" in
    *">"*|*" rm "*|rm\ *|*" mv "*|mv\ *|*" cp "*|cp\ *|*" touch "*|touch\ *|*" mkdir "*|mkdir\ *|*" rmdir "*|rmdir\ *|*"sed -i"*|*"perl -i"*)
      return 0
      ;;
  esac
  return 1
}

tool_name="$(json_string tool_name)"
case "$tool_name" in
  Write|Edit|MultiEdit|Bash) ;;
  *) exit 0 ;;
esac

cwd="$(normalize_path "$(json_string cwd)")"
if [[ -z "$cwd" ]]; then
  cwd="$(pwd)"
fi
task_id="$(json_string task_id)"
state_file="$(state_file_for_task "$cwd/docs/.ccb/state" "$task_id")"

source_rel=""
if [[ "$tool_name" == "Bash" ]]; then
  command="$(decode_json_text "$(json_string command)")"
  if ! is_mutating_bash_command "$command"; then
    exit 0
  fi
  if [[ "$command" =~ (^|[[:space:]])mv[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:];]+) ]]; then
    source_rel="$(repo_rel_path "$cwd" "${BASH_REMATCH[2]}")"
    printf '%s\n' "${BASH_REMATCH[3]}" > /tmp/ccb-hook-candidates-$$
  else
    printf '%s' "$command" |
      grep -Eo '([A-Za-z]:[\\/][^[:space:]"'\'';]+|docs/\.ccb/specs/archive/[^[:space:]"'\'';]+|docs/\.ccb/state/[^[:space:]"'\'';]+|references/kernel/[^[:space:]"'\'';]+)' > /tmp/ccb-hook-candidates-$$ || true
  fi
else
  target="$(json_string file_path)"
  if [[ -z "$target" ]]; then
    target="$(json_string path)"
  fi
  [[ -z "$target" ]] && exit 0
  printf '%s\n' "$target" > /tmp/ccb-hook-candidates-$$
fi

while IFS= read -r raw_path; do
  [[ -z "$raw_path" ]] && continue
  rel="$(repo_rel_path "$cwd" "$raw_path")"
  if ! is_forbidden_rel "$cwd" "$rel"; then
    continue
  fi
  if [[ -n "$state_file" ]] && override_allows "$state_file" "$rel"; then
    continue
  fi
  if state_file_with_override_for_rel "$cwd/docs/.ccb/state" "$rel" >/dev/null; then
    continue
  fi
  if archive_workflow_allows "$cwd" "$rel" "$source_rel"; then
    continue
  fi
  rm -f /tmp/ccb-hook-candidates-$$
  block_path "$rel" "$task_id"
done < /tmp/ccb-hook-candidates-$$

rm -f /tmp/ccb-hook-candidates-$$
exit 0
