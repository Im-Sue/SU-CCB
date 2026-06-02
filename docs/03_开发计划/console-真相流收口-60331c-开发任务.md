---
task_id: subtask-a9771860331c
title: P1 真相流收口(derive + status)
doc_type: dev_task
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmppm45yt09j35fx6e2
section_id: pr1-truth-flow
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmppm45yt09j35fx6e2.json
source_draft_hash: 2b4787f460f744188fe087b491beaae99f1d9665d4e47935076e05287b597e94
created_at: 2026-05-28T13:00:00.000Z
updated_at: 2026-05-28T14:00:00.000Z
updated_by: ccb_claude
---

# P1 真相流收口(derive + status)

> 一句话:把 Console 还在直接写业务真相的口子全堵上。

## 范围
- derive / derive_followup 改走现有 `POST /requirements/:id/anchor-dispatch` → `/ccb:su-flow`→task_breakdown(payload 带 `source_task_id/source_task_key/followup` provenance);真正 dev_task 由 `task_breakdown → 审查草案 → su-materialize-requirement` 写,**不再 `task.create`/`requirement.create`**。`requirement_id` 从 source task 取(缺失则 409)。
- planning-anchor start / breakdown-draft 翻 `Requirement.status` 改为只写 console-internal 运行态(planningRuntimeState/anchorId),`status` 由 plugin 写 docs/02 后投影。
- md-first 需求创建/编辑固化为唯一被许可的 Console 写文档路径。

## 触及
server:`anchor.routes` / `derive.service` / `tool-invoke.service` / `breakdown-draft.service`

## 验收
- [ ] derive/followup 不再直接写 DB,走 dispatch 队列,plugin 写 docs/03 dev_task
- [ ] 无路由写 plugin-canonical 字段(`schema-ownership-lint` 绿)
- [ ] server 测试绿

## Materialization Context
- Requirement: cmppm45yt09j35fx6e2 ｜ Section: pr1-truth-flow ｜ Owner: ccb_codex ｜ Priority: high ｜ Deps: 无

## 审查结论(2026-05-28 · Claude)
- **接受并提交**(job_45b28f9674fe):derive/derive_followup 改 requirement anchor-dispatch(带 source_task provenance)、status 写收口、删 `createRequirementRecordAsync`(md-first 成唯一写文档路径)。typecheck / 聚焦测试 / schema-ownership-lint 绿,完整 vitest 554 passed。净删 ~214 行。
- **遗留(范围外,需配套)**:plugin `su-flow` 尚未处理 `derive_followup` payload(grep 全空)→ **端到端 followup 暂不通**,另立任务跟进(plugin 侧:su-flow 认 derive_followup → 落成 breakdown draft 新 subtask → materialize)。
