#!/usr/bin/env bash

set -euo pipefail

# CCB v0.3.4 PreToolUse hook: hook_validate_engineering_decidable_evidence
# 规则：U2/U3/U5 只有 5-of-5 证据完整时才能走 engineering-decidable；真实产品意志 U1/U4/U6 才能直接升级用户。

INPUT_JSON_FILE="$(mktemp)"
trap 'rm -f "$INPUT_JSON_FILE"' EXIT
cat > "$INPUT_JSON_FILE"

CCB_HOOK_INPUT_FILE="$INPUT_JSON_FILE" python3 - <<'PY'
# -*- coding: utf-8 -*-
from __future__ import annotations

import json
import os
import re
import sys
from typing import Any

try:
    import yaml
except Exception:  # pragma: no cover - hook 环境缺 PyYAML 时必须 fail closed
    print("缺少 PyYAML，无法校验 engineering-decidable 证据；请先安装依赖。", file=sys.stderr)
    raise SystemExit(2)


input_file = os.environ.get("CCB_HOOK_INPUT_FILE", "")
RAW = open(input_file, "r", encoding="utf-8").read() if input_file else ""
try:
    PAYLOAD = json.loads(RAW or "{}")
except json.JSONDecodeError:
    print("Hook 输入不是合法 JSON，无法校验 engineering-decidable 证据。", file=sys.stderr)
    raise SystemExit(2)

TOOL = PAYLOAD.get("tool_name") or PAYLOAD.get("tool") or ""
if TOOL not in {"Write", "Edit", "MultiEdit", "Bash"}:
    raise SystemExit(0)

ENGINEERING_TOUCHPOINTS = {
    "U2_db_api_rename",
    "U3_task_status_derivation",
    "U5_migration_backfill",
}
REAL_USER_TOUCHPOINT_PREFIXES = ("U1_", "U4_", "U6_")
REVERSIBILITY_CLASSES = {"reversible", "reversible_with_rollback"}
SCOPE_CLASSES = {"task_local", "module_local", "repo_local"}
CANONICAL_CLASSES = {
    "projection_only",
    "api_compat_preserved",
    "existing_kernel_direction",
    "u1_u4_settled",
}
DECIDERS = {"claude", "codex_recommended", "codex-recommended"}


def as_text(value: Any) -> str:
    return value if isinstance(value, str) else ""


def collect_candidate_texts(payload: dict[str, Any]) -> list[str]:
    texts: list[str] = []
    for key in ("content", "new_string", "old_string", "command", "file_path", "path"):
        value = payload.get(key)
        if isinstance(value, str) and value:
            texts.append(value)
    for edit in payload.get("edits") or []:
        if isinstance(edit, dict):
            for key in ("new_string", "old_string", "content"):
                value = edit.get(key)
                if isinstance(value, str) and value:
                    texts.append(value)
    return texts


def is_mutating_bash(command: str) -> bool:
    lower = command.lower()
    mutating_markers = (">", " rm ", "mv ", " mv ", "cp ", " cp ", "sed -i", "perl -i", "python", "node")
    return any(marker in lower for marker in mutating_markers)


def looks_relevant(texts: list[str]) -> bool:
    marker_blob = "\n".join(texts)
    markers = (
        "engineering_decidable_decisions",
        "engineering_decidable_evidence_status",
        "escalation_reason",
        "U2_db_api_rename",
        "U3_task_status_derivation",
        "U5_migration_backfill",
    )
    return any(marker in marker_blob for marker in markers)


def extract_yaml_docs(texts: list[str]) -> list[dict[str, Any]]:
    docs: list[dict[str, Any]] = []
    for text in texts:
        frontmatter_match = re.search(r"(?s)\A\s*---\s*\n(.*?)\n---", text)
        yaml_text = frontmatter_match.group(1) if frontmatter_match else text
        if not any(marker in yaml_text for marker in ("engineering_decidable", "escalation_reason", "U2_", "U3_", "U5_")):
            continue
        try:
            parsed = yaml.safe_load(yaml_text) or {}
        except yaml.YAMLError:
            # Bash 命令文本经常不是 YAML；只有明显要写证据块时才拒绝。
            if "engineering_decidable_decisions" in yaml_text:
                print("engineering-decidable 证据块不是合法 YAML。", file=sys.stderr)
                raise SystemExit(2)
            continue
        if isinstance(parsed, dict):
            docs.append(parsed)
    return docs


def present(value: Any) -> bool:
    return value not in (None, "")


def non_empty_list(value: Any) -> bool:
    return isinstance(value, list) and len(value) > 0


