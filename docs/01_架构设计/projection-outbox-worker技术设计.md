---
doc_type: architecture
title: "ProjectionOutbox Worker 技术设计"
updated: 2026-06-10
---

# ProjectionOutbox Worker 设计大纲

## 0. 范围与目的

落地 ADR-0013 §5 "Projection ↔ state file 同步"协议中**尚未实现**的 DB → 文件方向。当前实现：
- `apps/ccb-console/server/src/modules/task/state-projection.ts` 处理 **file → DB**（read snapshot, refresh projection）
- Prisma model `ProjectionOutbox` 已落库（schema.prisma），但**零代码 enqueue**，零 worker 拉取

本设计覆盖：enqueue 时机、worker loop、state file 生成器、reconcile job、failure 语义、idempotency、observability。

不覆盖：state file 内部 markdown 的具体字段语义（沿用 `state-schema.yaml` + 现有 `extractFrontmatter`）。

## 1. 关键设计决策

| # | 决策 | 备选方案与理由 |
|---|---|---|
| D1 | **单进程 in-process worker**，启动随 server boot，stop 随 SIGTERM | 不引入 BullMQ / Redis；console 单实例部署，无水平扩展需求；切走 leader election 复杂度 |
| D2 | **轮询间隔 1s**（可 env 配） | 100ms 太密 / 5s 用户感知延迟；1s 在交互性 vs 负载之间 |
| D3 | **批大小 N=20**（可 env 配） | 单次 SELECT 限 20 行，避免 worker 长 tx |
| D4 | **重试上限 5 次**（与 ADR-0013 §5 一致） | 已锁定 |
| D5 | **重试退避：updatedAt 作 lastAttemptAt 过滤；delay(n) = min(2s × n, 30s)** | 简单可预测；不加 schema migration（P4 闭合） |
| D6 | **enqueue 由 caller 在自己 prisma.$transaction 内调 `enqueueProjectionOutbox(tx, ...)` helper**（plan review R1 P1 修订；不改 primitiveExecutor.run 签名）| caller-owned tx 不引入 wrapper 大重构；漏写风险归 master roadmap E1.5 primitive-wrapper-rollout 集中处理 |
| D7 | **state file 生成 = 反向 `parseStateMd`** | 复用现有 `extractFrontmatter` 反向工具；保证回环可逆（write→read 应得同一 frontmatter） |
| D8 | **reconcile 启动时跑一次** + 每 5 分钟一次 | 启动跑：处理 server crash 期间 'pending' 历史项；周期跑：兜底 file 被外部修改的漂移 |
| D9 | **outbox row `status=failed` + structured log**，不写 EventJournal canonical types（consult C1 修订） | outbox 已含 retryCount / lastError / updatedAt；Console ops 面板订阅 outbox 表查询；不扩 E6 event-store contract |
| D10 | **archive 后的 task state file 也走 outbox** | archive 仍是 DB 写，路径切换 active → archive 由生成器决定（参考 `resolveStatePath`） |

## 2. 模块拆分

```
apps/ccb-console/server/src/modules/task/
  state-projection.ts            (existing, file→DB 不动)
  projection-writer.ts           (NEW, DB→file 生成器)
  projection-outbox-worker.ts    (NEW, 拉 outbox + 调 writer + 状态机)
  projection-outbox-enqueue.ts   (NEW, 提供 enqueue helper)
```

集成点：
- 应升级 caller（设计 §12.2 白名单）：在自己 `prisma.$transaction` 内 task 写完后调 `enqueueProjectionOutbox(tx, { taskId, revision })`
- `server-bootstrap`：启动时 `await reconcileProjections()` + 拉起 `startProjectionOutboxWorker()`
- `server-shutdown`：`stopProjectionOutboxWorker()` 等待当前 batch 完成

## 3. 数据流

### 写路径（每次 Task mutation，由 caller 主导）

**R3-P1 修订**：`Task.stateRevisionSeen` 是 `Int?`（nullable）。caller 必须先读 `beforeRevision`，计算 `afterRevision = (beforeRevision ?? 0) + 1`，**显式 set**（不能用 `{ increment: 1 }`，对 null 行为未定义）。

