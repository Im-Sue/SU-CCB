---
adr: ADR-0020
title: Follow-up 作为来源标记 · 取消 backlog task 概念
date: 2026-05-15
status: accepted
owner: claude
reviewer: ccb_codex (consult rep_d094c9c45b04)
related: [ADR-0013-task-hierarchy-three-tier-model, ADR-0017-epic-multi-pr-materialization, ADR-0019-entity-field-ownership-and-sync-direction]
supersedes_partial: [currentNode='backlog' 私自标记的所有 spec/state/test 用法]
---

# ADR-0020 · Follow-up 作为来源标记，取消 backlog task 概念

## Context

用户实证：CCB 看板把"Draft #1/2/3"（用户登记的未立项需求）显示成 backlog task，与
用户直觉不符。深查发现：

1. `references/kernel/nodes/` 只有 7 节点（requirement_analysis → archive），
   `backlog` 不是合法 kernel 节点。
2. `currentNode='backlog'` 是 spec frontmatter 手写的"野生标记"，违反
   `hierarchy-invariants.spec.ts` 对 subtask currentNode 必须在 7 节点或终态的约束。
3. Draft #1/2/3 双身份：既是 Requirement(status=draft) 又被 indexer 派生为
   currentNode=backlog 的 Task。
4. follow-up 在 CCB 历史里没有明确建模，被混入 backlog task。

## Decision

### 实体模型只 4 类

| 实体 | 角色 |
|---|---|
| Requirement | 用户的需求（草稿 → 立项 → 交付） |
| Epic | 大需求容器（kind=epic） |
| Subtask | 可执行工作（kind=subtask，走 7 节点）|
| Document | 知识 / 决策 / 清单（ADR / decision / 备忘） |

**废除**：currentNode='backlog' 标记、"backlog task"作为独立类型概念、
follow-up 作为独立实体类型概念。

### Follow-up = 来源标记，按"要做"分流

| 衍生场景 | 数据 | 关联字段 |
|---|---|---|
| A 当下做 | 当前任务内补做 | 不产生新实体 |
| B 同 Epic 内 followup | 新 Subtask | parentEpicId + requirementId（且必须 = 父 Epic.requirementId） |
| C 同 Requirement 直挂 followup | 新 Subtask | requirementId（无 parentEpicId） |
| D 衍生新需求 | 新 Requirement | source_task_id（新字段） |
| E 暂存想法 / 备忘 | Document（ADR/decision/note） | 不进任务系统 |

### Schema 改动

- **新增** `Requirement.source_task_id` (String?, FK → Task.id, onDelete: SetNull)
- **保留** `Requirement.generatedTaskId` 兼容字段（已 deprecated，由
  `RequirementMaterialization` 主导立项关系）
- **不动** `RequirementMaterialization` 表

### Indexer / Invariant 收紧

- indexer 拒绝 spec frontmatter `currentNode: backlog` 或 unknown node →
  落 anomaly，不派生 task
- `hierarchy-invariants.spec.ts` 已要求 7 节点白名单，本 ADR 强化执行

### UI 设计

| 区域 | 内容来源 |
|---|---|
| 顶部「未立项需求」 | Requirement.status='draft'，按 source 分 tab (manual / followup_of_task) |
| 中部 Epic 摘要 | 已立项 Requirement / Epic |
| 主流程 7 节点列 | Subtask（currentNode ∈ 7 节点） |
| 任务详情「衍生 followup」段 | 反向查询 Subtask.parentEpicId / Requirement.source_task_id |
| review/archive 衍生按钮 | 3 选 1：加 subtask / 转 Requirement.draft / 写 decision |

废除 BacklogStrip 组件原"backlog task"语义，可复用为「未立项需求」UI 容器。

## Consequences

**正面**：
- 概念清晰，与 ADR-0013 三层模型一致
- backlog 不再阻塞父完成（aggregation 逻辑可简化）
- 衍生 follow-up 有明确数据归属，避免孤儿
- 看板「未立项需求」与 /requirements 页面共享同一数据，仅视图不同

**负面 / 代价**：
- schema migration（新增 source_task_id 字段 + index）
- 历史数据治理：4 个孤儿 backlog task + F9 residual 清单 spec
- BacklogStrip 组件改语义，前期 commit b4106c6 视觉需重做
- aggregation 中 `backlogCount` API 字段需退场兼容

**已 commit 改动重评估**：
- `262e940` blockingChildren 抽象保留（仍过滤 cancelled），过滤 backlog 部分未来移除
- `262e940` 3 Draft 挂 Requirement 关系正确，但 backlog task 待删
- `b4106c6` BacklogStrip 改语义为「未立项需求」

## Migration Path

按 codex consult 推荐顺序：

1. **本 ADR 落定** → 阻止后续 spec 写 `currentNode: backlog`
2. **Schema migration**：加 source_task_id 字段 + indexer 收紧规则
3. **数据治理**（一次性 maintenance 脚本）：
   - Draft #1/2/3：删 Task 记录，保留 Requirement
   - F9 residual：按内容拆解（U1-U3 → Requirement.draft, A5+W1 → Subtask 挂工程债 Req, 用户决策项 → decision note）
   - F9 residual spec 归档为 Document
4. **UI 改造**：BacklogStrip → UnstartedRequirementStrip；任务详情衍生段；review/archive 衍生按钮
5. **aggregation 清理**：移除 backlog 豁免逻辑（彻底删 backlogCount 字段或保留只读兼容）

每步独立 spec / 独立 commit，可暂停可回滚。

## Open Questions（codex 列出的盲点 · 实施前需决策）

| 编号 | 议题 | 倾向 |
|---|---|---|
| OQ-1 | 多级衍生链（A→B→C）展示深度 | UI 仅显示直接父，详情可追溯 |
| OQ-2 | 循环引用防护 | schema 加 check / 应用层校验 |
| OQ-3 | 跨项目 source_task_id | 禁止（projectId 校验） |
| OQ-4 | 源 task 删除/归档后链接策略 | onDelete: SetNull |
| OQ-5 | 一个需求来自多个 task | 当前 1:N，未来需要可改 join 表 |
| OQ-6 | indexer 是否继续派生 draft spec 为 task | 否，draft spec 仅作 Requirement.description 来源 |
| OQ-7 | backlogCount API 字段退场 | 保留只读兼容 1 个 minor 版本后移除 |

## References

- Codex consult: rep_d094c9c45b04 (job_85776a46ffc4)
- Hierarchy invariants: apps/ccb-console/server/src/modules/task/hierarchy-invariants.spec.ts
- ADR-0013 三层模型, ADR-0017 立项 materialization, ADR-0019 字段所有权
- Discussion turn: 用户原话 4 段 (Draft 不应在 backlog / 流程梳理 / followup 关联管理 / 接受新概念)
