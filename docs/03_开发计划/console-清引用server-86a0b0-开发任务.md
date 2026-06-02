---
task_id: subtask-70d16386a0b0
title: P3a 清 legacy 活引用·server
doc_type: dev_task
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmppm45yt09j35fx6e2
section_id: pr4-clear-refs-server
order: 4
implementation_owner: ccb_codex
dependencies: [subtask-a9771860331c]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmppm45yt09j35fx6e2.json
source_draft_hash: 2b4787f460f744188fe087b491beaae99f1d9665d4e47935076e05287b597e94
created_at: 2026-05-28T13:00:00.000Z
updated_at: 2026-05-29T10:00:00.000Z
updated_by: ccb_claude
---

# P3a 清 legacy 活引用·server

> 一句话:把服务端对旧 kind/路径/列的活引用清掉,为 P3b 删列铺路。

## 范围
- 删 `inferDocumentKind` 的 `.ccb/{plans,tasks,decisions}` 分支、`deriveTasks` 的 plan/task 分组(只留 dev_task)。
- 改 task detail 的 `linkedDocuments` 查询方式(不再依赖 `linked*` 列)。
- 拆除 epic 兼容壳(server 固定返回 `parentEpicId:null` 等)。

## 触及
server:`document-parser` / `project-indexer` / `task.routes`

## 验收
- [ ] 无 `.ccb/{plans,tasks,decisions}` kind 分支、无 plan/task 老 kind 分组
- [ ] task detail linkedDocuments 不依赖 linked* 列仍正确
- [ ] server 测试绿

## Materialization Context
- Requirement: cmppm45yt09j35fx6e2 ｜ Section: pr4-clear-refs-server ｜ Owner: ccb_codex ｜ Priority: medium ｜ Deps: pr1-truth-flow

## 审查结论(2026-05-29 · Claude)
- **接受**(job_22bd1d4d82e4):删 `.ccb/{plans,tasks,decisions}` legacy kind 推断;`deriveTasks` 只投影 `dev_task`、不再写 `linked*`;task detail `linkedDocuments` 改按 `taskKey + kind=dev_task` 查;移除 `linked*`/epic null 兼容;`/api/requirements/:id/epics` → 410。独立 grep 核验 server 实现侧无 `linked*`/epic/legacy kind 残留(仅余 schema invariant 测试)。typecheck / schema-ownership-lint 绿,vitest 558 passed。
- 解锁 pr6(删列 migration)的 server 半边;待 pr5(web)清完引用后即可上 pr6。