```
caller (e.g. update_task_metadata):
  prisma.$transaction(async tx => {
    const before = await tx.task.findUnique({
      where: {id},
      select: { stateRevisionSeen: true }
    });
    const beforeRevision = before?.stateRevisionSeen ?? 0;
    const afterRevision = beforeRevision + 1;
    const updated = await tx.task.update({
      where: {id},
      data: { ...stateFields, stateRevisionSeen: afterRevision }
    });
    await enqueueProjectionOutbox(tx, {
      taskId: updated.id,
      revision: afterRevision  // ← 永远 >= 1，不可能 null
    });
    return updated;
  });
```

幂等：`idempotencyKey UNIQUE` 拒绝重复（caller 重试时静默吞 P2002）。

**注 1**：transition-consumption 的嵌套结构（outer `apply_task_projection_transition` + inner `apply_event_transition_to_task_projection` / `record_transition_apply_audit`）只在 outer 的 `task.updateMany` 成功后调一次 enqueue，inner primitive 不重复调。outer 已用 `beforeRevision = task.stateRevisionSeen ?? 0` 模式（见 transition-consumption.service.ts:246）。

**注 2**：`materialize_requirement_task` 创建 task 时 caller 必须显式设 `stateRevisionSeen: 1`（不能省略让 default null），enqueue 用 `revision: 1`。

### Worker loop

**Single-flight 约束**（R2-P4 修订）：worker 用 promise chain 串行驱动，**不**用 `setInterval`。一轮 tick 完整结束（处理完拿到的 batch + sleep 1s）后才启动下一轮，避免重叠 tick / 并发处理同 row。`startProjectionOutboxWorker` 返回 `{ stop }` 句柄；`stopProjectionOutboxWorker` 等当前 tick 完成。

```
loop:
  # P4 修订：用 updatedAt 作 lastAttemptAt，过滤未到 nextAttempt 的 row
  # delay(retryCount) = min(2s × retryCount, 30s)；retryCount=0 时立即拉
  rows = SELECT WHERE status='pending'
           AND (retryCount = 0 OR updatedAt <= NOW - delay(retryCount))
         ORDER BY createdAt
         LIMIT N
  if rows.empty: sleep 1s; continue
  for row in rows:
    try:
      task = prisma.task.findUnique({id: row.taskId})
      if not task:
        UPDATE outbox SET status='failed', lastError='task_deleted', updatedAt=NOW WHERE id=row.id
        log.warn('projection.failed', { taskId, revision, reason: 'task_deleted' })
        continue
      writeStateFile(task)  # 见 §4
      UPDATE outbox SET status='projected', updatedAt=NOW WHERE id=row.id
    catch err:
      retry = row.retryCount + 1
      if retry >= 5:
        UPDATE outbox SET status='failed', retryCount=retry, lastError=err.message, updatedAt=NOW
        log.error('projection.failed', { taskId, revision, retry, error: err.message })
        # ↑ C1 决策：structured log，不写 EventJournal
      else:
        UPDATE outbox SET retryCount=retry, lastError=err.message, updatedAt=NOW
        # 下一轮被 SELECT 过滤排除，直到 NOW + delay(retry) 到达
```

### Reconcile（启动 + 周期）

```
reconcileProjections():
  # Phase 1: 历史 pending（server crash 期间未处理 + 失败重启）
  pending_count = SELECT count(*) WHERE status='pending'
  log("reconcile.startup", pending_count)

  # Phase 2: file ↔ DB drift 检测
  drift_count = 0
  for task in prisma.task.findMany({select:{id, stateRevisionSeen, projectId, taskKey, ...}}):
    revision = task.stateRevisionSeen ?? 1   # R2-P3: null 视为首次投影 revision=1
    snapshot = readCurrentStateSnapshot(task)   # 复用现有
    if snapshot is null OR snapshot.revision < revision:
      # P5 修订：用同一 idempotencyKey；upsert
      # drift 命中即 reset row 状态（无论原 status 是 pending/failed/projected）：
      # - 文件被删 → snapshot null → projected row 也要 reset 重写
      # - 文件 revision 落后 → 同上
      # - 已 projected 且文件最新 → drift 判断不命中，不触碰
      try {
        await prisma.projectionOutbox.upsert({
          where: { idempotencyKey: `${task.id}:${revision}` },
          create: { taskId: task.id, revision,
                    idempotencyKey: `${task.id}:${revision}`,
                    status: 'pending', retryCount: 0 },
          update: { status: 'pending', retryCount: 0, lastError: null, updatedAt: NOW }
        })
        drift_count++
      } catch (err) {
        # per-row catch (R2 N3)：单 task 异常不阻塞全扫
        log.warn('reconcile.drift_upsert_failed', { taskId: task.id, error: err.message })
      }

  # Phase 3: 输出 metrics
  return {
    pending_replayed: pending_count,
    drift_reenqueued: drift_count,
    duration_ms: ...,
    oldest_pending_lag_seconds: ...
  }
```

