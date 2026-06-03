---
doc_type: module_spec
title: "SU-Oriel TaskRun 状态机模块规格"
status: active
updated: 2026-06-03
---

# SU-Oriel TaskRun 状态机模块规格

## 1. 模块目标

TaskRun 模块描述单个任务的一次执行尝试、尝试序号、执行状态和状态迁移轨迹。它与任务节点状态不同：`Task` 的业务节点真相来自 `currentNode`、`nodeSubstate`、`runtimeState`、`lastTransitionId`；`TaskRun` 只表达一次执行尝试的运行态。

真实实现锚点：

- `su-oriel/server/src/modules/task-run/task-run.state-machine.ts`
- `su-oriel/server/src/modules/task-run/task-run.service.ts`
- `su-oriel/server/src/modules/task-run/task-run.routes.ts`
- `su-oriel/server/src/modules/task-run/dirty-check.ts`
- `su-oriel/server/src/modules/kernel/apply.routes.ts`
- `su-oriel/server/prisma/schema.prisma`
- `su-oriel/server/src/modules/task/task.routes.ts`
- `su-oriel/server/src/modules/task/phase-derive.ts`

## 2. 功能范围

| 能力 | 当前实现 |
|---|---|
| 状态集合 | `pending`、`dispatched`、`running`、`paused`、`completed`、`cancelled`、`failed`。 |
| 终态集合 | `completed`、`cancelled`、`failed-terminal`。 |
| 迁移校验 | `canTransitionTaskRun` 与 `assertTaskRunTransition` 根据 allowed transitions 拒绝非法迁移。 |
| 执行入口 | `/api/task-runs/:taskId/dispatch`、`retry`、`pause`、`resume`、`cancel`。 |
| 错误映射 | 输入错误 400，不存在 404，已关闭入口 410，冲突 409。 |
| dispatch 现状 | `dispatchTaskRun` 当前直接返回 410：SU-Oriel worktree 入口已关闭。 |
| pause/resume/cancel | 对已有 latest run 先校验状态，再通过 kernel apply 走受控 primitive。 |

## 3. 状态迁移

| from | to | attempt 变化 | 说明 |
|---|---|---|---|
| `pending` | `dispatched` | 不变 | 初次派发。 |
| `dispatched` | `running` | 不变 | worker 接受执行。 |
| `running` | `paused` | 不变 | 暂停执行。 |
| `paused` | `running` | 不变 | 恢复执行。 |
| `running` | `completed` | 不变 | 执行完成。 |
| `running` | `failed` | 不变 | 失败但可重试。 |
| `failed` | `dispatched` | +1 | retry 派发下一次 attempt。 |
| `pending` / `dispatched` / `running` / `paused` / `failed` | `cancelled` | 不变 | 取消执行。 |
| `failed` | `failed-terminal` | 不变 | 失败终止。 |

终态不可再迁出。状态机是 allowed transition 表，不是 DAG；`running` 与 `paused` 允许循环。

## 4. 数据模型

| 模型 | 字段/关系 | 说明 |
|---|---|---|
| `TaskRun` | `taskId`、`status`、`attemptN`、`dispatchedAt`、`completedAt`、`errorSummary`、`transitionsJson`、`workspacePath`、`worktreeBranch` | 一次任务执行尝试。 |
| `Task` | `currentNode`、`nodeSubstate`、`runtimeState`、`lastTransitionId` | 任务业务节点真相字段，不由 TaskRun 状态替代。 |
| `TaskWorkspace` | `lockedByRunId`、`workspacePath`、`branchName`、`status` | 工作区投影，可与 TaskRun 关联。 |

## 5. 接口边界

TaskRun 路由存在，但 dispatch 已被显式关闭，返回 410，原因是 per-需求 worktree 生命周期由 CCB plugin 管理。文档不能把 SU-Oriel 描述成当前执行 worktree 的创建者或业务写入者。

`retryTaskRun` 依赖 `dispatchTaskRun`，因此在 dispatch 关闭期间也无法真正重新派发。`pauseTaskRun`、`resumeTaskRun`、`cancelTaskRun` 仍按 latest run 状态校验后调用 kernel apply。

任务列表/详情里的 `phase` 是展示兼容投影，由 `currentNode` 映射而来；写入旧阶段字段会被拒绝。活状态应读取 `currentNode`、`nodeSubstate`、`runtimeState`、`lastTransitionId` 与 TaskRun 自身 `status`。

## 6. 旧规格 vs 实际偏差

旧 TaskRun 规格写成 “schema only”，并声明不实施 dispatch/retry/pause/resume/cancel 路径。真实 v1.0 已有路由、服务、错误映射和 kernel apply 集成，但 dispatch 被产品架构显式关闭。

旧 phase 迁移文档是点状迁移 runbook，包含旧路径和兼容期操作清单；活规格只保留当前结论：旧阶段列已退役，任务业务节点以 node 字段为真相，API 的 `phase` 只是临时展示兼容。

## 7. v1.0 校正点

- `TaskRun` 是执行尝试状态，不等于任务业务节点状态。
- `Task` 当前没有持久化旧阶段列；`currentNode/nodeSubstate/runtimeState/lastTransitionId` 是任务节点投影字段。
- SU-Oriel worktree dispatch 入口已关闭，不能在规格里承诺可用。
- phase deprecation 的活结论已并入本规格，原点状文档归档。

## 8. 待定事项

- dispatch 入口是否长期保持 410，还是未来接回 plugin 管理的 runtime，需要架构侧另行决策。
- `failed-terminal` 当前是状态机终态语义，是否会由真实运行路径写入仍需后续实现确认。
