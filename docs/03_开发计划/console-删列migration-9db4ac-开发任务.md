---
task_id: subtask-876cf79db4ac
title: P3b Prisma migration 删列
doc_type: dev_task
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmppm45yt09j35fx6e2
section_id: pr6-drop-columns
order: 6
implementation_owner: ccb_codex
dependencies: [subtask-70d16386a0b0, subtask-8a83b2432463]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmppm45yt09j35fx6e2.json
source_draft_hash: 2b4787f460f744188fe087b491beaae99f1d9665d4e47935076e05287b597e94
created_at: 2026-05-28T13:00:00.000Z
updated_at: 2026-05-29T18:00:00.000Z
updated_by: ccb_claude
---

# P3b Prisma migration 删列

> 一句话:P3a 把活引用清完后,真正从 schema 删掉死列。

## 范围
- 删 `Task.linked{Spec,Plan,Task}Id`、`Requirement.outputMode`/`splitMode`/`sourceTaskId`。
- epic 四件套已非 DB 列(P3a 拆壳),无需 migration。
- 重生成 Prisma client。

## 触及
`apps/ccb-console/server/prisma/schema.prisma` + migration

## 验收
- [x] migration 生成且可应用(空库 migrate deploy 44 个全过;migrate diff empty)
- [x] 重生成 client、全量 server 测试绿(552)、schema-ownership-lint 0 fail
- [x] 无残留对已删列的引用(typecheck 绿)

## Materialization Context
- Requirement: cmppm45yt09j35fx6e2 ｜ Section: pr6-drop-columns ｜ Owner: ccb_codex ｜ Priority: medium ｜ Deps: pr4-clear-refs-server, pr5-clear-refs-web

## 审查结论(2026-05-29 · Claude)
- **接受**(job_239d66494049,rep_664153302d6c)。codex 实现:Prisma 删 `Task.linkedSpecId/linkedPlanId/linkedTaskDocId` + `Requirement.outputMode/splitMode/sourceTaskId`(及 `RequirementSourceTask` relation/index);migration `20260529090000_p3b_drop_legacy_projection_columns`(SQLite table-redefine);`createRequirement` 忽略已删 payload 字段、不入库;**requirement 投影仍输出常量** `outputMode:"requirement_only"`/`splitMode:"direct_pr"`/`sourceTaskId:null` —— web RequirementView 契约不破(正是派工要求)。
- **Claude 补收口**:删列后 `references/schema-ownership-matrix.yaml` 仍列这 6 个字段(lint 报 `matrix fields missing from schema`)→ 同步删 matrix 6 条 stale 条目(所有权契约随 schema 收口)。
- **独立验证**:server `tsc --noEmit` 绿;`vitest` 93 文件 / 552 测试绿;`schema-ownership-lint` 0 failure、`matrix fields missing from schema: none`(仅余 6 个既有 SlotBinding warning);migration 空库可应用、diff empty。