**P5 修订**：reconcile 使用与正常写路径相同的 `${taskId}:${revision}` idempotencyKey，通过 upsert 复用 row。**drift 命中即 reset**（无论 row 原 status；包括 projected row 在文件被删/回退时也 reset 重写）；drift 不命中（文件存在且 revision 等于 task）则 row 不动。

**R2-P3 null revision**：`Task.stateRevisionSeen` 是 `Int?`。enqueue/reconcile 遇 null 时统一视为 `1`（首次投影）。`materialize_requirement_task` 创建 task 时**应同时**设置 `stateRevisionSeen: 1`，避免 null 蔓延（slice 1 caller adoption 要求显式设值）。

## 4. State file 生成器（projection-writer）

### 4.1 路径定位（consult Q1A 决策）

**不加 `Task.documentPath` 列**。复用 `state-projection.ts:264` 的 `resolveStatePath` 语义：

```
priority 1: Project.localPath + Document(kind=state, taskKey).path
priority 2 (fallback): Project.localPath + docs/.ccb/state/<taskKey>.md
```

实现选项（不改 `state-projection.ts`）：
- **选项 a**：在 `projection-writer.ts` 内复制等价路径解析逻辑（推荐，独立，不耦合）
- **选项 b**：新建 `apps/ccb-console/server/src/modules/task/state-path.helper.ts` 共享 helper，state-projection.ts 与 projection-writer.ts 都调用（refactor 较大）

本轮采 **选项 a** —— 避免动 state-projection.ts；后续若 helper 复用面变大再 refactor 提取。

### 4.2 writer 函数

**R3-P1 修订**：writer 接受 `outbox.revision` 作 frontmatter revision 来源（不是直接读 task.stateRevisionSeen），保证 revision 永远是已归一化的 >= 1 整数：

```ts
async function writeStateFile(task: TaskWithDocument, outboxRevision: number): Promise<void> {
  const path = resolveStatePathLocal(projectRoot, task.taskKey, task.stateDocument?.path ?? null);
  const frontmatter = serializeFrontmatter({
    task_id: task.taskKey,
    spec_id: task.linkedSpecId ?? null,
    title: task.title,
    currentNode: task.currentNode,
    nodeSubstate: task.nodeSubstate,
    runtimeState: task.runtimeState,
    lastTransitionId: task.lastTransitionId,
    revision: outboxRevision,  // ← 来自 outbox row，永远 >= 1
    status: task.status,
    kind: task.kind,
    parentEpicId: task.parentEpicId,
    requirementId: task.requirementId,
    epicStatus: task.epicStatus,
    implementationOwner: task.implementationOwner,
    // ... 其他 ADR-0013 schema 字段
  });
  const body = readExistingBody(path) ?? defaultBody();  // 不覆盖人写的正文
  await atomicWrite(path, `---\n${frontmatter}\n---\n\n${body}`);
}
```

worker 调用：`writeStateFile(task, row.revision)`。

关键约束：
- **不覆盖正文**：state file body 是人编辑的；writer 只覆盖 frontmatter
- **原子写**：写到 `${path}.tmp` 再 rename
- **task 无 state Document 时**：使用 fallback 约定路径创建文件；Document 表同步**不在 writer 内做**（依赖 indexer/file watcher 后续补齐 Document row）。这是已知 limitation，列入 followup（见 §9）。

## 5. 失败语义（consult C1 决策修订）

5 次重试后标 outbox row `status=failed`，写 **structured log**（`pino` 标准日志，含 task_id / revision / error / retry_count），**不**扩 EventJournal canonical types。Console ops 面板订阅 `prisma.projectionOutbox.findMany({ where: { status: 'failed' } })` 即可，不需要新事件类型。

| 失败 | 行为 |
|---|---|
| Task 不存在（已 hard-delete） | 直接标 outbox `status=failed` + structured log reason='task_deleted' |
| 路径不可写（ENOENT 父目录） | 自动 mkdir -p；mkdir 失败按通用 retry 走 |
| frontmatter 序列化失败 | 标 `failed`，log full error |
| 文件被外部进程锁定 | 算 retry；5 次后 failed |
| body 读失败（state file 损坏） | 用 default body 重生（不阻塞 frontmatter 写入） |
| Worker 进程崩溃 | 重启时由 reconcile phase 1 把 'pending' 历史项重拉 |

