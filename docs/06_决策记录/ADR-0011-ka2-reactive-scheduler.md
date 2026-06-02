---
id: ADR-0011
title: KA-2 ReactiveScheduler — v0.4 second-wave 终态决策
status: active
decided_at: 2026-05-06
decider: Claude
reviewer: ccb_codex
related_epic: e14-ka2-reactive-scheduler
related_tasks:
  - e14-t0-reactive-scheduler-contract-rfc
  - e14-t1-reactive-scheduler-core-engine
  - e14-t2-policy-profile-handlers
deprecated_in: null
removed_in: null
grace_window: null
impacted_components:
  - apps-ccb-console-server
  - claude-plugin-distribution
  - kernel-references
---

# ADR-0011: KA-2 ReactiveScheduler — v0.4 second-wave 终态决策

## Status

Accepted.

## Context

v0.4 northstar §3.7 把 ReactiveScheduler 列为 v0.4 second-wave 终态：scheduler 必须通过 kernel-level event-store contract 读取事件、统一 `/ccb:su-flow` 三档调度差异、解锁 autonomous-batch 跨节点自主推进。

ADR-0010 已把 `/ccb:su-flow` 落地为 SingleTaskScheduler thin facade（仅 plan 三节点；`autonomous-batch` 字段预留 `not_implemented_in_v0.4_v1`）。E6 已交付 event-store contract（9 event types + envelope + dedupe + CAS + audit）+ K0 transition wrapper + K1 transition-consumption-attempts endpoint。

E14 epic 把 thin facade 升级为完整 ReactiveScheduler：
- E14-T0（archived 8.29 R4）：[ReactiveScheduler Contract RFC](../../../docs/01_架构设计/ccb-plan/2026-05-06-reactive-scheduler-contract-rfc.md) — 297 行，锁定 contract
- E14-T1（archived 8.6 R4）：scheduler 核心引擎（cursor / lock / event-router / parallel_join 检测），4 round implementation refinement
- E14-T2（archived 8.3 R4）：policy_profile handlers（interactive-single + autonomous-batch）+ transition-proposal 4 event 扩展 + apply 路径闭合 + capability gate fail-closed + manifest fail-fast，4 round refinement

本 ADR 锁定 9 项关键决策，作为 ReactiveScheduler 的协议级真相源。RFC 是 contract 形态，T1+T2 archived state 是 implementation 事实，本 ADR 是决策摘要 + 替代方案档案。

## Decision

### 决策 1 · policy_profile 持久 2 档 + SingleTask 仅入口 alias normalize

`state-schema.yaml` `enum.policy_profile` 仅 `interactive-single` / `autonomous-batch` 两档。`SingleTask` 不持久化为第三 enum；scheduler 入口 normalize（CLI / SKILL）→ `interactive-single`，telemetry/log 标 `entry_alias=SingleTask` 仅作迁移期统计便利。

### 决策 2 · scheduler 不直接 mutate task_state

scheduler 仅写自身私有 cursor 表（`SchedulerConsumerCursor` + `SchedulerLock`）。`task_state` 字段（`runtimeState` / `blocker_type` 等）由既有 hook / primitive_executor / transition consumer 链路在事件触发时写好；scheduler 仅观察。私有 `pauseReason` / `pauseDetail` / `lastAttempted*` 也只在 cursor 表，不进 state-schema。

### 决策 3 · K1 endpoint 路径与 contract 锁定

`POST /api/event-journal/events/:eventId/transition-consumption-attempts`（不写历史草案路径 `/api/transitions/apply`）。Body: `{mode: 'apply'|'dry_run', requestSource: 'api_direct', idempotencyKey?: string max 200}`。Response result enum: `dry_run_eligible` / `dry_run_ineligible` / `applied` / `already_applied` / `apply_ineligible`。

scheduler 仅对 RFC 附录 A 标注 K1 propose 的 event_type 调用该 endpoint。R4 终态：`codex_receipt_ready` / `codex_picked_up` / `verification_finished` 三类已闭合 propose + apply；`user_arbitration_submitted` 保持 propose-only；`session_resumed` 不映射 transition（仅触发 clearPause if recoverable）。

