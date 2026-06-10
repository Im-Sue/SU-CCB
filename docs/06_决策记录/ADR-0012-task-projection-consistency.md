---
id: ADR-0012
title: Task Projection Consistency — filename 漂移修复 + archive 路径语义 + FK 迁移
status: active
decided_at: 2026-05-08
decider: Claude
reviewer: ccb_codex
related_epic: ccb-console-task-projection-consistency
related_tasks: [ccb-console-task-projection-bugfix]
deprecated_in: null
removed_in: null
grace_window: null
impacted_components: [apps-ccb-console-server]
---

# ADR-0012: Task Projection Consistency

## Status

Accepted.

## Context

Console 看板显示 7 个"需求分析 · 节点未知"的幽灵 active task，加上索引健康面板 0/0/0 不匹配 API 实际数据。Codex 三轮 plan review（v1 6.8 → v2 7.2 → v3 7.4，第 4 轮收敛细节后由本 ADR 锁定）确认根因与解决路径：

1. **R1 — Identity 漂移**：`document-parser.ts` 把文件名 slug 作为 `taskKey` 主优先；当 `state` 文件命名与 `spec` 不一致（典型场景：归档时 spec 改成另一个日期前缀），二者被分到不同 taskKey，state 与 spec 永远归不到同一 task。
2. **R2 — 路径语义未编码**：indexer 不读 path，`docs/.ccb/specs/archive/` 下的 spec 派生出 `status=active` 幽灵 task。
3. **R3 — 前端无响应式**：file-watcher 改 DB 后前端零感知。本 ADR 仅覆盖 R1+R2；R3 的前端 polling 设计在同步 commit 中落地，不另立 ADR。

## Decision

### 决策 1 · taskKey 仍以 filename slug 为主，二次反向合并补 identity

不翻转 `document-parser.ts` 的 taskKey 优先级（避免 130+ archived task 全 taskKey 漂移、Task.id 重建、TaskRun/Workspace/ReviewIntent FK 断裂、SlidePanel URL 失效）。改为在 `deriveTasks()` 内做"二次反向合并"：

- 第一遍按 filename slug 分组（行为不变）
- 第二遍扫描"仅 state 文档孤儿组"，按 `frontmatter.task_id`（spec 一侧 `task_id` 缺失时用 `spec_id` 兜底）跨组匹配
- 匹配成功合并到 spec 组，保留 spec slug 作 survivor taskKey，输出 `mergePlan` 给后续 FK 迁移阶段
- 同时存在 `task_id` / `spec_id` 但二者均不等于 state 端 `task_id` → 不静默合并，记 `id_conflict` anomaly

### 决策 2 · `docs/.ccb/specs/archive/` 路径即归档语义

`deriveTasks()` 在派生 projection 时读 `Document.path`：

```ts
const allSpecsInArchive =
  !stateDocument && items.length > 0 &&
  items.every(it => it.kind === "spec" && /\/\.ccb\/specs\/archive\//.test(it.path));
```

仅当组内全部为 spec 且全部位于 archive/ 路径，且无 state 文档时，强制 `status='archived'`、`currentNode='archive'`、`runtimeState='completed'`。state 文件存在则不覆盖（state frontmatter 是真理）。混合组（archive spec + active plan/task）保持 active，记 `archive_mixed_docs` anomaly 等待人工巡检。

### 决策 3 · 合并时同步重写 Document/denorm taskKey + FK 迁移

新增 primitive `merge_task_identity_assignment`（已登记到 `docs/.ccb/index/primitive-mutation-inventory.yaml`）。每个 `mergePlan` 在单一 `prisma.$transaction(async tx => ...)` 内执行：

1. **Document.taskKey 重写**：state Document 行的 taskKey 改写到 survivor，`computeTaskStateProjection` / `file-watcher tryRefreshStateProjection` / `resolveStatePath` 等所有 by-taskKey 索引点恢复一致
2. **Survivor 解析**（4-case 分发）：
   - 都不存在 → 跳过，下游 upsert 创建
   - **仅 source(orphan) 存在 → update Task.taskKey 保 Task.id 与 SlidePanel URL**（核心保护点）
   - 仅 survivor 存在 → 无操作
   - 两侧都存在 → winner = `argmax(refCount)`，平手优先 survivor (canonical/spec-side)
3. **完整迁移**（仅两侧都存在时）：
   - 真 FK：`TaskRun` / `TaskWorkspace` / `ReviewIntent`（onDelete Cascade，必先迁后删）
   - 非 FK 但持有 taskId 的表：`EventJournal` / `EventConsumption` / `NodeRun` / `Requirement.generatedTaskId` / `SchedulerBranchState`
   - Denormalized taskKey：`Document` / `TaskWorkspace` / `ReviewIntent` / `EventJournal`
4. **SchedulerBranchState 行级 merge**：因 `@@unique([taskId, branchSetId, branchId])`，必须按行查冲突；冲突合并规则 = **terminal 优先**（`done > failed > running > pending`），平级按 `updatedAt` 决胜；`attemptCount` 取 max
5. **SchedulerConsumerCursor 主键特殊**：`taskId` 是主键，不能 update。仅 loser 存在 → create on winner + delete loser；双侧都在 → 取 `(lastConsumedEmittedAt, lastConsumedEventId)` 靠后 tuple，记 `cursor_merged` anomaly
6. **删除 loser Task**；最后把 winner.taskKey 锁定到 survivorTaskKey，并同步 winner 自身原有的 denorm taskKey

