#!/usr/bin/env bash

set -euo pipefail

# CCB v0.3.3 PreToolUse hook: hook_block_askuser_in_autonomous
# 规则：autonomous ask_user_decision 必须携带 DE Guard 6 字段浅证据。

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

yaml_value() {
  local key="$1"
  local file="$2"
  awk -F: -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value=$2
      sub(/#.*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^["'"'"']|["'"'"']$/, "", value)
      print value
      exit
    }
  ' "$file"
}

contains_any() {
  local haystack="$1"
  shift
  local pattern
  for pattern in "$@"; do
    case "$haystack" in
      *"$pattern"*) return 0 ;;
    esac
  done
  return 1
}

state_file_for_task() {
  local state_dir="$1"
  local task_id="$2"
  if [[ -n "$task_id" && -f "$state_dir/$task_id.md" ]]; then
    printf '%s' "$state_dir/$task_id.md"
    return 0
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

is_autonomous_mode() {
  local cwd="$1"
  local task_id="$2"
  local state_dir="$cwd/docs/.ccb/state"
  local latest_batch policy_profile user_approval_mode state_file

  latest_batch="$(ls -t "$state_dir"/batch-*.yaml 2>/dev/null | head -n 1 || true)"
  if [[ -n "$latest_batch" ]]; then
    policy_profile="$(yaml_value policy_profile "$latest_batch")"
    user_approval_mode="$(yaml_value user_approval_mode "$latest_batch")"
    if [[ "$policy_profile" == "autonomous-batch" && "$user_approval_mode" == "none" ]]; then
      return 0
    fi
  fi

  state_file="$(state_file_for_task "$state_dir" "$task_id")"
  if [[ -n "$state_file" ]]; then
    policy_profile="$(yaml_value policy_profile "$state_file")"
    user_approval_mode="$(yaml_value user_approval_mode "$state_file")"
    if [[ "$policy_profile" == autonomous* || "$user_approval_mode" == "downgraded" || "$user_approval_mode" == "none" ]]; then
      return 0
    fi
  fi
  return 1
}

has_de_evidence() {
  local text="$1"
  local lower
  lower="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')"

  contains_any "$lower" "decision" "decision_class" "决策" || return 1
  contains_any "$lower" "risk" "risk_level" "风险" || return 1
  contains_any "$lower" "reversibility" "reversible" "可逆" || return 1
  contains_any "$lower" "evidence" "available_evidence" "证据" || return 1
  contains_any "$lower" "precedent" "why_user_decision" "required" "先例" "前例" "原因" || return 1
  contains_any "$lower" "verdict" "default_decision" "结论" "裁定" || return 1
  return 0
}

tool_name="$(json_string tool_name)"
if [[ "$tool_name" != "AskUserQuestion" ]]; then
  exit 0
fi

cwd="$(normalize_path "$(json_string cwd)")"
if [[ -z "$cwd" ]]; then
  cwd="$(pwd)"
fi
task_id="$(json_string task_id)"

if ! is_autonomous_mode "$cwd" "$task_id"; then
  exit 0
fi

question_body="$(json_string question_body)"
if [[ -z "$question_body" ]]; then
  question_body="$(json_string question)"
fi
if [[ -z "$question_body" ]]; then
  question_body="$(json_string prompt)"
fi
if [[ -z "$question_body" ]]; then
  question_body="$(json_string content)"
fi
question_body="$(decode_json_text "$question_body")"
question_lower="$(printf '%s' "$question_body" | tr '[:upper:]' '[:lower:]')"

stage_1_verbs=(
  "选哪个" "怎么选" "你来定" "请决定" "是否改" "要不要改" "保留还是替换" "采用哪种"
  "which to choose" "please decide" "choose between" "whether to change" "keep or replace"
  "which design" "which implementation" "override"
)
stage_2_objects=(
  "方案" "实现" "接口" "契约" "数据结构" "表结构" "状态流" "事务流" "依赖" "迁移" "架构"
  "design" "implementation" "interface" "contract" "schema" "state flow" "transaction flow"
  "dependency" "migration"
)
negative_allowlist=(
  "file" "path" "directory" "environment" "test" "summary" "log"
  "文件" "路径" "目录" "环境" "测试" "摘要" "日志"
)

if contains_any "$question_lower" "${negative_allowlist[@]}"; then
  exit 0
fi

if contains_any "$question_lower" "${stage_1_verbs[@]}" && contains_any "$question_lower" "${stage_2_objects[@]}"; then
  if has_de_evidence "$question_body"; then
    exit 0
  fi
  echo "当前 autonomous 模式禁止无 DE Guard 证据的 ask_user_decision。请补齐 Decision/Risk/Reversibility/Evidence/Precedent/Verdict 六字段，或改 consult_codex / escalate_to_human。" >&2
  exit 2
fi

exit 0