### 决策 4 · capability gate fail-closed

scheduler 内部 `capability-resolver.ts` 默认认为 runtime capability 不可用（`runtimeCapabilities ?? []` 显式空集合）。governance_critical capability 在运行时缺失必触发 escalate，不再因为没传 runtime layer 就默认 proceed。RFC §5 决策伪代码 5 路径合并去重（`required_capabilities.must_have[].capability_id` + `optional_capabilities.nice_to_have[].capability_id` + `fixed_actions.steps[*].capability_id` + `subflows[*].steps[*].capability_id` + `subflows[*].branches[*].steps[*].capability_id`）+ `degradation.forbidden_policies` 比较当前 policy_profile + criticality 决策树。

### 决策 5 · apply 路径 prisma.$transaction audit-first + partial unique index

`transition-consumption.service.ts` apply 路径在同一 prisma.$transaction 内先 create EventConsumption audit row 再 update Task；任一失败 transaction rollback。Prisma schema EventConsumption 表加 partial unique index（`ON (eventId, transitionId, mode) WHERE mode='apply' AND result='applied'`）；并发重复 apply 由 P2002 冲突走 `already_applied` 分支。CAS 冲突时 emit `state_write_conflict` event（与 RFC 9 event types 一致）。

### 决策 6 · pauseReason → recoverable_via_event 静态映射

`PAUSE_REASON_RECOVERY_EVENTS` 常量定义（`cursor.service.ts` L36-48），与代码事实严格对齐：

| pauseReason | recoverable via |
|---|---|
| `transient_error_exceeded` | `[session_resumed, user_arbitration_submitted]` |
| `governance_critical_escalate` | `[session_resumed, user_arbitration_submitted]` |
| `manifest_unavailable` | `[session_resumed, user_arbitration_submitted]` |
| `consult_in_progress` | `[user_arbitration_submitted]` |
| `state_write_conflict_requires_escalation` | `[user_arbitration_submitted]` |
| `dirty_state` | `[session_resumed]` |
| `user_arbitration_pending` | `[session_resumed]` |
| `apply_ineligible_*`（前缀通配） | `[session_resumed, user_arbitration_submitted]` |
| `parallel_join_not_supported` | `[]`（永不可恢复，等 E15 / KA-1b 完成） |
| `interactive_handoff` | `[]`（永不可恢复，用户显式调 `/ccb:su-dispatch`） |

`clearPause({ advanceTo })` 推进 cursor 跳过 pause-causing event 避免回放卡死（cursor 同步写 `lastAttemptedEventId` / `lastAttemptedEmittedAt`）。

### 决策 7 · global.yaml + node manifest fail-fast schema validate

scheduler 启动时加载 `references/kernel/capabilities/global.yaml`，缺失 `criticality` / `degradation` 等必填字段 → registerScheduler throw startup error（不预置默认值）。consume loop 按 task currentNode 加载 `references/kernel/nodes/<currentNode>.node.yaml`；结构错（仅含 schema_version + node_id 但其他必填字段缺）→ scheduler 写 cursor.pauseReason=`manifest_unavailable` + autonomous resolver 拒绝 proceed。

### 决策 8 · 单实例 SQLite advisory lock

scheduler 启动用 SQLite `BEGIN IMMEDIATE` + `SchedulerLock` 单行表（`holderId` / `holderPid` / `acquiredAt` / `heartbeatAt`）；进程每 15s 更新 heartbeat；守护脚本（`scripts/scheduler-watchdog.sh`）每 30s 检测 ≥60s 未更新心跳的死 holder 强制清行；冲突退出码 `scheduler_already_running`，`schedulerStartupState.result.status='lock_busy'` 携带占锁实例的 holderId/holderPid。multi-instance leader election / 跨主机锁 / 切换到 PostgreSQL 留 v0.5+ 候选。

### 决策 9 · 依赖准入分级（替代「不引入新外部依赖」绝对禁令）

