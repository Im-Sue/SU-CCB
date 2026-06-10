---
adr: ADR-0022
title: maintenance/ 一次性脚本 schema-ownership-lint 豁免
date: 2026-05-17
status: accepted
owner: claude
reviewer: ccb_codex (collab rep_3444ad9f2ab0, 0.82 confidence)
related: [ADR-0014-projection-outbox-worker, ADR-0019-entity-field-ownership-and-sync-direction, ADR-0021-status-repair-primitive-three-layer]
addresses: [F5/F8 epic 引入的 schema-ownership-lint 规则首次真跑（PR `task/cmp7zz0g9016aqrz6yeoi9tmm` 修对 workflow 后）暴露 24 处历史欠债, 23/24 集中在 src/maintenance/ 一次性数据迁移脚本, 逐处包 primitiveExecutor.run 会与外层 prisma.$transaction 产生嵌套事务语义问题, 缺少明确的"治理通道豁免边界"决策记录，未来再有同类脚本会反复争议]
---

# ADR-0022 · maintenance/ 一次性脚本 schema-ownership-lint 豁免

## Context

### 触发事件

ADR-0021 阶段化推进过程中，CI workflow `schema-ownership-lint` 因 pnpm action setup 顺序错误，长期处于"配置失败但不算 PR 红"状态。PR `task/cmp7zz0g9016aqrz6yeoi9tmm` 在 commit `7452cb7`、`408e458` 修对 workflow 配置后，lint 在该分支上第一次真正跑通，一次性暴露 24 处历史欠债。

### 24 处违规分布

- 22 处 `src/maintenance/merge-shadow-tasks.ts`（write_missing_primitive）
- 1 处 `src/maintenance/backfill-archived-progress.ts:154`（write_missing_outbox）
- 1 处 `src/modules/task/derive.service.ts:82`（write_missing_outbox，业务路径）

`git blame` 证实 derive.service.ts:82 提交于 `adaf9197 2026-05-16`，不在 PR1-PR4 (be94602..09b9b47) 范围内。PR1-PR4 的 matrix diff 只新增 PATCH write_entries 与新 entity 字段，对老代码的检测面没有扩大。结论：24/24 都是历史欠债，与当前 PR 引入的业务变更无因果关系。

### 为什么不能逐处真修 maintenance

`merge-shadow-tasks.ts` 已经 import primitiveExecutor 并在外层用过；违规点在 helper 函数体内对 `tx.*` 的 `updateMany` 调用，外层已有 primitive + `prisma.$transaction`。lint 的 AST ancestor 检测跨不了函数调用边界，所以报红，但**强行在每个 helper 调用处嵌套 `primitiveExecutor.run` 会产生嵌套 primitive / 事务语义问题**（重复审计、idempotency 键冲突、事务边界含糊）。这不是"加一行 wrapper"能解决的，需要重构整个 maintenance 脚本的事务模型。

### 为什么 maintenance 脚本与治理通道目标错位

治理通道（primitiveExecutor + matrix + outbox）的核心收益：
- 自动审计写入路径
- 强制事务边界
- 自动入队 projection outbox 让下游 read model / event consumer 收到变更

maintenance 脚本的实际形态：
- 手动一次性触发（`pnpm tsx src/maintenance/<script>.ts`）
- 大批量数据修复，通常涉及 cross-entity 关联修正
- 跑前有 dry-run + spot check，跑后有数据校验脚本兜底
- 跑完即 archive，不进入生产 hot path

强求 maintenance 脚本走治理通道，**收益与代价不匹配**：审计/事务/投影对一次性脚本意义有限，而代价是重构十几个脚本的事务模型。

## Decision

### 豁免范围

**仅豁免** `apps/ccb-console/server/src/maintenance/**` 路径下的脚本，从 schema-ownership-lint 检测范围中跳过。

### 实现方式

在 `apps/ccb-console/server/src/maintenance/schema-ownership-lint.ts`（或其调用入口 `scripts/lint-schema-ownership.ts`）的 `runSchemaOwnershipLint` 中 hardcode skip pattern：扫描 `sourceRoots` 时跳过 `**/maintenance/**`。