def decision_errors(decision: dict[str, Any], index: int) -> list[str]:
    prefix = f"engineering_decidable_decisions[{index}]"
    errors: list[str] = []
    required = [
        "id",
        "decision_ref",
        "touchpoint",
        "summary",
        "evidence_list",
        "reversibility_class",
        "scope",
        "tests_ref",
        "canonical_consistency",
        "decided_by",
        "created_at",
    ]
    missing = [name for name in required if not present(decision.get(name))]
    if missing:
        errors.append(f"{prefix} 缺少必需字段: {', '.join(missing)}")

    touchpoint = decision.get("touchpoint")
    if touchpoint not in ENGINEERING_TOUCHPOINTS:
        errors.append(f"{prefix}.touchpoint 必须是 U2/U3/U5")

    if not non_empty_list(decision.get("evidence_list")) or len(decision.get("evidence_list") or []) < 2:
        errors.append(f"{prefix}.evidence_list 至少需要 2 条证据")

    reversibility = decision.get("reversibility_class")
    if reversibility not in REVERSIBILITY_CLASSES:
        errors.append(f"{prefix}.reversibility_class 必须是 reversible/reversible_with_rollback")

    scope = decision.get("scope")
    if not isinstance(scope, dict):
        errors.append(f"{prefix}.scope 必须是对象")
    else:
        if scope.get("class") not in SCOPE_CLASSES:
            errors.append(f"{prefix}.scope.class 非法")
        if not non_empty_list(scope.get("paths")):
            errors.append(f"{prefix}.scope.paths 必须非空")
        if scope.get("external_contract_impact") is not False:
            errors.append(f"{prefix}.scope.external_contract_impact 必须为 false")

    if not non_empty_list(decision.get("tests_ref")):
        errors.append(f"{prefix}.tests_ref 必须非空")

    consistency = decision.get("canonical_consistency")
    if not isinstance(consistency, dict):
        errors.append(f"{prefix}.canonical_consistency 必须是对象")
    else:
        if consistency.get("class") not in CANONICAL_CLASSES:
            errors.append(f"{prefix}.canonical_consistency.class 非法")
        if consistency.get("changes_kernel_semantics") is not False:
            errors.append(f"{prefix}.canonical_consistency.changes_kernel_semantics 必须为 false；否则走 U1/U4 升级")
        if touchpoint == "U3_task_status_derivation" and consistency.get("class") != "u1_u4_settled":
            errors.append(f"{prefix} 的 U3 projection-only 路径必须声明 U1/U4 已 settled")
        if touchpoint == "U3_task_status_derivation" and len(consistency.get("required_decision_refs") or []) < 2:
            errors.append(f"{prefix} 的 U3 projection-only 路径必须引用 U1/U4 决策 ref")

    if (touchpoint == "U5_migration_backfill" or reversibility == "reversible_with_rollback") and not present(
        decision.get("rollback_ref")
    ):
        errors.append(f"{prefix}.rollback_ref 必须存在")

    if decision.get("decided_by") not in DECIDERS:
        errors.append(f"{prefix}.decided_by 必须是 claude/codex_recommended")
    return errors


def validate_doc(doc: dict[str, Any]) -> list[str]:
    errors: list[str] = []

    reason = as_text(doc.get("escalation_reason"))
    if reason:
        if reason.startswith(REAL_USER_TOUCHPOINT_PREFIXES):
            return errors
        if reason in ENGINEERING_TOUCHPOINTS and doc.get("engineering_decidable_evidence_status") == "passed":
            errors.append(f"{reason} 证据已通过，禁止升级用户；请追加 engineering_decidable_decisions 并记录决策 provenance")
        return errors

    decisions = doc.get("engineering_decidable_decisions")
    if decisions is None:
        if doc.get("touchpoint") in ENGINEERING_TOUCHPOINTS:
            return ["触及 U2/U3/U5 engineering-decidable touchpoint，但缺少 engineering_decidable_decisions evidence ledger"]
        return errors
    if not isinstance(decisions, list):
        return ["engineering_decidable_decisions 必须是数组"]
    for index, decision in enumerate(decisions):
        if not isinstance(decision, dict):
            errors.append(f"engineering_decidable_decisions[{index}] 必须是对象")
            continue
        errors.extend(decision_errors(decision, index))
    return errors


texts = collect_candidate_texts(PAYLOAD)
if TOOL == "Bash" and not is_mutating_bash(as_text(PAYLOAD.get("command"))):
    raise SystemExit(0)
if not looks_relevant(texts):
    raise SystemExit(0)

docs = extract_yaml_docs(texts)
all_errors: list[str] = []
for doc in docs:
    all_errors.extend(validate_doc(doc))

if all_errors:
    print("engineering-decidable 证据校验失败：", file=sys.stderr)
    for error in all_errors[:8]:
        print(f"- {error}", file=sys.stderr)
    print("请补齐 evidence / reversibility / scoped / tested / canonical_consistency 5-of-5，或仅在 U1/U4/U6 真实用户权威场景升级。", file=sys.stderr)
    raise SystemExit(2)

raise SystemExit(0)
PY