**不新增** `projection_failed` canonical event type（避免扩 E6 event-store contract 范围）。

## 6. 可观测性

| Metric | 来源 |
|---|---|
| `outbox.pending.count` | `SELECT count WHERE status='pending'` |
| `outbox.failed.count` | `SELECT count WHERE status='failed'` |
| `outbox.lag.seconds` | 当前时间 - oldest pending createdAt |
| `projection.write.duration.ms` | per-write 计时 |
| `outbox.failed.log` | structured log + outbox row status=failed（C1 决策，不进 EventJournal）|
| `reconcile.pending_count` | reconcile 每轮报 |
| `reconcile.drift_reenqueued` | reconcile 每轮报 |
| `reconcile.duration_ms` | reconcile 每轮报 |
| `reconcile.oldest_pending_lag_seconds` | reconcile 每轮报 |

Console 看板（后续 PR）订阅 `prisma.projectionOutbox.findMany({ where: { status: 'failed' } })` + 解析 structured log。

## 7. 测试策略

| 类型 | 用例 |
|---|---|
| 单测 · writer | frontmatter 反向解析回环（write→read 应等价） |
| 单测 · enqueue | 重复 enqueue 同 idempotencyKey 不报错 |
| 集成 · worker loop | 写 1 row → 1s 内 status='projected' + state file 内容正确 |
| 集成 · retry | mock writeStateFile fail 4 次成功 1 次：retryCount=4，最终 'projected' |
| 集成 · failed | mock writeStateFile fail 5 次：outbox status='failed'，structured log 输出含 task_id/revision/error |
| 集成 · reconcile | server 启动前手动塞 1 'pending' 历史 row → 启动后被处理 |
| 集成 · reconcile drift | 删 1 个 state file → 周期 reconcile 重生 |
| 集成 · reconcile per-row | mock 1 row writeStateFile throw → 同 batch 其他 row 仍处理（错误隔离）|
| invariant | 每个声明 enqueue descriptor 的 primitiveExecutor.run 后存在对应 outbox row（status pending or projected） |

## 8. 失败与降级

| 场景 | 降级 |
|---|---|
| 整个 worker 挂死 | 不影响 read（DB SoT）；state file stale；reconcile 周期会兜底 |
| outbox 表损坏 | 紧急绕过：禁用 worker（env flag），降级为 best-effort sync write（旧行为） |
| state file 系统盘满 | outbox row status=failed + structured log；DB 仍正确，恢复盘后 reconcile 自动补 |

## 9. 不做（留后续）

- 多进程 / 水平扩展（D1）
- 指数退避（D5）
- ops alert / Slack（D9 由 Console 后做）
- state file body 模板化（writer 只动 frontmatter）
- archive 路径切换的 audit log（用 EventJournal `task_archived` 兜底）
- **raw task writes 覆盖**（sprint.routes / task.routes epic cancel / scheduler epic-lifecycle handler 等）— 归 master roadmap E1.5 primitive-wrapper-rollout epic 集中处理（user B1 决策）
- **task 无 state Document 时 writer 创建文件后 Document 表同步** — 依赖 indexer / file watcher 后续补齐 Document row（Q1A followup limitation）
- **`projection_failed` canonical event** — 不扩 EventJournal types（C1 决策），结合 outbox failed status + structured log 替代

## 10. 验收

worker 实施 PR 必须包含：
1. 4 个新模块文件 + 单测
2. `enqueueProjectionOutbox` helper（B 决策 caller-owned tx）+ caller 白名单（§12.2）升级 + 集成测
3. server bootstrap / shutdown wiring
4. 1 份 e2e 集成测覆盖 §3 三个流程
5. 启动后跑 reconcile 输出 metrics 截图（或日志）

## 11. 开放问题（已 resolved 2026-05-10）

consult job_297bb0467afa, rep_6626e2a5d4f5。用户决策 A1+B1+C1。

