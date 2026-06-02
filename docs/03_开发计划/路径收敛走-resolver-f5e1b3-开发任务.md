---
task_id: subtask-85a973f5e1b3
title: 路径收敛走 resolver
doc_type: dev_task
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpmv55uy7d2673077860d06a
section_id: pr5-path-resolver-converge
order: 5
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpmv55uy7d2673077860d06a.json
source_draft_hash: 01dfecb840056c326d6941e7eeff491092f48e444bb712c9c079fab6163441af
created_at: 2026-05-27T12:57:49.805Z
updated_at: 2026-05-28T14:16:42.343Z
updated_by: ccb_claude
---

# 路径收敛走 resolver

## C1 路径收敛
- 把 plugin lib + Console 硬编码的 docs/.ccb 路径收敛到 resolver(pr1)
- 替换:requirement-analysis/subtask/reconcile/slot-health/evidence-registry/project-indexer 等
- 产出:统一路径入口 + 回归测试

## Materialization Context

- Requirement: cmpmv55uy7d2673077860d06a
- Section: pr5-path-resolver-converge
- Owner: ccb_codex
- Priority: high
- Dependencies: none

## Archive Note

- Archive note: pr5 path-converge was achieved via pr6/pr7 plus subsequent resolver/path migration work; no separate implementation commit was needed.