| 层级 | 例子 | 准入策略 |
|---|---|---|
| 核心框架 dep | fastify / prisma / vitest / react / zod | 不替换 / 不大版本升级，需 RFC + ADR |
| 中型工具 dep | yaml / dayjs / nanoid / pino / lodash | 按需引入，code review 评估必要性即可 |
| 小型 polyfill / 单函数包 / type 包 | — | 自由 |

E14-T2 R3/R4 期间 codex 选择保留手写 yaml loader + zod 兜底（决议 7），未引入 yaml 库；属决策 9 中的「中型工具 dep 按需」自评结果，可后续评估是否切换。绝对禁令的旧表述废弃，master roadmap §4 仍保留「核心框架 dep 大版本升级需 RFC」原文。

## Consequences

- v0.4 second-wave 工程主线核心目标达成：`/ccb:su-flow` 不再仅 plan facade，autonomous-batch 跨节点自主推进解锁
- scheduler 与 task_state 解耦：未来扩展 handler / event mapping 不需动 6 canonical
- pauseReason 解除策略静态化：T2+ 实施可在已有 map 上扩展，新增 pauseReason 必须明示 recoverable_via_event 列表
- apply 路径原子幂等闭合：并发重复 apply / audit 失败回滚 / CAS 冲突 emit state_write_conflict 三条路径完整，K1 contract 在 v0.4 second-wave 不再有"半 apply"风险
- 依赖准入治理升级：中型工具 dep 按需进入降低 codex 实施侧的次优选择压力
- T7 完成后北极星 §3.7 状态行将从 pending 转为 delivered

## Alternatives Considered

- **autonomous-batch 推迟到 v0.5**：被否。北极星明确 v0.4 second-wave 完整收敛三档；autonomous-batch 是核心解锁价值。governance_critical escalate + advisory lock + manifest fail-fast 三层兜底已足够 production safety
- **multi-instance leader election（v0.4 second-wave 即引入）**：被否。单实例假设在 SU-CCB 个人项目场景充分；多实例锁 / 跨主机协调引入 leader election 复杂度（zk / etcd / pg_advisory）超出 master roadmap §4 不做边界。留 v0.5+ 候选
- **切换到 PostgreSQL 以原生 advisory lock**：被否。Console 当前 SQLite + Prisma 工作良好；切 PG 涉及 plugin distribution 全链路调整，超出 v0.4 second-wave 范围
- **scheduler 直接 mutate task_state（绕过 K1）**：被否。违反 RFC §3 数据边界；任何 task_state 写都应经 K1 / hook / primitive 链路，否则 audit / CAS / event-store contract 失效
- **pauseReason 由用户手动分类**：被否。静态映射在编译期约束更稳；用户视角通过 SKILL.md 暂停/恢复指南映射可见提示词
- **引入 yaml 库（如 `yaml` package）做 fail-fast schema validate**：T2 R4 评估保留手写 loader + zod 兜底（决议 9 中型工具 dep 自评不引入）。后续评估窗口仍开放——非阻塞决策

## Related References

- RFC: `docs/01_架构设计/ccb-plan/2026-05-06-reactive-scheduler-contract-rfc.md`（T0 archive 8.29 R4，297 行）
- T0 state report: `docs/.ccb/state/2026-05-06-e14-t0-reactive-scheduler-contract-rfc.md`
- T1 state report: `docs/.ccb/state/2026-05-06-e14-t1-reactive-scheduler-core-engine.md`（核心引擎 8.6 R4）
- T2 state report: `docs/.ccb/state/2026-05-06-e14-t2-policy-profile-handlers.md`（handlers + transition extensions 8.3 R4）
- E14 epic spec: `docs/.ccb/specs/active/2026-05-04-e14-ka2-reactive-scheduler.md`（plan review 8.57 R3）
- 上游 ADR：ADR-0010 KA-10 /ccb:su-flow facade（thin facade 起点）
- 实施 commits: 9d6c209 → 9fac03c → 4329fea → db34152（T1）；c6f72db → 521884e → 2611ef4 → 74472dd（T2）
- v0.4 北极星 §3.5 + §3.7：policy_profile 三档收敛 + ReactiveScheduler second-wave
- master roadmap §3 Wave 4 + §7 风险池