### 决策 4 · 顺序：merge 在 cleanup 之前

`scanProject()` 调用顺序固定为 `deriveTasks → applyTaskIdentityMerges → cleanupStaleTaskProjectionsAsync → upsertTaskProjectionAsync`。merge 必须先于 cleanup，否则 `cleanupStaleTaskProjectionsAsync` 的 `deleteMany` 会先 cascade 删 TaskRun/Workspace/ReviewIntent。

### 决策 5 · anomaly 记录方式

合并过程产生的 anomaly 与 `deriveTasks` 推断的 anomaly 汇总后写入 `SyncJob.logSummary`（`reconcile` job）。详细 yaml 报告由 `scripts/verify-task-projection.ts`（commit C2 落地）输出到 `docs/.ccb/index/task-projection-verification.yaml`。

### 决策 6 · `docs/.ccb/state/` 与 `docs/.ccb/reports/` 目录约定（§P1 数据治理）

**state/**：仅存放 v0.3.2 task state 文件，每个 task **唯一一份**，filename slug 与 spec 对应文件 slug 一致；frontmatter 含 `task_id`、`currentNode`、`runtimeState` 等 kernel 真相源字段。indexer 把 path 含 `/state/` 的 markdown 标 `kind=state` 视作 task projection 输入。

**reports/**：存放任务实施期产出的报告附件（如 dual-run smoke report、coverage baseline、rollout 实施报告等）。**不进 task projection**，indexer 应标 `kind=report` 或 `kind=other`（视 P2 实现），不作为 state 真源。

**为什么分目录**：历史上一次曾出现 9 份 *-report.md 文件混入 `state/`，被 indexer 当 state 识别后导致 deriveTasks 与 computeTaskStateProjection 选 state document 顺序不一致 → DB.stateHashProjection 永久与磁盘 hash 不对齐 → 索引健康面板长期 staleStateCount > 0。一次性把 9 份 report 迁出后，issue 收敛到 0。

**spec 引用更新**：原引用 `docs/.ccb/state/<x>-report.md` 全部改写为 `docs/.ccb/reports/<x>-report.md`；引用此约定的下游 ADR、catalog、archive spec 同步更新。

### 决策 7 · UX 分级（§P0 stale UX 止痛）

- `index-health` 返回 `staleStateCountActive` + `staleStateCountArchived`，前端按 `currentNode='archive' OR status IN ('archived','done','completed')` 划分
- 概览警告分级：`active drift > 0` 用红色 + 可点击跳 `/tasks?projection=stale`；`archived-only drift` 用黄色维护提示
- 任务页 `?projection=stale[&scope=archived]` URL 参数限缩看板到 `staleTaskIds*`；顶部 banner 含 `Refresh active` 主按钮 + `archived` 二次确认入口
- 批量 endpoint `POST /api/projects/:id/refresh-stale-projections?scope=active|all`，默认 active

## Consequences

正向：
- 7 个 SU-CCB 当前幽灵 task 一次扫描即收敛
- 未来类似 filename 漂移自动恢复（无需用户手动重命名 state 文件）
- SlidePanel URL（基于 Task.id）在 case ii 路径下保持稳定
- FK 迁移 + denorm taskKey 同步保证历史不丢

风险：
- 新 primitive `merge_task_identity_assignment` 在大规模批量 merge 时（>50）可能触发 SQLite 事务过长。当前单项目场景每次 merge 数 ≤ 个位数，非 blocker；未来多项目高频可分批事务
- SchedulerConsumerCursor / SchedulerBranchState 双侧并存的合并规则是约定式（terminal 优先 / 靠后 tuple），不是协议级保证；记 anomaly 让人工 review
- `archive_mixed_docs` / `id_conflict` 留下来要由 designer 巡检；建议每周 `verify-task-projection.yaml` review

## Alternatives Considered

**Alt-1 翻转 taskKey 优先级（task_id 主，filename 次）**：被否决。会让 130+ archived task 全部 taskKey 漂移，Task.id 在 cleanup+upsert 间被删后重建，TaskRun/Workspace/ReviewIntent 通过 FK Cascade 全部丢失。

**Alt-2 引入 canonical_task_id 字段进 Task schema**：被否决。需要 Prisma migration、数据回填、TaskView 类型大改，超出"持久最优"的非目标声明。当前 task_id 仅在 frontmatter 与本 ADR 描述的合并算法中使用，没必要落到 schema。

**Alt-3 catalog-driven archive 推断**：被否决。catalog 是元数据索引，archive 是文件系统语义；两者耦合反而脆弱。路径推断更直接、更便携。

## References

- `apps/ccb-console/server/src/indexer/project-indexer.ts:deriveTasks` `:applyTaskIdentityMerges`
- `apps/ccb-console/server/src/tests/indexer-merge.spec.ts` — 10 case 覆盖
- `docs/.ccb/index/primitive-mutation-inventory.yaml` entry `merge_task_identity_assignment`
- Codex review JSON：rep_27d4003f8f01 / rep_35172933f49b / rep_37a9193e8b58
