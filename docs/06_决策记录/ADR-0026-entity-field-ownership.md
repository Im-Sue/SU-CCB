---
id: ADR-0026
title: Entity Field Ownership v1.0 + Cross-runtime Rule Sharing
status: active
decided_at: 2026-05-22
last_updated: 2026-05-22
decider: 用户（基于 Phase 4 audit + Phase 2b/2b-hotfix 暴露的债务）
reviewer: ccb_codex（rep_967c972f9d9d audit）
codename: entity-field-ownership-v1
related_doc: docs/03_开发计划/ccb-plan/2026-05-21-plugin-sovereignty-roadmap.md
parent_adrs:
  - ADR-0023  # plugin sovereignty 主决策
  - ADR-0024  # plugin primitive runtime
  - ADR-0030  # plugin node paradigm
implements_via:
  - SP-Phase4 实施 spec（4a 内 ADR-0026 lint 实施）
phase: 4
---

# ADR-0026: Entity Field Ownership v1.0 + Cross-runtime Rule Sharing

## Status

Accepted（2026-05-22）。Phase 4 v1.0 收尾必做。

## Context

Phase 0-3 落地后存在多个字段所有权债务：
- schema-ownership lint 暴露 `Requirement.status` 等字段归属不清
- Phase 2b 引入 subtask spec frontmatter 与 task-state 文件层（Phase 3 补救）字段交叉
- Console 仍有活业务写入口（`PATCH /api/tasks` status/progress/blockedReason）违反 plugin sovereignty
- Console TS / plugin ESM 各写一份 subtask 业务规则（规则漂移风险）
- Prisma `@owner(db-owned, projection-only|derived)` 旧语义无法表达 v1.0 plugin canonical 边界

需要正式 ADR 明确：每个字段归谁写 / 谁只读 / 跨 runtime 怎么共享规则。

## Decision

### 决策 1 · Owner taxonomy（4 档）

每个 DB 字段必须标 `owner` 注解，限定为：

| owner | 含义 | 写入路径 |
|---|---|---|
| `plugin-canonical` | plugin 文件是真相源，DB 是投影 | plugin lib（lib/state / lib/subtask / lib/breakdown-draft / lib/requirement-reanalyze）走 lib/runtime |
| `console-projection` | Console indexer 自己派生 | indexer 内部 computation（如 primaryDocumentId / linkedSpecId）|
| `console-internal` | Console own 的 PM 元数据 | Console UI / API 直接写（id / timestamps / userIds / priority / sprintId / storyPoints）|
| `append-only-audit` | append-only 不可变 | plugin journal.jsonl + Console DB EventJournal（仅追加，不允许 update / delete）|

### 决策 2 · Source taxonomy（plugin-canonical 字段来源细分）

| source | 路径 |
|---|---|
| `task-state` | `docs/.ccb/state/<task_id>.md` frontmatter（运行时状态）|
| `subtask-spec` | `docs/.ccb/specs/active/<task_id>.md` frontmatter（execution contract 初态）|
| `breakdown-draft` | `docs/.ccb/drafts/breakdown/<rid>.json`（计划草案）|
| `requirement-md` | requirement md frontmatter（need analysis）|
| `indexer` | Console indexer 自动派生（仅用于 console-projection）|
| `operator` | Console 用户操作（仅用于 console-internal）|

### 决策 3 · Task 字段表

| 字段 | owner | source |
|---|---|---|
| `taskKey / title / kind / requirementId / specSectionId / implementationOwner / dependencies / sourceBreakdownDraft / sourceDraftHash` | plugin-canonical | subtask-spec |
| `status / currentNode / nodeSubstate / runtimeState / progress / blockedReason / lastTransitionId / lastNodeTransitionAt` | plugin-canonical | task-state |
| `reviewStatus / verificationResultJson / reviewFollowupJson` | plugin-canonical | task-state |
| `primaryDocumentId / linkedSpecId / linkedPlanId / linkedTaskDocId / summary` | console-projection | indexer |
| `id / projectId / priority / ownerUserId / assigneeUserId / reviewerUserId / createdBy / updatedBy / sprintId / storyPoints / createdAt / updatedAt` | console-internal | operator |
| **删除** | — | `stateHashProjection / stateRevisionSeen / step / legacyKind / legacyParentHint / migration*` |

### 决策 4 · Requirement 字段表

