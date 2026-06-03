---
doc_type: module_spec
title: "SU-Oriel 任务看板模块规格"
status: active
updated: 2026-06-03
---

# SU-Oriel 任务看板模块规格

## 1. 模块目标

任务看板模块把项目文档和事件投影成可浏览、可筛选、可追踪的任务工作台。它展示任务所处节点、评审意图、咨询记录、关联文档、工作区和时间线，并提供少量受控触发入口；任务推进真相仍来自 plugin 生命周期与项目文档。

真实实现锚点：

- `su-oriel/server/src/modules/task/task.routes.ts`
- `su-oriel/server/src/modules/task/phase-derive.ts`
- `su-oriel/server/src/modules/task/progress-aggregation.ts`
- `su-oriel/server/src/modules/task/derive.routes.ts`
- `su-oriel/server/src/modules/tasks/task-node-flow.routes.ts`
- `su-oriel/server/src/modules/tasks/task-consultation.routes.ts`
- `su-oriel/server/src/modules/tasks/pending-interactions.routes.ts`
- `su-oriel/server/src/modules/tasks/consult-records.routes.ts`
- `su-oriel/server/src/modules/task-event-view/task-event-view.routes.ts`
- `su-oriel/server/src/modules/sprint/sprint.routes.ts`
- `su-oriel/web/src/pages/tasks/TasksPage.tsx`
- `su-oriel/web/src/pages/tasks/TasksBoardView.tsx`
- `su-oriel/web/src/pages/tasks/TaskDetailFullPage.tsx`
- `su-oriel/web/src/components/task-detail-v2/`
- `su-oriel/web/src/lib/node-board-config.ts`

## 2. 功能范围

| 能力 | 当前实现 |
|---|---|
| 任务列表 | `GET /api/projects/:projectId/tasks` 返回项目任务投影，包含 node 字段、进度、优先级、需求关联和语义类型。 |
| 任务详情 | `GET /api/tasks/:taskId` 返回关联需求、关联文档、工作区、review projection、review intents 等详情。 |
| 任务时间线 | `GET /api/tasks/:taskId/timeline` 合并 dev_task frontmatter、工作区事件、review intent 与 event journal。 |
| 节点流 | `GET /api/tasks/:taskId/node-flow` 返回 current node、substate、runtime state、transition 和可操作动作。 |
| 协商记录 | `GET /api/tasks/:taskId/consultation`、`/consult-records`、`/pending-interactions` 展示多 agent 协商与待处理交互。 |
| 评审意图 | `GET/POST /api/tasks/:taskId/review-intents`，`POST /api/review-intents/:intentId/consume`，`DELETE /api/review-intents/:intentId`。 |
| 衍生任务 | `POST /api/tasks/:taskId/derive` 创建后续任务草案/派生结果。 |
| 需求聚合 | `GET /api/requirements/:requirementId/aggregation` 与项目聚合接口展示需求下任务进度。 |
| Sprint | `GET/POST /api/projects/:projectId/sprints`、sprint 详情、任务分配、燃尽数据。 |
| 元数据更新 | `PATCH /api/tasks/:taskId` 当前只允许更新 `priority`。 |

## 3. 页面组件

| 页面/组件 | 当前职责 |
|---|---|
| `TasksPage` | 根据 URL 判断展示任务看板或全屏任务详情。 |
| `TasksBoardView` | 支持看板/列表切换、筛选、隐藏归档、未启动需求提示和健康面板。 |
| `node-board-config.ts` | 将任务投影到 `dispatch`、`implementation`、`review`、`archive` 四类看板列。 |
| `TaskDetailFullPage` | 全屏任务详情容器，提供返回看板、需求面包屑和 sync 状态。 |
| `task-detail-v2` 组件组 | 节点状态、动作、咨询流、决策时间线、checkpoint、文档预览、工作区和侧栏信息。 |
| `HealthPanel` / `UnstartedRequirementStrip` / `TasksFilterBar` | 看板辅助视图与筛选入口。 |

## 4. 数据模型

| 模型 | 字段/关系 | 说明 |
|---|---|---|
| `Task` | `taskKey`、`title`、`status`、`currentNode`、`nodeSubstate`、`runtimeState`、`lastTransitionId`、`progress`、`blockedReason`、`reviewStatus`、`requirementId` | 任务投影；核心状态字段由 dev_task 文档同步。 |
| `Document` | `taskKey`、`kind`、`frontmatterJson` | 任务关联文档来源。 |
| `ReviewIntent` | `intentType`、`payloadJson`、`status`、`attemptCount` | 人工评审意图与消费状态。 |
| `TaskWorkspace` | `workspacePath`、`branchName`、`status` | 任务工作区投影。 |
| `TaskCheckpoint` | `transitionId`、`nodeBefore`、`nodeAfter`、`stateHash` | 节点流转审计快照。 |
| `Sprint` | `name`、`status`、`capacity`、`tasks` | 迭代组织和燃尽投影。 |

## 5. 接口边界

任务看板不直接推进节点状态。`PATCH /api/tasks/:taskId` 拒绝旧阶段字段写入，也拒绝 `status`、`progress`、`blockedReason` 这类 plugin canonical dev_task 字段的写入；用户侧只保留 `priority` 元数据更新。

列表和详情响应中仍有 `phase` 展示兼容字段，由 `currentNode` 映射而来，不是持久化真相。前端看板实际按 `currentNode`、`runtimeState`、`reviewStatus` 和 `status` 推导列。

旧 AI task slot 启动入口 `POST /api/tasks/:taskId/start-ai-session` 当前返回 410；旧 Epic 接口也返回 410。活流程应通过需求详情、anchor/runtime 与受控评审意图触发。

## 6. 旧规格 vs 实际偏差

旧规格把任务看板描述为简单的阶段列、任务卡片和详情面板，并假设可修改状态、进度、负责人。真实 v1.0 已经迁移为 node projection：状态真相是 `currentNode`、`nodeSubstate`、`runtimeState`、`lastTransitionId`，UI 只做投影和受控触发。

旧规格里的 `TaskPhaseBadge` 概念已过时；当前 UI 使用 node badge、review projection、详情组件和 timeline/consultation/checkpoint 等视图。

## 7. v1.0 校正点

- 看板列不是业务状态真相，只是 node projection 的四列视图。
- 任务详情包含关联需求、文档、工作区、评审意图和事件时间线。
- Sprint 是当前实现中的项目级任务组织能力。
- `phase` 仅是 API 兼容投影，不能作为写入或持久化字段。

## 8. 待定事项

- `phase` 兼容字段的最终删除时点需要产品/客户端兼容性确认。
- TaskRun 与 anchor runtime 的 UI 汇合边界仍在演进，任务看板目前只展示相关投影与触发入口。
