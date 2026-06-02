#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK_DIR="$ROOT/.claude/hooks"
FIXTURE_DIR="$HOOK_DIR/fixtures"

run_expect() {
  local label="$1"
  local expected="$2"
  local hook="$3"
  local fixture="$4"
  local output status project_root_for_sed

  set +e
  project_root_for_sed="${ROOT//\\/\\\\}"
  project_root_for_sed="${project_root_for_sed//&/\\&}"
  output="$(sed "s|<PROJECT_ROOT>|$project_root_for_sed|g" "$fixture" | bash "$hook" 2>&1)"
  status=$?
  set -e

  if [[ "$expected" == "pass" && "$status" -eq 0 ]]; then
    echo "PASS $label exit=$status"
  elif [[ "$expected" == "fail" && "$status" -ne 0 ]]; then
    echo "PASS $label exit=$status"
    printf '%s\n' "$output" | head -n 2
  else
    echo "FAIL $label expected=$expected exit=$status"
    printf '%s\n' "$output"
    exit 1
  fi
}

run_archive_selftest() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/docs/.ccb/specs/active" "$tmp/docs/.ccb/specs/archive" "$tmp/docs/.ccb/state"
  printf '%s\n' 'fixture' > "$tmp/docs/.ccb/specs/active/archive-fixture.md"
  cat > "$tmp/docs/.ccb/state/archive-fixture.md" <<'EOF'
---
task_id: archive-fixture
currentNode: archive
status: reviewing
review_status: passed
---
EOF

  local payload="$tmp/archive-payload.json"
  cat > "$payload" <<EOF
{"tool_name":"Bash","cwd":"$tmp","task_id":"archive-fixture","command":"mv docs/.ccb/specs/active/archive-fixture.md docs/.ccb/specs/archive/archive-fixture.md"}
EOF

  bash "$HOOK_DIR/preusetool-block-mutation-forbidden-paths.sh" < "$payload"
  mv "$tmp/docs/.ccb/specs/active/archive-fixture.md" "$tmp/docs/.ccb/specs/archive/archive-fixture.md"
  test -f "$tmp/docs/.ccb/specs/archive/archive-fixture.md"
  echo "PASS archive-active-to-archive exit=0"
  rm -rf "$tmp"
}

run_interactive_ask_selftest() {
  local tmp payload
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/docs/.ccb/state"
  cat > "$tmp/docs/.ccb/state/interactive.md" <<'EOF'
---
task_id: interactive
policy_profile: interactive-single
user_approval_mode: required
currentNode: dispatch
status: dispatched
---
EOF
  payload="$tmp/interactive-ask.json"
  cat > "$payload" <<EOF
{"tool_name":"AskUserQuestion","cwd":"$tmp","task_id":"interactive","question_body":"请选择哪个 implementation design?"}
EOF
  bash "$HOOK_DIR/preusetool-block-askuser.sh" < "$payload"
  echo "PASS ask-user-interactive exit=0"
  rm -rf "$tmp"
}

run_autonomous_ask_selftest() {
  local tmp fail_payload pass_payload output status
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/docs/.ccb/state"
  cat > "$tmp/docs/.ccb/state/autonomous-ask.md" <<'EOF'
---
task_id: autonomous-ask
policy_profile: autonomous-batch
user_approval_mode: none
currentNode: technical_design
status: planning
---
EOF

  fail_payload="$tmp/autonomous-ask-fail.json"
  cat > "$fail_payload" <<EOF
{"tool_name":"AskUserQuestion","cwd":"$tmp","task_id":"autonomous-ask","question_body":"选哪个 implementation design?"}
EOF
  set +e
  output="$(bash "$HOOK_DIR/preusetool-block-askuser.sh" < "$fail_payload" 2>&1)"
  status=$?
  set -e
  if [[ "$status" -ne 0 ]]; then
    echo "PASS ask-user-missing-de exit=$status"
    printf '%s\n' "$output" | head -n 1
  else
    echo "FAIL ask-user-missing-de expected fail exit=0"
    rm -rf "$tmp"
    exit 1
  fi

  pass_payload="$tmp/autonomous-ask-pass.json"
  cat > "$pass_payload" <<EOF
{"tool_name":"AskUserQuestion","cwd":"$tmp","task_id":"autonomous-ask","question_body":"Decision: U1. Risk: high. Reversibility: reversible. Evidence: consult R2. Precedent: guard policy. Verdict: user must decide which design."}
EOF
  bash "$HOOK_DIR/preusetool-block-askuser.sh" < "$pass_payload"
  echo "PASS ask-user-with-de exit=0"
  rm -rf "$tmp"
}