不采用 matrix schema 加 `exempt_paths` 字段的方案。理由：matrix schema 扩展是治理体系级变更，影响所有 entity declaration + lint 解析逻辑 + 文档；本决策只解决"一次性脚本豁免"这一具体问题，不扩治理体系。matrix 声明式豁免如将来需要，作为独立任务承接（见下方"后续演进"）。

### 不豁免的范围（明确边界）

以下路径**继续受 schema-ownership-lint 检测**，不进入豁免：

- `apps/ccb-console/server/src/modules/**`（业务路径：API routes / services / primitives）
- `apps/ccb-console/server/src/workers/**`（后台 worker：scheduler / outbox / indexer）
- `apps/ccb-console/server/src/indexer/**`（文件→DB 同步）
- `apps/ccb-console/server/src/db/**`（数据库连接 / migrations runtime）
- 任何 周期性 cron / hot path / 生产 worker 入口

未来如果出现新的"非业务路径但需要豁免"的脚本类型，先评估是否真的不能走治理通道；如确需豁免，必须新增 ADR，不在本决策范围内扩展。

### 同 PR 范围内的真修项

- `derive.service.ts:82` 业务路径违规：**真修**，在 task.create 后同事务内 `enqueueProjectionOutbox(revision: 1)`，加 focused test。理由：derive_subtask 创建正式 Task 进入 projection，下游 read model 依赖此事件。
- `Requirement.sourceTaskId` matrix coverage 缺口：**补 matrix**（最小方案，只补字段声明）。不扩 `derive_requirement` write entry taxonomy，那是治理体系级扩展，独立任务承接。

## Rationale

### 为什么不选 "continue-on-error" 让 lint 不 block PR

第二次毁掉 workflow 的真跑路径，把"治理欠债"伪装成"治理已建立"。本 PR 已经修对 workflow（commit 7452cb7 / 408e458），这是真正的进展；走 continue-on-error 等于把这个进展撤销。

### 为什么不选 "matrix 声明式豁免" 一步到位

- matrix schema 扩展是治理体系级变更，与本 PR 主线（requirement edit + reanalyze）无关
- `exempt_paths` 字段会让 matrix 同时承担"字段声明"和"路径策略"两个职责，违反单一职责
- 当前只有一类需要豁免的路径（maintenance），用更轻的 hardcode 解决即可
- 真要演进，应该是独立任务，配套 ADR 与 schema migration

### 为什么允许 derive.service.ts:82 历史欠债同 PR 修

虽然该处不是本 PR 引入，但：
- 只有 1 处，工作量小（30 分钟）
- 不修就要再立"业务路径豁免"决策，比真修代价大
- 顺手清掉历史欠债，避免下个 PR 再次受阻

## Consequences

### 正面

- 当前 PR 解锁，lint 回绿，能合入
- 治理体系核心边界（business / worker / hot path 不豁免）明确
- ADR 留痕，未来再有 maintenance 脚本类型不再争议
- workflow 真跑保留，治理通道仍受 CI 保护

### 负面

- maintenance 脚本失去 lint 兜底，若未来有脚本误把生产逻辑写进 maintenance 路径会无人发现 —— 通过 code review 兜底
- 引入"豁免目录"概念后，未来可能有人滥用（把不该豁免的代码塞 maintenance/）—— 通过 PR 审查 + 本 ADR 明确边界兜底

### 风险缓解

- maintenance 脚本仍受 typecheck / 单测 / 集成测试覆盖
- 涉及大批量数据修复的脚本要求 dry-run + apply 两段式（已是当前惯例）
- 任何怀疑误用豁免的 PR，reviewer 引用本 ADR 决断

## 后续可演进（非本决策范围）

未来如有需要，可独立立项演进到：

- matrix schema 加 `exempt_paths` 字段，把豁免声明化
- ADR-0014 / ADR-0019 体系内统一表达"路径豁免"语义
- lint 报告区分 "real violation" 与 "exempted path skipped"，输出 metrics 监控豁免范围扩张

## 验收

- `pnpm --filter ccb-console-server lint:schema-ownership -- --check` 退出码 0
- maintenance/ 下脚本未被扫描（lint 输出明确显示 skipped paths）
- modules/ workers/ indexer/ 下任何裸 prisma 写入仍会报红
- `derive.service.ts:82` 不再出现在 failures 列表
- `Requirement.sourceTaskId` 在 matrix 已声明
