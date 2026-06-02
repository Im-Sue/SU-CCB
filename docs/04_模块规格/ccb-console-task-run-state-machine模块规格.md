---
doc_type: module_spec
title: "TaskRun State Machine"
updated: 2026-05-28
---
# TaskRun State Machine

## 1. 背景

| 项 | 内容 |
|---|---|
| 任务 | E9-T1 TaskRun Prisma model + 状态机 schema |
| 范围 | Console server TaskRun 持久化模型与状态转换表 |
| 状态 | schema only |

TaskRun 表示一个 Task 的一次执行尝试。一个 Task 可以有多个 TaskRun，
每个 TaskRun 用 `attempt_n` 标记尝试序号，并用 `transitions` 记录状态变化轨迹。

本状态机采用 allowed transitions 表，不是 DAG。允许 `running` 与 `paused` 循环，
也允许 `failed` 在可重试时回到 `dispatched`。本文件只定义模型和转换规则，
不实施 dispatch、retry、pause、resume、cancel 路径，也不集成 K1 apply endpoint。

## 2. 状态集合

| status | 含义 |
|---|---|
| `pending` | TaskRun 已创建，尚未派发 |
| `dispatched` | 已派发给执行者，等待 pickup |
| `running` | 执行者已接受并正在执行 |
| `paused` | 当前执行被暂停，保留恢复能力 |
| `completed` | 执行成功完成 |
| `cancelled` | 执行被取消 |
| `failed` | 本次执行失败，但仍可能重试 |

终态集合：

- `completed`
- `cancelled`
- `failed-terminal`

`failed-terminal` 是状态机终态语义，用于表示重试次数耗尽后的失败终止。
数据库 `status` 字段仍保存字符串，由后续 E9-T2 路径按规则写入。

## 3. Allowed Transitions

| from | to | attempt_n | 说明 |
|---|---|---|---|
| `pending` | `dispatched` | 不变 | 初次派发 |
| `dispatched` | `running` | 不变 | 执行者 pickup 并开始运行 |
| `running` | `paused` | 不变 | 暂停运行中的执行 |
| `paused` | `running` | 不变 | 恢复暂停的执行 |
| `running` | `completed` | 不变 | 执行成功完成 |
| `running` | `failed` | 不变 | 执行失败，保留重试可能 |
| `failed` | `dispatched` | +1 | retry 进入下一次派发 |
| `pending` | `cancelled` | 不变 | 派发前取消 |
| `dispatched` | `cancelled` | 不变 | pickup 前取消 |
| `running` | `cancelled` | 不变 | 运行中取消 |
| `paused` | `cancelled` | 不变 | 暂停状态取消 |
| `failed` | `cancelled` | 不变 | 失败后不再重试，人工取消 |
| `failed` | `failed-terminal` | 不变 | 达到 max retry 后进入失败终态 |

除上表外的转换默认拒绝。任一终态进入后不可再迁出。

## 4. attempt_n 幂等规则

`attempt_n` 是 TaskRun 尝试序号，初始值为 `1`。同一个 Task 的同一次派发、
pickup、pause、resume、complete、fail、cancel 重放时必须保持相同 `attempt_n`，
不得因为重复事件而创建新的 attempt。

只有 `failed -> dispatched` retry 转换会递增 `attempt_n`。重试请求必须携带
可复用的 idempotency key，并以 `(taskId, attempt_n, transition)` 为幂等判断边界：
同一边界内重复提交返回已有结果；新的 retry 才能产生 `attempt_n + 1`。

## 5. transitions 记录

`transitions` 是 JSON array 字符串，记录 TaskRun 状态变更轨迹。每条记录建议包含：

```json
{
  "from": "pending",
  "to": "dispatched",
  "attempt_n": 1,
  "transition_id": "task-run:pending->dispatched",
  "triggered_at": "2026-05-03T00:00:00.000Z",
  "idempotency_key": "task-run:task-id:attempt-1:dispatch"
}
```

后续执行路径写入时应追加记录，不应覆盖已有轨迹。

## 6. 边界

本 task 只固化 schema 和 allowed transitions：

- 不实施 dispatch / retry / pause / resume / cancel 路径。
- 不实施 K1 apply endpoint 集成。
- 不实施 worktree 分配或清理。
- 不改变 `references/kernel/state-schema.yaml`。
