---
id: ADR-0014
title: ProjectionOutbox Worker — DB→file 投影的 outbox-driven 异步落盘
status: accepted
decided_at: 2026-05-09
accepted_at: 2026-05-10
decider: Claude
reviewer: ccb_codex
implementation_batch: 2026-05-10-batch-m2-3c-implementation (5 slice all pass)
related_epic: task-hierarchy-three-tier-model
related_adr: [ADR-0012, ADR-0013, ADR-0016]
related_tasks: [task-hierarchy-m2-3c-projection-outbox-worker (implemented in commits eee5865 → e860bf6)]
deprecated_in: null
removed_in: null
grace_window: null
impacted_components: [apps-ccb-console-server]
---

# ADR-0014: ProjectionOutbox Worker

## Status

Proposed（待 codex review）。

## Context

ADR-0013 §5 定义了 Projection ↔ state file 同步协议（DB SoT，state file = async outbox / projection），并落了 Prisma `ProjectionOutbox` 表。但**实施层只完成了一半**：

- ✅ file → DB（read）方向：`apps/ccb-console/server/src/modules/task/state-projection.ts`，由 `refreshTaskStateProjection` 与 indexer 提供
- ❌ DB → file（write）方向：零代码 enqueue，零 worker 拉取；M2-PR4 spec 明确将其登记为 deferred（"state file generation 设计未敲定"）

后果：当前所有 `prisma.task.update` 后**不会自动重写 state file**；用户看到的 state 文件靠 indexer 反向 / 人工编辑维持。在 hierarchy 模型上线后，这种"半投影"会在 epic_replan / subtask 创建等高频写场景下加剧 file ↔ DB 漂移。

## Decision

落地 outbox-driven 异步 worker，按 ADR-0013 §5 协议：

1. **enqueue 由 caller 在自己 prisma.$transaction 内调 helper**（D6 修订 · plan review R1 P1）：新建 `enqueueProjectionOutbox(tx, { taskId, revision })` helper（`apps/ccb-console/server/src/modules/task/projection-outbox-enqueue.ts`）；DB→file 写路径 caller 升级为 `prisma.$transaction` + `tx.task.update` + `enqueueProjectionOutbox(tx, ...)`；幂等键 `${taskId}:${revision}` UNIQUE 拦重复，重复 P2002 静默吞。**不改** `primitiveExecutor.run` 签名（避免大重构）。caller 白名单见设计文档 §12。
2. **单进程 in-process worker**（D1）随 server boot 启动，1s 轮询、20 行批拉、5 次重试上限、固定 2s × retryCount 退避（max 30s）。
3. **state file 生成器**（D7）只覆盖 frontmatter，保留人写的正文；写文件原子化（tmp + rename）。**路径定位复用 state-projection 的 Document join 语义**（consult Q1A 决策），不加 `Task.documentPath` 列；不改 `state-projection.ts`，新建 shared helper 或在 writer 内复制路径解析逻辑。
4. **启动跑 + 5 分钟周期跑 reconcile**（D8）：phase 1 处理 server crash 期间未消化的 pending；phase 2 扫描 task vs file revision 漂移并 re-enqueue；phase 3 输出 metrics（pending_count / drift_reenqueued / duration_ms / oldest_pending_lag）。**per-row catch 错误隔离**：单 file 异常不阻塞全扫。
5. **失败语义**：5 次重试后标 outbox row `status=failed` + 写 structured log（consult C1 决策，**不**扩 EventJournal canonical types）；不直接 ops alert（Console 后续做面板订阅 outbox 表）。
6. **archive 路径切换**沿用 `resolveStatePath`，不引入额外 audit log（`task_archived` event 已兜底）。

完整设计大纲：`docs/03_开发计划/ccb-plan/2026-05-09-projection-outbox-worker-design.md`。

### Consult resolution（2026-05-10）

predecessor batch slice 2 留的 Q1-Q5 由 codex consult job_297bb0467afa 解答；用户决策 A1+B1+C1：

