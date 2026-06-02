---
id: ADR-0019
title: Entity-Field Ownership & Sync Direction Protocol
status: active
decided_at: 2026-05-14
activated_at: 2026-05-14
decider: Claude
reviewer: ccb_codex
related_adr: [ADR-0011, ADR-0012, ADR-0013, ADR-0014, ADR-0017]
amends: [ADR-0014]
related_tasks:
  - md-db-drift-treatment-v1（紧急修复 P0/P1 · archived 2026-05-14 commit bb59349）
  - 2026-05-14-md-db-drift-treatment-followups（治理 backlog F1-F6）
  - 2026-05-14-f2-s1-rollup-cancel-status-boundary（dispatch_ready）
  - 2026-05-14-f2-s2-epic-replan-primitive（dispatch_ready）
  - 2026-05-14-f2-s3-materialize-cas-primitive（dispatch_ready）
  - 2026-05-14-f7-primitive-executor-hardening（backlog）
consult_refs:
  - codex round 1-5（紧急修复阶段，5 轮收敛主体方向）
  - codex round 2 follow-up rep_718cdd67aa2d（F2 范围澄清：6→7 处 + primitiveExecutor 空壳定位）
deprecated_in: null
removed_in: null
grace_window: null
impacted_components:
  - apps-ccb-console-server
  - docs/.ccb/requirements
  - docs/.ccb/state
  - references/schema-ownership-matrix.yaml
---

# ADR-0019 · Entity-Field Ownership & Sync Direction Protocol

## Status

Active（2026-05-14 紧急修复 P0/P1 落地 + codex round 2 follow-up 澄清 + F2 拆 S1/S2/S3 spec + F7 backlog 立项 后正式生效）

## Context

### 触发事件

2026-05-13 用户在 Console 操作"立项 Epic + 多 PR · AI 辅助拆分"，提示
`Invalid prisma.task.create() invocation: Unique constraint failed on the fields: (projectId, taskKey)`。

5 轮 consult 与一次完整 Phase 1 全量盘点（schema / write 入口 / sync 组件 / skills 消费者 / docs 目录归属）后定位为：**md⇄DB 同步是单向漂移的，且影响面是全系统级治理债，不是单点 bug**。

### 关键事实

1. **ADR 内部已有混合语义**（不是单纯"代码违反 ADR"）：
   - ADR-0014 / ADR-0013 §5 宣告 "DB 是 SoT, state file = async outbox/projection"
   - ADR-0012 同时把 state frontmatter 字段视为 "task projection 输入"，filename slug 主优先
   - ADR-0014 自身也承认 `state-projection.ts` 是 file→DB 反向路径
   - **结果**：Task 状态字段实际形成 "DB ⇄ file 双向" 模式，无单一 SoT 协议

2. **Requirement 是 ADR 空白**：ADR-0013 D8 只确立 "独立 Requirement 表"，未声明真源方向；`createRequirementMdFirst` 注释 "md 是真源" 是历史遗留，非 ADR 决策

3. **多写者振荡风险**（dev.db 实测漂移已发生，振荡机制可触发）：
   - `Requirement.status`: cancel route + status-rollup + scan upsert（3 写者）
   - `Task.runtimeState`: transition-consumption + state-projection（2 写者，dual-direction）
   - `Task.epicStatus`: cancel route + epic-lifecycle handler（2 写者，**全 raw**）

4. **raw write 漏洞 7 处**（ADR-0014 L61-72 已知 "E1.5 延后清单"，至今未完成 · 2026-05-14 codex round 2 follow-up 重新盘点）：
   - `task.routes.ts:1047` `/api/epics/:id/cancel`
   - `task.routes.ts:1061` `/api/requirements/:id/cancel`
   - `epic-lifecycle.handler.ts:78-142` replan（`tx.task.create` + `tx.task.update` 各一处）
   - `materialize.service.ts:239` CAS lock
   - `materialize.service.ts:562` CAS rollback
   - `epic-status-rollup.ts:94` epicStatus
   - `requirement-status-rollup.ts:99` requirement.status（codex round 2 新发现）

   ~~原列 `transition-consumption.service.ts:280` 已撤销~~：codex round 2 实测确认该处外层 `primitive + tx + audit row + CAS updateMany + outbox` 完整合规。`primitiveExecutor` 当前是 13 行空壳（仅校验入参后 `return run()`，无审计落盘、无幂等登记）是**全仓性基建问题**，治理由独立 spec `2026-05-14-f7-primitive-executor-hardening` 承担，不在 7 处 raw write 范围。

