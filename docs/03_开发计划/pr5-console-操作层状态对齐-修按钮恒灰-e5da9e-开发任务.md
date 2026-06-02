---
doc_type: dev_task
task_id: subtask-64c997e5da9e
title: PR5:Console 操作层状态对齐(修按钮恒灰)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpqlbcw1e06bb166ae00d341
section_id: pr5-console-status-align
order: 5
implementation_owner: ccb_codex
dependencies: [subtask-89f904166004, subtask-32356f57c581]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpqlbcw1e06bb166ae00d341.json
source_draft_hash: 32e6a56cb823328e84ea9f34bfe908d10c9a5bd77910b4943f2f9fb857c69576
created_at: 2026-05-29T09:38:09.240Z
updated_at: 2026-05-29T13:00:10.764Z
updated_by: ccb_claude
---

# PR5:Console 操作层状态对齐(修按钮恒灰)

## 目标
Console 操作层对齐新状态模型,修「批量推进」按钮恒灰:indexer/Prisma/资格门/UI consumer 全部对齐 `{reviewing,done,cancelled}`,资格门 fail-closed。从已合 PR3+PR2a 基线开工。

## 范围
- `[MODIFY] project-indexer.ts` `normalizeTaskStatus`(~`:1785`):只出 `{reviewing,done,cancelled}`;删 `active` fallback;旧值(planning/dispatch_ready/dispatched/implementing/active)**read-compat 归一 `reviewing`**(留一版),停止写旧值;空缺省 `reviewing`。
- `[MODIFY] prisma/schema.prisma:123`:`Task.status` 默认 `active`→`reviewing`(+ migration)。
- `[MODIFY] anchor-broker/anchor.routes.ts:636`:资格门 fail-closed `currentNode==="dispatch" && status==="reviewing" && !hasActiveAnchor && !isPendingDispatch`;抽**共享 helper**,batch(`:636`)+ 单派工(`:421` 现无门)复用。
- `[MODIFY] UI consumer`:`node-board-config.ts:83`、`ui-mapping.ts:117,233`、`start-ai-session.routes.ts:48`、`RequirementDetailPage.tsx:245,1176`、`TaskDetailPage.tsx:421`、`MyWorkPage.tsx:116`;`AlertStrip.tsx:38` blocked 改走 runtime/blockedReason、不再依赖 `status`。

## 验收
- `deriveTasks`:无 status 默认 reviewing;旧 planning/dispatch_ready/dispatched/active 归一 reviewing;done/cancelled 保持。
- Prisma 默认 reviewing(migration 生效)。
- batch + 单派工共用 helper:`dispatch 节点 + reviewing` 才 eligible;done/cancelled/非 dispatch fail-closed。**物化子任务后「批量推进」按钮变亮**(原 bug 修复验证)。
- UI:board lane、status badge、MyWork、AlertStrip blocked 正确。
- **回归 rescan:26 task `done=19/reviewing=7`、节点 `archive=19/dispatch=7` 不变**。
- 双侧 typecheck + vitest 全绿。

## 边界
- 不可误改同名 `active`:Sprint / capability registry / terminal viewport / anchor allocation / TaskRun `dispatched` / ReviewIntent `cancelled`(非 Task.status 域)。
- **单派工加门是行为收紧**:开工前先验证「非 dispatch 节点单独派工」是否现用法,是则 helper 留旁路。

## 依赖
pr3-kernel-status-upgrade(新模型为准)+ pr2a-req-scoped-reindex(`project-indexer.ts` helper 先落,避免冲突)。

## Materialization Context

- Requirement: cmpqlbcw1e06bb166ae00d341
- Section: pr5-console-status-align
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-89f904166004, subtask-32356f57c581
