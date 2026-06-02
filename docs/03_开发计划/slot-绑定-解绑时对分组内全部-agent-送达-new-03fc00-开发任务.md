---
task_id: subtask-af2d2703fc00
title: slot 绑定/解绑时对分组内全部 agent 送达 /new
doc_type: dev_task
status: reviewing
current_node: dispatch
node_substate: awaiting_codex_pickup
priority: medium
requirement_id: cmpl40j1ve2d3820066c75fdb
section_id: pr1-slot-context-reset-new
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpl40j1ve2d3820066c75fdb.json
source_draft_hash: 331d539d7732def7a1b14e0f93da7616b71d809259a1a020e54e6c8a9f4152c0
created_at: 2026-05-26T14:38:44.445Z
---


# slot 绑定/解绑时对分组内全部 agent 送达 /new

## 目标
绑定成功后 / 解绑前,对该 slot 分组下所有 agent(claude+codex)送达 /new,新建会话隔离上下文。
## 范围
- ccbd-client 封装 project_view;新增 slot-context-reset.service.ts 枚举 agent + tmux send-keys 送达。
- slot-binding.service onSlotBound 回调(提交后触发、不回滚);slot.routes release 前 best-effort 触发(不阻断)。
## 验收
- 按拓扑枚举全部 agent(非 1:1);bind 后/release 前对多 agent 都触发送达;送达失败不阻断主流程。
- 实测某 slot 的 claude+codex 都收到 /new。
## 依赖
无(原子任务)。

## Materialization Context

- Requirement: cmpl40j1ve2d3820066c75fdb
- Section: pr1-slot-context-reset-new
- Owner: ccb_codex
- Priority: medium
- Dependencies: none