5. **skills 不读 requirement md** — Phase 1 grep 全 SKILL.md + 节点 manifest 确认。skills 真源是 `docs/.ccb/state/<task>.md`（CAS + revision）

### 影响面

dev.db 实测：33 条 Requirement 当前 `generatedTaskId=null` 但有 Task 反链——意味着 33 个用户在 Console 看到的"立项"按钮都可能再次触发 P2002，且 Requirement.status 显示与实际 Task 状态不一致。

## Decision

### 五项核心原则

**P1 · 真源唯一性 (Single SoT per field)**

每个字段必须有**单一 owner**：要么 DB，要么 file。**禁止"两边都是 source"**。

合法的 "source + projection" 不是双源（如 spec 文件是 file-owned source，DB 仅存 spec_hash 是 projection of-hash）。

**P2 · 写入路径强制审计 (Write Path Discipline)**

DB 写入必须满足：
- 包在 `primitiveExecutor.run({...})` 内（提供 audit + idempotency 钩子）
- 后跟 `enqueueProjectionOutbox`（如该字段有 file 投影）
- 在 `prisma.$transaction` 内（保证原子性）

**当前 primitiveExecutor 实现状态（2026-05-14）**：当前 `apps/ccb-console/server/src/modules/primitive/primitive-wrapper.ts` 仅 13 行，校验 `primitive + mutationType` 后 `return run()`，**未兑现 audit 落盘 + idempotency 登记**。本 ADR 的"包 primitive 包装"在 F2-S1/S2/S3 阶段仅起"机器可识别边界"作用；真实 audit/idempotency 由 forward-ref spec **F7 · primitiveExecutor 硬化**（`2026-05-14-f7-primitive-executor-hardening`）兑现。F2 完成后 F7 升级 wrapper 内部时 API 兼容，无 source 改动。

**例外**：
- scan / projection 等批处理可用 **job-level primitive/audit**（非每行），由实施 spec 明确白名单
- migration / backfill / reconcile 路径必须显式标记 `repair_mode`，不进入常规 sync 路径
- 已存在但不符合的入口（7 处 raw write，见 Context §4）按 F2-S1/S2/S3 三个 spec 收敛，不立刻硬切

**P3 · sync 方向单一 (One-Way Sync per Field)**

每个字段最多一条常规 sync 方向：
- `db-owned + projection` → 只 DB→file（projection-writer）
- `file-owned + scan-sync` → 只 file→DB（scanProject）
- **禁止两个方向同时存在**（这是振荡根源）

**例外**：reconciler / repair_mode 可反向回填，必须显式标记。

**P4 · owner 由语义决定，不是频率**

owner 选择基于字段语义：
- **状态/标记/关系** → `db-owned`（不论高低频）
- **内容/语言/描述** → `file-owned`（如需离线访问）or `db-only TEXT`（仅 console 显示）
- **跨表派生（rollup）** → `db-derived`（rollup 是唯一写者）

频率只决定**是否需要 outbox 投影到 file**，不决定 owner：
- `db-owned + projection` → 高频改且需离线访问（Task 状态字段）
- `db-only` → 低频或仅 UI 显示（priority / sprintId）

**P5 · 字段归属机器可验证 (Schema Ownership Annotation + Lint)**

在 `prisma/schema.prisma` 字段上加注释：

```prisma
// @owner(db, projection-only)   ← 高频状态，DB 真源 + file 投影
status               String

// @owner(db, derived(rollup))   ← rollup 派生
aggregatedStatus     String

// @owner(file, scan-sync)       ← 内容字段，md 真源
description          String

// @owner(db, db-only)           ← 纯 DB，无文件投影
priority             String
```

**lint/CI 配套**（独立 spec 实施）：
- 扫描 `prisma.<model>.update*` / `tx.<model>.update*` 是否在白名单入口
- 比对 schema 注释与 `references/schema-ownership-matrix.yaml`
- 检测 raw write（无 primitive + 无 outbox）

### Status Semantics（合并自原 ADR-0021 提议）

