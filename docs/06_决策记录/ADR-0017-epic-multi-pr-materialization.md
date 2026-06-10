---
id: ADR-0017
title: ADR-0013 Addendum - Epic Multi-PR Materialization
status: active
decided_at: 2026-05-13
decider: Claude
reviewer: ccb_codex
related_epic: epic-multi-pr-v0.6
related_tasks: []
supersedes: null
deprecated_in: null
removed_in: null
grace_window: null
revision: v2 · post-RFC-alignment
related: [ADR-0010, ADR-0011, ADR-0013 (parent ADR), ADR-0014, ADR-0018 (task-anchor-runtime · v2 alignment 派生)]
consult_evidence:
  round_1: "job_4cd1140330bc (codex, status: needs-refine-before-active)"
  round_2: "job_53fada2f90d6 (codex, pending_round_3: 空)"
rfc_ref: docs/01_架构设计/ccb-plan/2026-05-13-e17-epic-multi-pr-alignment-rfc.md
impacted_components: [apps-ccb-console-server, apps-ccb-console-web, claude-plugin-distribution, kernel-references]
---

# ADR-0017: ADR-0013 Addendum — Epic Multi-PR Materialization

## Status

Active（2026-05-13，post-RFC v2 alignment + codex round 1-2 consult 收敛）。

v1 (2026-05-12 proposed) carrier 定义为 `kind=subtask + state=epic_split_pending`，需要 materialize 阶段做 "subtask → epic 提升"。**v2 (2026-05-13)** 因 ADR-0018 task-anchor-runtime 上线后 Anchor API 强校验 `kind === "epic"`，A1 改为**立项时直接建 `kind=epic` carrier**，消除 promotion 反模式，与 ADR-0018 决策 1 零冲突。详 §A5 alignment notes。

## Context

ADR-0013 v0.5 落地三层任务模型（Requirement / Epic / SubTask），但 Epic + 多 PR 路径有 4 块设计未闭合：

1. SubTask 怎么从 task_breakdown 拆分结果落入 DB（"task_breakdown_adapter" 在 M2 spec 标 deferred）
2. 用户怎么审查 AI 拆分结果再确认入库（人在回路）
3. SubTask 怎么继承 Epic plan 产物（linkedSpecId + specSectionId 字段已留好，没规范使用方式）
4. Epic.epicStatus 怎么从 SubTask 状态变更自动推进（progress-aggregation.ts read-only，没 writer）

E17 task-anchor-runtime 上线后 anchor 绑定 epic 的硬约束驱动 A1 重写。本 ADR v2 给 4 块缺口的规范，CCB 上游零改动。

## Decision

### A1 · Planning Carrier · kind=epic from project start

Epic Multi-PR 立项时**直接创建 Planning Carrier**（不再 subtask → epic 提升）：

- `Task.kind = epic`
- `Task.materializationState = epic_split_pending`（v0.6 新增字段）
- `Task.epicStatus = planning`
- `Task.parentEpicId = null`
- `Task.requirementId = <source Requirement.id>`
- `Task.currentNode ∈ {requirement_analysis, technical_design, task_breakdown}`（carrier 可启动 `/ccb:su-flow` 走拆分草案 R 路径）

Carrier 天然作为 ADR-0018 的 Epic anchor 绑定对象。`AnchorStartStrip` / `POST /api/epics/:epicId/anchor/start` 对 carrier 直接可见 / 可启动，无需 API 泛化。

`materialize-as-epic` API 在 `prisma.$transaction` 内执行：

1. **校验 carrier 前置条件**：`kind=epic`、`materializationState=epic_split_pending`、`linkedSpecId=null` 或可被本次覆盖、`draft.status=approved`、`expectedDraftHash` 匹配
2. **创建 N 个 child SubTask**：`kind=subtask`、`parentEpicId=carrier.id`、`linkedSpecId=<Epic spec 路径>`、`specSectionId=<draft.subtasks[].section_id>`、`currentNode=dispatch`
3. **推进 carrier**：`materializationState=materialized`、`linkedSpecId=<新生成的 Epic spec 路径>`、`progress=0`
4. **emit `epic_materialized` event**（envelope 含 `anchor_id` / `epic_task_id` columns；payload 含 `carrier_task_id`、`subtask_count`、`epic_spec_path`、`draft_hash`；详 §A5）

**所有 child SubTask 共享父 Epic anchor，禁止独立 anchor**（ADR-0018 决策 1 派生硬约束）。

如果 carrier 有 busy anchor 绑定，API 返回 409，**不允许** API 自动停止 anchor（避免掩盖 AI session 仍在产草案的竞态）。用户需先经 Anchor stop-and-append / archiving 路径释放 anchor。

### A2 · Breakdown Draft Artifact

Materialization 前，Epic + SubTask 拆分输出 **canonical artifact 是主 Console workspace 文件**（不在 DB）：

```
<project.localPath>/docs/.ccb/drafts/breakdown/<carrierTaskKey>.json
```