| Q | 答复 | 影响 |
|---|---|---|
| Q1 · `task.documentPath` 字段策略 | A · 复用 state-projection Document join 路径，**不加** Task.documentPath 列 | §4.1 路径定位选项 a |
| Q2 · `revision` 推进时机 | A1 · 扩 `primitiveExecutor.run` API 接收 enqueue descriptor；revision 推进在 caller/语义层做，不盲拦截 | ADR-0014 Decision §1 修订；slice 1 实施 |
| Q3 · enqueue 是否记 EventJournal | 否 · outbox row 即 audit | §6 metrics + §5 失败语义 |
| Q4 · reconcile 周期 5 分钟负载 | 5 分钟落地 + metrics（实测 dev.db 246 docs / 49ms / 0.20ms 一个 doc，量级低）。164 estimate 偏低，实际 dev.db 两 project 约 180+163 tasks | §4 D8 + §6 |
| Q5 · projectId 隔离 | 否 · taskId 全局唯一，row-level retry 隔离 | 不动 schema |

**B1 决策**：raw task writes（sprint.routes / task.routes epic cancel / scheduler epic-lifecycle）覆盖归 master roadmap E1.5 primitive-wrapper-rollout，本 ADR 范围**不**覆盖。

**C1 决策**：5 次失败标 outbox `status=failed` + structured log，**不**扩 EventJournal canonical types。

实施由 batch `2026-05-10-batch-m2-3c-implementation` 5 slice 推进（see state file）。

## 12. Q2 修订 · API 形态（用户决策 B + plan review R1 修复 P1/P2）

### 12.1 API 形态：caller-owned tx + helper

**不改 `primitiveExecutor.run` 签名**。新建 `enqueueProjectionOutbox` helper：

```ts
// apps/ccb-console/server/src/modules/task/projection-outbox-enqueue.ts

import { Prisma } from "@prisma/client";

export interface EnqueueProjectionOutboxInput {
  taskId: string;
  revision: number;  // 必须 >= 1；null 由 caller 在升级时显式 default 1（R2-P3）
}

/**
 * Enqueue a ProjectionOutbox row for DB→file projection.
 * Caller MUST hold an open prisma transaction (Prisma.TransactionClient).
 * Idempotent on (taskId, revision) — repeat calls swallow P2002.
 */
export async function enqueueProjectionOutbox(
  tx: Prisma.TransactionClient,
  input: EnqueueProjectionOutboxInput
): Promise<void> {
  // R3-P1: runtime 拒绝 null/0/负数 revision
  if (!Number.isInteger(input.revision) || input.revision < 1) {
    throw new Error(
      `enqueueProjectionOutbox: revision must be integer >= 1, got ${input.revision}`
    );
  }
  try {
    await tx.projectionOutbox.create({
      data: {
        taskId: input.taskId,
        revision: input.revision,
        idempotencyKey: `${input.taskId}:${input.revision}`,
        status: "pending",
        retryCount: 0
      }
    });
  } catch (err) {
    // R2-P6: 用 Prisma.PrismaClientKnownRequestError P2002 判断 unique violation
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2002") {
      return;  // 重复 enqueue 静默吞
    }
    throw err;
  }
}
```

caller 升级模式：

```ts
// caller 已有 prisma.$transaction 用法（推荐）
const updated = await prisma.$transaction(async (tx) => {
  const current = await tx.task.findUniqueOrThrow({
    where: { id },
    select: { id: true, stateRevisionSeen: true }
  });
  const afterRevision = (current.stateRevisionSeen ?? 0) + 1;
  const task = await tx.task.update({
    where: { id },
    data: { ...stateFields, stateRevisionSeen: afterRevision }
  });
  await enqueueProjectionOutbox(tx, { taskId: task.id, revision: afterRevision });
  return task;
});

// caller 当前直接 prisma.task.update 无 tx：包成 $transaction
const updated = await prisma.$transaction(async (tx) => {
  const current = await tx.task.findUniqueOrThrow({
    where: { id },
    select: { id: true, stateRevisionSeen: true }
  });
  const afterRevision = (current.stateRevisionSeen ?? 0) + 1;
  const task = await tx.task.update({
    where: { id },
    data: { ...stateFields, stateRevisionSeen: afterRevision }
  });
  await enqueueProjectionOutbox(tx, { taskId: task.id, revision: afterRevision });
  return task;
});
```

primitiveExecutor.run 仍是外层 audit/idempotency wrapper，不感知 enqueue。

### 12.2 Caller 白名单（slice 1 升级面 · R2-P1 修订）

判定规则：caller **直接** `prisma.task.create / update / updateMany / upsert`（写 Task 表 state 字段）→ 应升级。写其他表（TaskRun / ReviewIntent / EventConsumption / Document / TaskWorkspace）→ 不升级。

**应升级声明 enqueue（grep 验证 prisma.task.{create,update,updateMany,upsert} 存在）**：