| 字段 | 定义 | owner |
|---|---|---|
| `Task.runtimeState` | 执行态（running / waiting_user / completed / failed） | `db-owned + projection` |
| `Task.status` | 逻辑视图（active / archived），由 `runtimeState + currentNode` 派生 | `db-derived（display-only）` |
| `Task.epicStatus` | Epic 生命周期（planning / delivering / delivered / cancelled） | `db-owned + projection`（仅 kind=epic） |
| `Task.materializationState` | Epic 物化锁（epic_split_pending / materializing / materialized / cancelled） | `db-only`（无 file 投影） |
| `Requirement.status` | 需求生命周期（draft / analyzed / delivering / delivered / deferred / cancelled） | `db-derived（rollup-only）`，rollup 唯一写者 |

API 返回时 `Task.status` 从 `runtimeState + currentNode` 实时派生（或缓存为 `db-derived` 字段，由 rollup 维护）。

### Requirement md 长期定位

Requirement md **继续生成**（保持用户阅读习惯），但：
- frontmatter **只保留**：`id / title / created`
- **移除**：`status / source / output_mode / split_mode / generated_task_id`
- 文件顶部加 stale 提示："⚠️ 当前状态以 Console 为准"
- scan upsert **永不覆盖** Requirement 的 db-owned 字段

### ADR-0014 修订（amend）

ADR-0014 "DB 是 SoT" 宣告**仅适用于 db-owned 字段**。本 ADR-0019 提供完整字段归属矩阵作为补充协议；ADR-0014 L61-72 的 "E1.5 延后清单" 由独立 "Raw Write Treatment Spec" 收敛。

## 字段归属矩阵

完整矩阵单独维护：[`references/schema-ownership-matrix.yaml`](../../../references/schema-ownership-matrix.yaml)

矩阵包含：实体名 / 字段名 / owner / sync 方向 / 投影机制 / 写入入口白名单 / 备注。

## Consequences

### 正向

- 关闭 ADR-0014 留下的 4 项治理债：raw write 边界 / SoT 适用范围 / Requirement owner / Status 字段语义
- 解决用户 P2002 报错的根因（scan 不再覆盖 Requirement 运行时字段）
- 为后续新增实体提供判定模板（owner 决策树）
- lint/CI 把治理从 "review 时 grep" 升级为 "提交时拦截"

### 负向

- 历史 33 条漂移数据需脚本回填（紧急修复 spec 覆盖）
- 6 处 raw write 治理改造（独立 spec 排期）
- schema 注释与 matrix.yaml 双源维护成本（lint 拦保护）
- ADR-0014 / 0012 需小幅修订或加 forward-reference

## Alternatives considered

- **方案 P 全量 DB SoT（不分字段）**：被 codex round 3-4 实测打脸——`taskKey` 是投影 identity，`projectId_taskKey` 是 Prisma selector，state 文件被 skills 消费，全量 file→DB 单向不可行
- **方案 Q 全量 md SoT**：被 codex round 3 否决——业务写绑文件系统，引入 fs+DB 非事务、并发覆盖、文件锁问题，性能与可靠性损失大
- **方案 R 字段级 SoT 元数据 schema**：本 ADR 是 R 的轻量版（schema 注释 + 外部 yaml 矩阵），不上 schema 元编程
- **CRDT / event-sourced 方案**：codex round 5 评估为 "远超事故半径"，会重写 Console + skills + DB 投影模型，不选

## Open questions（待 codex round 6 确认）

1. `references/schema-ownership-matrix.yaml` 的字段粒度：每个字段一行，还是按 owner 类别分组？
2. lint 规则是 ESLint plugin / 自定义 grep / TypeScript transformer？
3. raw write 治理 spec 的优先级：先治理 6 处现有，还是先加 lint 拦新增？
4. ADR-0012 / ADR-0014 修订是 inline amend 还是单独 amendment ADR？

## Implementation roadmap

| 阶段 | 内容 | 负责 | 阻塞 ADR |
|---|---|---|---|
| 紧急 P0 | scan 不覆盖 Requirement 运行时字段 + 33 条数据回填 | Codex | 否 |
| 紧急 P1 | P2002 → 409 翻译 + cmp3j9k6 task 不一致修正 | Codex | 否 |
| 后续 1 | schema-ownership-matrix.yaml 完整填充 | Claude + Codex | 是 |
| 后续 2 | schema.prisma `@owner` 注释 | Codex | 是 |
| 后续 3 | Raw Write Treatment Spec 起草 + 6 处治理 | Claude + Codex | 是 |
| 后续 4 | lint/CI 规则 | Codex | 是 |

紧急 P0/P1 与本 ADR 写作并行，不互相阻塞。