| Q | 答复 | 决策来源 |
|---|---|---|
| Q1 | A · 复用 state-projection Document join 路径，不加 Task.documentPath | codex 推荐 + user A1 |
| Q2 | **修订**：caller-owned tx + helper（plan review R1 P1）；revision 推进在 caller 语义层做（不盲拦截）。原 A1 "扩 wrapper API" 因 primitiveExecutor 当前无 tx 注入能力被改为 helper 模式 | user A1 → caller-owned tx |
| Q3 | outbox row 即 audit；不写 EventJournal | codex 默认 + user C1 |
| Q4 | 5 分钟周期落地 + metrics（实测 dev.db 246 docs / 49ms / 0.20ms 一个 doc，量级低） | codex 推荐 |
| Q5 | 不加 projectId 列；row-level retry 隔离 | codex 推荐 |

raw task writes 覆盖（sprint.routes / task.routes epic cancel / scheduler epic-lifecycle）属 master roadmap E1.5 primitive-wrapper-rollout 范围（user B1），本 ADR 范围不覆盖。

## Consequences

正向：
- 关闭 ADR-0013 §5 的实施缺口；hierarchy 模型上线后 epic / subtask 高频写场景的 state file 自动同步
- DB 仍是 SoT，state file 损坏不影响 read；worker 挂死有 reconcile 兜底
- `idempotencyKey UNIQUE` 拒绝重复 enqueue；worker 重启不丢 pending 历史

负向：
- enqueue 由 caller 在自己 `prisma.$transaction` 内调 `enqueueProjectionOutbox` helper（B 决策）；caller 漏写或绕过 primitive wrapper 的 raw 写（如 raw `prisma.task.update`）会绕过 outbox（已知风险）。本 ADR 范围内**不覆盖** raw writes（sprint.routes / task.routes epic cancel / scheduler epic-lifecycle handler 等），归 master roadmap E1.5 primitive-wrapper-rollout epic 集中处理（user B1 决策）；reconcile 周期会兜底 drift
- SQLite 单进程无 leader election，console 多实例部署需重设计（v2，Postgres 切换时同步处理）
- 周期 reconcile 在 当前 dev.db 实测规模（343 tasks / 246 state docs，两 project 各 180+163）每 5 分钟全扫一次：只读 IO 49ms / 0.20ms 一个 doc，量级低，先按 5 分钟落地 + metrics 监控，后续按 oldest_pending_lag_seconds / drift_reenqueued / duration_ms 等指标调优

## Alternatives considered

- **方案 A · 同步写**：每次 mutation 同步写 state file（旧 console v0.x 行为）。问题：写文件失败会回滚 DB tx，把"投影问题"传染到业务路径，违反 SoT 原则。
- **方案 B · 全文件 watcher 反向**：只靠 file watcher + reconcile，无 outbox。问题：crash window / race / 高频写下 reconcile 跟不上；ADR-0013 §5 已 R3 拒此方案。
- **方案 C · Redis/BullMQ 队列**：上 BullMQ。问题：console 单实例部署不需要；引入 redis 依赖与运维负担；先做 D1 单进程版，水平扩展时再切（YAGNI）。

## Migration

- 无需 schema migration（`ProjectionOutbox` 表已存在）
- 现有 state file 由 reconcile phase 2 在 worker 启动时按需 re-enqueue 修齐
- 若 enqueue 全量回灌（一次性把所有 task 当前 revision 入 outbox）需额外脚本 — 暂不强制，reconcile 漂移检测会渐进修齐

## References

- `docs/03_开发计划/ccb-plan/2026-05-09-projection-outbox-worker-design.md` — 完整设计大纲
- `docs/03_开发计划/ccb-plan/2026-05-09-task-hierarchy-three-tier-model-技术设计.md` §5 — 上游协议
- `docs/.ccb/decisions/ADR-0012-task-projection-consistency.md` — file→DB 上半场
- `docs/.ccb/decisions/ADR-0013-task-hierarchy-three-tier-model.md` — 引入 hierarchy 与 outbox 表
- `docs/.ccb/specs/active/2026-05-09-task-hierarchy-m2-console-backend.md` — M2-PR4 部分 deferred 项的回执
