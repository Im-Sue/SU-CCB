---
doc_type: dev_task
task_id: subtask-89f904166004
title: PR4:主仓 kernel 状态模型升级 + 同步插件副本(敏感)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpqlbcw1e06bb166ae00d341
section_id: pr4-kernel-status-upgrade
order: 4
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpqlbcw1e06bb166ae00d341.json
source_draft_hash: 32e6a56cb823328e84ea9f34bfe908d10c9a5bd77910b4943f2f9fb857c69576
created_at: 2026-05-29T09:38:09.240Z
updated_at: 2026-05-29T13:00:10.764Z
updated_by: ccb_claude
---

# PR4:主仓 kernel 状态模型升级 + 同步插件副本(敏感)

## 目标
主仓 `references/kernel` 状态模型升级为单一真相源(ADR-0038):`status={reviewing,done,cancelled}` + `current_node` 管位置 + 异常态归 `runtime_state`;再单向同步插件副本。敏感 PR,单片不再细拆。

## 范围
- `[MODIFY] references/kernel/state-schema.yaml:23`:`task_status` 收敛 3 值;默认 `proposed`→`reviewing`;`:390/:699` 引用同步;`replanning`→node_substate、`waiting_for_user_arbitration`→`runtime_state=waiting_user/escalated` + `active_waiting_set[].waiting_for=user_arbitration`(`:716` 附近)。
- `[MODIFY] 7 个 node manifest` 的 `task_status_in`:废弃该字段,或统一 `[reviewing]`(入口由 `previous_nodes_any_of`/`current_node`/guard 判定;archive 入口亦 `reviewing`,归档完成才写 done)。
- `[MODIFY] transition-table.md / guard-registry.md / primitive-executor-contract.md`:旧 status 副作用/guard(如 `dispatch_ready` guard-registry:66,153、`waiting_for_user_arbitration` :171、transition status effects :148,:404)。
- **升 kernel schema 版本号**;再机械同步插件副本 `su-ccb-claude-plugin/references/kernel`(恢复 正本→副本单向)。
- `[MODIFY] ADR-0038` status `proposed`→`accepted`(已用户授权)。

## 验收
- `references/kernel/tools/lint_state.py` 全跑通过;U3 治理(`changes_kernel_semantics`)按 ADR-0038 + 用户授权满足。
- grep 断言 active kernel 旧 `task_status` 值只剩 deprecated/兼容说明。
- 7 manifest 与 `state-schema.yaml` 自洽;插件副本与主仓差异可解释(仅分发快照)。
- 不触碰 Console 运行时(运行时不读这些 YAML gating,`task-node-flow.service.ts:42`)——本片为协议/契约/lint 层。

## 边界
- 只改 kernel 协议真相源 + 副本同步 + ADR;**不改 Console 代码**(留 PR4)。
- read-compat 归一逻辑在 PR4 的 Console 层,不在 kernel。

## 依赖
无(独立开发);但**必须先于 PR4 合入**,不允许 PR4 插队(否则中间态不自洽)。

## Materialization Context

- Requirement: cmpqlbcw1e06bb166ae00d341
- Section: pr4-kernel-status-upgrade
- Owner: ccb_codex
- Priority: high
- Dependencies: none