Schema 版本：`breakdown-draft-v0.1`。完整字段定义见 `references/kernel/breakdown-draft-schema.yaml`。

**写入路径硬约束**：仅经 `POST /api/tasks/:taskId/breakdown-draft` Console API；禁止 anchor 内 ccb_claude 直接写 anchor 本地 fs（ADR-0018 决策 5 派生）。

**Lifecycle**：

```
draft → reviewing → approved → consumed
draft → cancelled
reviewing → cancelled
```

- approved 后 `materialize-as-epic` 消费 → 移到 `.processed/<carrierTaskKey>-<hash>-<timestamp>.json`（**不是**改 JSON status；详 §A6）
- cancelled draft 保留 7 天 → cron auto-cleanup
- `.processed/` 保留 30 天或随项目归档（不随 carrier archive 立即删，用于追责）

**Materialization 必须校验 `expectedDraftHash`**（sha256 of canonical JSON）；不匹配返回 409。

### A3 · Plan Inheritance

Materialized SubTask **必须**：

- `currentNode = dispatch`（不重跑 requirement_analysis / technical_design / task_breakdown）
- `linkedSpecId` 指向父 Epic 的 spec 文件路径
- `specSectionId` 等于 `subtask_sections[].section_id`（kernel template epic-spec-v0.5.0）
- **不**复制 Epic spec 内容——只引用

参考 kernel：`su-ccb-claude-plugin/templates/epic-spec-template.md` + `references/kernel/state-schema.yaml:1015-1029`。

### A4 · Epic Aggregate Hook

SubTask 状态变更触发 `rollupEpicStatusFromSubtask(tx, subtaskId)` 同步 helper，**在同一 prisma.$transaction 内执行**。

挂点（与 `rollupRequirementStatusFromTask` 完全对应的位置）：

- `apps/ccb-console/server/src/modules/transitions/transition-consumption.service.ts:297`（transition apply 后）
- `apps/ccb-console/server/src/modules/task/task.routes.ts:308`（PATCH task 状态变更）
- `apps/ccb-console/server/src/modules/task/task.routes.ts:629`（archive 路径）

Helper 必须**复用** `computeEpicAggregation`（progress-aggregation.ts:172），不重新发明状态机。Epic 状态语义：

```
任何非 cancelled child 到 dispatch+ → delivering
所有非 cancelled child archive 且至少 1 child delivered → delivered
所有 child cancelled 或用户显式 cancel → cancelled
```

Rollup 完成后立即调 `rollupRequirementStatusFromTask(tx, epicId)`，保持现有 requirement 状态同步链。

### A5 · E17 task-anchor-runtime Alignment

本 ADR v2 wording 来自 RFC `2026-05-13-e17-epic-multi-pr-alignment-rfc.md` v2 + codex consult round 1 (job_4cd1140330bc) + round 2 (job_53fada2f90d6)。E17 引入的契约对本 ADR 影响如下：

**EventJournal anchor 维度**：`emit_event` envelope 必须含 `anchor_id?` / `epic_task_id?`（nullable + optional），`emitEventInTransaction` service 必须写 `EventJournal.anchorId / epicTaskId` columns（不仅 payload）。`epic_materialized` payload **不再复制** `anchorId`；runtime anchor 维度以 envelope/columns 为唯一真相源，payload 仅保留业务事实（`carrier_task_id` / `subtask_count` / `epic_spec_path` / `draft_hash`）。详 RFC §F2。

**跨 anchor 通信**：breakdown-draft 写入 + materialize 触发都通过主 Console API + broker 路由（ADR-0018 决策 5），不直接走 anchor 本地 fs。

**Carrier anchor 绑定**：carrier=kind=epic 天然吻合 ADR-0018 决策 1。`AnchorStartStrip` 现有 `task.kind === "epic"` 可见性条件**不需要改**。`anchor.routes.ts:127` `kind === "epic"` 强校验**不需要改**。

**SubTask anchor**：materialize 创建的 child SubTask **禁止独立 anchor**（ADR-0018 决策 1）；共享父 Epic anchor 内串行执行。

### A6 · Materialize Crash 应对 / Orphan Spec Cleanup

`materialize-as-epic` API 顺序保留 **"先写 spec 文件 → 再 DB transaction"**（不调换；DB-first 会产生 DB 已 materialized 但 spec 文件缺失的更坏状态）：

- spec 先写到最终路径 `<Epic spec 路径>`
- DB transaction 失败时 **best-effort rm** spec 文件
- 成功后将 consumed draft 移到 `.processed/<carrierTaskKey>-<hash>-<timestamp>.json`
- **启动时 orphan scan**（推荐做但非必须）：扫描 generated spec 文件，若存在 spec 但无对应 `epic_materialized` event 或 carrier `linkedSpecId` 引用，报告 orphan + 标 carrier `materializationState=cleanup_required`
- idempotency 仍以 `(carrierId, expectedDraftHash)` 为准；重复 materialize 同 hash 返回既有 result