run_existing_archive_guard_selftest() {
  local tmp payload output status
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/docs/.ccb/state"
  cat > "$tmp/docs/.ccb/state/archive-guard.md" <<'EOF'
---
task_id: archive-guard
currentNode: review
status: reviewing
review_status: needs_followup
---
EOF
  payload="$tmp/archive-guard.json"
  cat > "$payload" <<'EOF'
{"tool_name":"Write","file_path":"docs/.ccb/state/archive-guard.md","content":"---\ntask_id: archive-guard\nstatus: archived\n---"}
EOF
  set +e
  output="$(bash "$HOOK_DIR/preusetool-block-archive-writes.sh" < "$payload" 2>&1)"
  status=$?
  set -e
  if [[ "$status" -ne 0 ]]; then
    echo "PASS existing-archive-guard exit=$status"
    printf '%s\n' "$output" | head -n 1
  else
    echo "FAIL existing-archive-guard expected fail exit=0"
    rm -rf "$tmp"
    exit 1
  fi
  rm -rf "$tmp"
}

run_autonomous_ask_selftest
run_interactive_ask_selftest
run_expect "mutation-active-spec" pass "$HOOK_DIR/preusetool-block-mutation-forbidden-paths.sh" "$FIXTURE_DIR/mutation_pass_active_spec.json"
run_expect "mutation-archived-spec" fail "$HOOK_DIR/preusetool-block-mutation-forbidden-paths.sh" "$FIXTURE_DIR/mutation_fail_archived_spec.json"
run_expect "engineering-u2-pass" pass "$HOOK_DIR/preusetool-validate-engineering-decidable-evidence.sh" "$FIXTURE_DIR/engineering_decidable_u2_pass.json"
run_expect "engineering-u2-missing-reversibility" fail "$HOOK_DIR/preusetool-validate-engineering-decidable-evidence.sh" "$FIXTURE_DIR/engineering_decidable_u2_missing_reversibility_fail.json"
run_expect "engineering-u3-kernel-semantics" fail "$HOOK_DIR/preusetool-validate-engineering-decidable-evidence.sh" "$FIXTURE_DIR/engineering_decidable_u3_kernel_semantics_fail.json"
run_expect "engineering-u3-projection" pass "$HOOK_DIR/preusetool-validate-engineering-decidable-evidence.sh" "$FIXTURE_DIR/engineering_decidable_u3_projection_pass.json"
run_expect "engineering-u5-missing-rollback" fail "$HOOK_DIR/preusetool-validate-engineering-decidable-evidence.sh" "$FIXTURE_DIR/engineering_decidable_u5_missing_rollback_fail.json"
run_expect "engineering-u1-escalation" pass "$HOOK_DIR/preusetool-validate-engineering-decidable-evidence.sh" "$FIXTURE_DIR/engineering_decidable_u1_escalation_pass.json"
run_expect "engineering-u2-failed-evidence-escalation" pass "$HOOK_DIR/preusetool-validate-engineering-decidable-evidence.sh" "$FIXTURE_DIR/engineering_decidable_u2_failed_evidence_escalation_pass.json"
run_expect "engineering-u2-valid-evidence-escalation" fail "$HOOK_DIR/preusetool-validate-engineering-decidable-evidence.sh" "$FIXTURE_DIR/engineering_decidable_u2_valid_evidence_escalation_fail.json"
run_archive_selftest
run_existing_archive_guard_selftest