| caller / primitive | 文件位置 | 实际写法 | enqueue 时机 |
|---|---|---|---|
| `update_task_metadata` | task.routes.ts:275 | prisma.task.update | update 后调 enqueue(tx, taskId, afterRevision) |
| `apply_task_projection_transition` (outer wrapper) | transition-consumption.service.ts:215 | prisma.$transaction 含 inner task.updateMany | 在 outer tx 的 task.updateMany 成功后调一次 enqueue(tx, taskId, afterRevision)。**inner primitive (record_transition_apply_audit / apply_event_transition_to_task_projection) 不重复调** |
| `materialize_requirement_task` | project-indexer.ts:860 | prisma.task.create | create 时显式设 stateRevisionSeen=1（R2-P3），create 后调 enqueue(tx, taskId, 1) |

**明确不升级（写 TaskRun / 其他表 / file→DB / audit / 索引路径）**：

| caller / primitive | 理由 |
|---|---|
| `dispatch_task` (apply.routes.ts:352-) | 仅写 prisma.taskRun.create/update（mutationType: "prisma.taskRun.create/update"）|
| `pause_task` / `resume_task` / `cancel_task` (apply.routes.ts:215-295) | 仅写 prisma.taskRun.update（mutationType: "prisma.taskRun.update"）|
| `apply_event_transition_to_task_projection` (transition-consumption.service.ts:272 inner) | inner 路径，由 outer `apply_task_projection_transition` 已 enqueue（避免双重）|
| `record_transition_apply_audit` 等 record_* | 写 EventConsumption audit 表，不动 Task |
| `consult_codex` | file CAS to DB（file→DB 路径）|
| `refresh_task_projection` | file → DB refresh |
| `apply_task_projection_diff` | indexer file → DB |
| `apply_requirement_diff` | indexer requirement file → DB |
| `consume_external_event_transition` | EventConsumption 表 |
| `consume_review_intent` / `create_review_intent` / `cancel_review_intent` | ReviewIntent 表 |
| `apply_task_workspace_state` / `cleanup_task_workspace` | TaskWorkspace 表 |
| `cleanup_taskrun_worktree` | TaskRun + filesystem |
| `write_generated_doc` / `cleanup_stale_task_projections` / `merge_task_identity_assignment` | 索引/清理路径 |
| `consume_external_event_transition` (transition-consumer-wrapper) | EventConsumption 表 + file→DB 路径 |

**Deferred · raw task writes（R3-N1 显式标注）**——绕过 primitive wrapper 的 raw `prisma.task.update` 影响 Task state 但不在本 ADR 范围（B1 决策，归 master roadmap E1.5 primitive-wrapper-rollout）：

| caller | 文件位置 | 影响 |
|---|---|---|
| sprint task assignment | `apps/ccb-console/server/src/modules/sprint/sprint.routes.ts` (sprintId update) | task.sprintId（不影响 state frontmatter，可低优）|
| epic cancel | `apps/ccb-console/server/src/modules/task/task.routes.ts` (epic cancel branch) | task.status / task.cancelledAt |
| scheduler epic-lifecycle | `apps/ccb-console/server/src/modules/scheduler/handlers/epic-lifecycle.handler.ts` | task.create/update by scheduler |

→ 这些 raw writes 在 m2-3c 落地后**不会 enqueue**，state file 短期内可能与 DB 漂移。**reconcile 周期会兜底**（drift 检测命中 → re-enqueue）。E1.5 epic 完成后这些 caller 会改走 primitive wrapper + helper enqueue。

### 12.3 Slice 1 验收（R2 修订）

- [ ] `enqueueProjectionOutbox` helper + 单测（成功 / 重复 P2002 静默 / tx rollback 时不入库 / null revision 拒绝）
- [ ] 应升级白名单 3 个 caller 全量升级 + 每个 caller 至少 1 个 happy-path 集成测验证 outbox row 入库
- [ ] 不升级清单 grep 验证未引入 `enqueueProjectionOutbox` 调用（避免误升级 file→DB / TaskRun-only 路径）
- [ ] `materialize_requirement_task` 创建 task 时显式设 `stateRevisionSeen: 1`（R2-P3 null revision 处理）
- [ ] transition-consumption 路径无双重 enqueue（grep `enqueueProjectionOutbox` 在 transition-consumption.service.ts 仅 1 处调用）

**path parity test 移到 Slice 2**（属 writer 范围，更聚焦）。