**Acceptance**：注入 DB transaction failure 后 spec 被删除或产生 orphan cleanup report；成功后 draft 移入 `.processed/`；重复 materialize 同 hash 返回既有 result；spec 写失败时 DB 不变。

### A7 · 幽灵 Epic Cleanup（B 路径自带风险）

立项 Epic 多 PR 后立即产生 kind=epic carrier。如果用户不 materialize 一直挂着，可能形成"幽灵 Epic"：

- `epic_split_pending` carrier **48h 无 draft 或无更新** → UI 标"草案待处理"提醒
- **7 天无进展** → 标 stale，TaskDetail / Requirements 显示 cleanup CTA
- **14 天仍无进展** → 进入"建议归档/取消"状态（**不自动删除**，避免误删用户意图）
- **用户主动 abort**：TaskDetail banner + BreakdownReviewPage 提供"放弃 Epic 多 PR"入口；尚未 materialized 时取消 draft + 设 `materializationState=cancelled`，按现有 Task status 语义归档或取消 carrier
- **/anchors 面板**：显示已启动 anchor 的 carrier draft 状态 `draft pending / reviewing / approved`；未启动 anchor 的幽灵 carrier 不占 anchor slot
- **并发规则**：
  - anchor `busy` 时 abort 返回 409，要求先 stop/cancel
  - `idle_dirty` 可取消 draft，但 anchor cleanup 走 E17 archiving 路径
  - anchor `archiving / orphaned` 时禁止 materialize，先恢复或清理 anchor

## Consequences

### Positive

- Epic 多 PR 路径打通，立项 dialog disabled 选项启用
- CCB 上游零改动；ADR-0018 task-anchor-runtime 零妥协
- 消除 "subtask → epic 提升" promotion 反模式
- ADR-0013 三层模型完成度从 v0.5"骨架"到 v0.6"可用"
- carrier 天然走 anchor，runtime 承载零特例

### Negative

- 已有的 untracked PR0-PR5 partial code 部分假设 `kind=subtask` carrier；commit 前需重写测试和 service path
- 草案文件和 DB 不能天然原子；A6 orphan scan 是 best-effort
- breakdown-draft 格式由本 ADR 锁定为 JSON；后续切 YAML/Protobuf 需新 ADR
- B 路径下立项 Epic 多 PR 立即产生 carrier，需 A7 cleanup 策略避免"幽灵 Epic"

### Neutral

- AI session 拆分准确度由 Claude/Codex 自身决定；ADR 不限定 AI 拆分质量
- S 路径（手动拆分）和 R 路径共享同一 draft + API；任何路径都通过审查页确认

## Alternatives Considered

- **A1 v1 path（subtask carrier + materialize 时 promotion）**：被否（本 ADR v2）。与 ADR-0018 anchor 绑定 epic 抽象冲突，R 路径运行时无承载
- **Anchor API 泛化接受 subtask carrier（Option A）**：被否。临时 hack 容易 ossify，违 ADR-0018 决策 1 抽象
- **Server NodeExecutor 自动跑 fixed_actions**：被否（继承 v1）。违反"AI session 当 NodeExecutor"哲学
- **草案存 epic spec sections 文件**：被否（继承 v1）。spec 是 approved 目标形态
- **草案用 .md 复用 kernel template**：被否（继承 v1）。审查页频繁 GET/PUT + ETag，JSON 工程成本更低
- **EventJournal payload 直接放 anchorId 而非 envelope**：被否（round 2 拍板）。envelope/columns 是 runtime anchor 维度的唯一真相源，payload 不重复

## Verification

- `test -f docs/.ccb/decisions/ADR-0017-epic-multi-pr-materialization.md` + status: active
- Prisma schema 含 `Requirement.splitMode` + `Task.materializationState`
- migration `20260513_epic_multi_pr_foundation` 文件存在并能应用
- EventJournal types 含 `epic_materialized` + envelope schema 含 `anchor_id` / `epic_task_id`
- `references/kernel/breakdown-draft-schema.yaml` 存在
- end-to-end：立项 dialog 选 Epic + 多 PR → carrier 直接为 `kind=epic + state=epic_split_pending` → 启动 Anchor → /ccb:su-flow 产草案 → 审查页 approve → materialize → DB N SubTask + linkedSpecId/specSectionId 正确 → epic_materialized event 写 columns

## Related

- 需求：`docs/.ccb/requirements/active/2026-05-12-epic-multi-pr-长期产品形态-e8d142.md`
- Parent ADR：ADR-0013 三层模型
- Driver ADR：ADR-0018 task-anchor-runtime
- Alignment RFC：`docs/01_架构设计/ccb-plan/2026-05-13-e17-epic-multi-pr-alignment-rfc.md` v2
- kernel template：`su-ccb-claude-plugin/templates/epic-spec-template.md`
- kernel schema：`references/kernel/state-schema.yaml:295-325` + `:1015-1029`
- v0.5 已交付基础设施：anchor pool + ccbd client + decision timeline + user_intent
- 协商记录：本会话 Epic Multi-PR round 1-2 (v1) + RFC alignment round 1-2 (v2)