| 字段 | owner | source |
|---|---|---|
| `title / description / verbatimSource / claudeInterpretation / ambiguities / fidelityDiff / analysisInputHash / analysisStaleAt / currentPlanningStep / currentPlanningStepStartedAt / planDocPath / breakdownDraftPath / rollupProgress / rollupStatus / status` | plugin-canonical | requirement-md |
| `id / projectId / source / outputMode / splitMode / sourceTaskId / createdBy / updatedBy / createdAt / updatedAt` | console-internal | operator |
| `planningAnchorId` | console-internal | operator（仍由 anchor broker 使用，本期不 drop）|
| **删除** | — | `generatedTaskId / planRevision` |

### 决策 5 · Console 写入规则

- Console 只能直写 `console-internal` / `console-projection` 字段
- `plugin-canonical` 字段 Console 必须只读（仅作 projection 渲染）
- `append-only-audit` 字段 Console 可追加但绝不 update / delete
- 任何 PATCH / POST endpoint 修改 `plugin-canonical` 字段 → **lint 拒绝 + CI fail**

### 决策 6 · Cross-runtime Rule Sharing（解决规则漂移）

**YAML schema 作 declarative source-of-truth**，构建时**生成** TS + ESM validator：

```
references/kernel/schemas/<name>.schema.yaml   ← single source of truth
  ↓ 构建期 generate
lib/<name>/generated-validator.mjs              ← plugin ESM runtime 用
apps/ccb-console/server/src/generated/<name>-validator.ts  ← Console TS runtime 用
```

工具选型由 4a 实施时定（zod / valibot / 自实现 generator）。

**禁止**：Console TS / plugin ESM 手写两套业务规则（schema-validator-hotfix 引入的 `business-rules-utils` 模式只是过渡，最终目标是 generate）。

### 决策 7 · Lint / CI

- `pnpm run lint:schema-ownership` 规则升级：
  - 检查 Prisma schema 每个字段必须有 `@owner` 注解
  - 检查 Console route handler 不能改 `plugin-canonical` 字段
  - 检查 plugin lib 不能改 `console-internal` 字段
- CI 必须 fail-on-violation（PR 不让 merge）

### 决策 8 · Migration Policy

按用户拍板"全新接入"（与父需求 §1 一致）：
- v1.0 发布前 **完全清空 Console SQLite**（含 Task / Requirement / EventJournal / TaskRun / NodeRun / Checkpoint 所有表）
- 例外：`Project` / `ProjectSettings` 属于 console-internal 用户接入元数据，记录"用户接入了哪些项目"及其设置，不纳入 clean start 清空范围
- Prisma migration 一次性删除所有 deprecated 字段（破坏性）
- 重新跑 indexer 投影建表
- 用户已有 docs/.ccb/ 文件直接被新 indexer 投影

不做：渐进式 deprecate / data migration script / 保留 historical events。

## 非目标（明确不做）

- 不做 multi-tenancy field 权限管理（v2+）
- 不做字段加密 / 访问控制（v2+）
- 不做 dynamic owner annotation（编译期决定，运行时不可改）

## 替代方案

| 方案 | 拒绝原因 |
|---|---|
| 维持现有 `@owner(db-owned, projection-only)` 旧语义 | 不能表达 plugin canonical / Console internal 边界 |
| Console TS / plugin ESM 各写业务规则 | 规则漂移已成实际问题（Phase 2b/2b-hotfix 验证）|
| 渐进 deprecate 字段 | 跟"全新接入"父需求不一致 + Migration 复杂度高 |

## 风险

| 风险 | 缓解 |
|---|---|
| YAML → TS+ESM generator 工程量大 | 4a 选型评估，必要时 fallback 到 Console import plugin ESM（同 Node runtime）|
| Console 清空 SQLite 丢失测试数据 | v1.0 还没真发布，dev.db 仅测试数据，可接受 |
| `@owner` 注解漏标 | lint fail-on-missing |
| `planningAnchorId` 字段需要 anchor broker 使用 | 本期不 drop，留 v1.x 决定 |

## 关联

- 父需求：`docs/01_架构设计/ccb-plan/2026-05-17-v1.0-plugin-sovereignty.md`
- 路线图：`docs/03_开发计划/ccb-plan/2026-05-21-plugin-sovereignty-roadmap.md`
- 触发 audit：codex `rep_967c972f9d9d`
- 父 ADR：0023 / 0024 / 0030
- 关联 ADR：ADR-0027（EventJournal v1.0）
- 实施：Phase 4 spec（4a 优先级）
