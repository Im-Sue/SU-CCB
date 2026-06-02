---
id: ADR-0035
title: SubTask 拆分粒度 + 两层物化治理
status: active
decided_at: 2026-05-23
last_updated: 2026-05-23
decider: 用户 paradigm（参考 prediction_market）+ Claude 拍板 cap=7 / exception 需 approval ref / 优先拆 Requirement / B 重组 outcome_contracts schema
reviewer: ccb_codex（round 1 / rep_8beb3e587abd, round 2 / rep_5309321530cf）
codename: subtask-granularity
related_doc:
  - docs/.ccb/requirements/active/2026-05-23-phase5-v1x-governance-enhancement.md
  - docs/02_需求设计/ccb-plan/2026-05-22-phase5-governance-backlog.md
parent_adrs:
  - ADR-0023   # plugin sovereignty
  - ADR-0030   # capability paradigm
  - ADR-0034   # capability outcome policy
amends:
  - ADR-0034   # SubTask outcome_contracts 引用 policy 表
related_adrs:
  - ADR-0032   # slot binding 协调（1 Requirement = 1 slot）
  - ADR-0033   # Phase 3 合并实施 spec 含本 ADR 输出
consult_evidence:
  - job_c2b12d18e1d4   # round 1 两层物化 paradigm + E+D+A+C
  - job_6458655d909c   # round 2 audit + B 重组 outcome_contracts + 退出协商
upstream_reference: /mnt/f/python/web3/prediction_market/docs/
impacted_components:
  - apps-ccb-console-server
  - claude-plugin-distribution
  - docs-ccb-workspace
size_exception: false
---

# ADR-0035: SubTask 拆分粒度 + 两层物化治理

## Status

Accepted（2026-05-23）。Phase 5 议题 4 形式化。Codex 2 轮协商 + Claude 拍板 cap=7 / approval ref / 拆 Requirement 优先 / B 重组 schema。

## Context

### 议题 4 用户原话（2026-05-22）

> 目前对于需求的任务拆分机制太零散太乱了，一个需求竟然拆出来十几个子任务或者步骤，一个任务甚至嵌套了七八个小步骤。（可以去参考：`F:\python\web3\prediction_market\docs`）这个项目的文档维护方式和逻辑。

### 关键 paradigm（codex round 1）

议题 4 真正的问题**不是**"怎么拆得更细"，而是 SU-CCB **把两个不同层级混了**：

| 层级 | 是什么 | SU-CCB 当前问题 |
|---|---|---|
| **物化任务**（materialized SubTask）| 真正能派工 / 验收 / 产生 capability outcome 的交付单元 | 把太多"步骤"也物化成独立任务 → 状态/派工/验收膨胀 |
| **文档里的步骤清单**（checklist / steps）| 任务文档内的执行细节 markdown | 应该留在 markdown，**不**投影成独立 task entity |

### prediction_market 真相

不是"任务少"：Campfire 双轨市场 9 task + 42 checklist；夺宝模块 79 个编号任务。但**大多数是 living plan 里的清单**，**不是**每项都变成独立状态主体。

**"拆得多" ≠ "物化得多"**。

### 现状盘点（codex round 1 grep）

- 当前 `task_breakdown.node.md` 有"交付单元"原则但**无硬上限 / 无嵌套约束 / 无 outcome/evidence 字段**
- `breakdown-draft.schema.yaml` 只校验 `section_id / order / title / spec_section_md / owner / dependencies`
- `business-rules.mjs` 不校验数量 / 循环 / 长链 / outcome / evidence

## Decision

### 1. 两层物化模型（核心 paradigm）

| 层级 | 定义 | 投影 |
|---|---|---|
| **Materialized SubTask** | 真正可派工 / 可验收 / 可产生 capability outcome 的交付单元 | 独立 Task entity → indexer / EventJournal / slot binding |
| **Checklist / Steps**（living plan）| 任务文档内部执行细节 markdown section | **不**投影独立 Task；只是 task.md 内部段落 |

### 2. 粒度规则

- **默认 3-5 个**物化 subtasks
- **硬上限 7 个**
- **超过 7 必须分流**：拆 Requirement / 改 living plan
- **禁止嵌套**物化任务（不能 task 再生子任务）

### 3. Task-vs-Checklist 判定树

| 判定 | 条件 |
|---|---|
| 应该 **materialize 成 SubTask** | 独立 capability outcome + 独立验收 + 独立 evidence + 独立 must_ask 命中 |
| 应该写成 **checklist** | 同一 outcome 内的顺序步骤 / 文件清单 / 不独立验收 |

每个候选 item 在 breakdown-draft 时声明 `materialize: true | false` + `materialize_reason`（不符判定树 → lint fail）。

`materialize: false` 的 item 进 task.md `## 实施 checklist` section，不投影 Task。

### 4. Granularity Exception 机制

`granularity_exception: true` 允许，但**必须** user approval ref（来自 `/ccb:su-approve`）。

适用：
- 超过 7 个 materialized subtasks（**所有**超 7 都要 approval，不分情况）
- 嵌套 materialized task（极少数业务必要）

fit ADR-0034 must_ask 机制 + 议题 1 拍板「风险事项需 approval ref」原则。

### 5. 超 cap 分流判定（拆 Requirement vs Living Plan）

| 分流 | 条件 |
|---|---|
| **拆 Requirement**（健康路径） | 独立用户价值 / 独立发布 / 可并行交付 |
| **Living implementation plan**（退路） | 同一目标下很多顺序步骤 / 文件清单 / 不独立发布 |

AI 在 breakdown-draft 阶段按此判定树决策；不明时升级用户。

### 6. SubTask Schema 新增字段（B 重组）

每个 SubTask draft 含两类：

#### 6.1 policy reference（引用 ADR-0034 真相源）

```yaml
outcome_contracts:
  - capability_id: <see ADR-0034 policy>
    expected_outcome_type: <see ADR-0034>
    subject_type: <see ADR-0034>
    policy_version: <semver>      # snapshot 防漂移
    evidence_required_refs: [<policy ref>]
    must_ask_refs: [<policy ref>]
```

**关键约束**：
- `outcome_contracts[]` **只是 policy 引用**（不是 evidence/must_ask 独立真相源）
- runtime 校验仍以 `capability-outcome-policy.yaml`（ADR-0034）为准
- 写入时 snapshot `policy_version` 防版本漂移
- `expected_outcome_type` 可多个（subtask 可能产生多个 outcome）

#### 6.2 planning metadata

```yaml
planning_metadata:
  non_goals: [string]        # 显式声明不做的事
  touch_set: [path-pattern]  # 预计触及的文件/模块
  conflict_risks: [string]   # 已知冲突风险点
```

### 7. 与 ADR-0032 Slot Coordination

**关键不变量**：

- **1 Requirement = 1 slot binding**（ADR-0032 sticky binding）
- 同一 Requirement 所有 subtask 在**同一 slot 内串行执行**（slot 内 `queue_policy = SERIAL_PER_AGENT`）
- **跨 slot 并行 = 拆 Requirement**，不让一个 Requirement 横跨多个 slot

**5 slot ≠ subtask cap=7**：项目级工位（执行容量）vs 单需求拆分粒度（语义边界），是两个独立维度。

### 8. AI 拆分时 task-vs-checklist 判定支持

AI 在 breakdown-draft 节点必须为每个候选 item 主动声明：

```yaml
- title: ...
  materialize: true | false
  materialize_reason: |
    <按 Decision 3 判定树解释>
  outcome_contracts: [...]    # 仅 materialize=true 时
```

错判 detect：
- AI 把应 task 写成 checklist → lint：候选 item 的 outcome_contracts 非空但 materialize=false → flag
- AI 把 checklist 升 task → lint：超 cap 时强制走分流 / approval

## Data Model

### outcome_contracts schema（详见 Decision 6.1）

写入位置：`docs/.ccb/drafts/breakdown/<rid>.json` 的 subtask sections，由 `lib/breakdown-draft/business-rules.mjs` 校验。

### planning_metadata schema（详见 Decision 6.2）

同上位置 + 校验。

### Materialize 判定字段

每个 candidate item：`materialize: bool` + `materialize_reason: string`（必填）。

## Schema Compatibility

修订**两端必须双改**：

- **Plugin**：`su-ccb-claude-plugin/lib/breakdown-draft/schema.yaml` + `business-rules.mjs` 加新字段 + 校验
- **Console**：`breakdownDraftSchema.strict()` zod schema + generated validator 同步

旧 breakdown draft 不存在（Phase 4c clean start）→ 无 migration 负担。

新字段**可选**（向后兼容空 `outcome_contracts`）；CI lint 校验新 draft 必填。

## Docs Chain & Templates

议题 3 ADR-0033 keep list 中 4 份新模板由 Phase 3 合并实施 spec 起草：

| 模板 | 包含 |
|---|---|
| `_模板_需求设计.md` | 需求 section + 拆分预览骨架 |
| `_模板_技术设计.md` | 技术契约 + outcome contracts 设计 |
| `_模板_开发任务.md` | Task 文档 + `outcome_contracts` + `## 实施 checklist` section |
| `_模板_模块规格.md` | 模块最终态（参考 prediction_market）|

文档链：`需求设计 → 技术设计 → 开发任务（含 checklist） → 模块规格`（参考 prediction_market 流程）

## Amends

### ADR-0034（Capability Outcome Policy）

- **补充**：SubTask `outcome_contracts[]` 字段引用 ADR-0034 policy 表，**不是**独立真相源
- runtime 校验仍以 `capability-outcome-policy.yaml` 为准
- ADR-0034 主体决策**不动**

### `task_breakdown.node.md` manifest（议题 3 Phase 3 实施 spec 落地）

- 加硬上限 7
- 加嵌套禁止
- 加 `materialize` 判定字段
- 加 `outcome_contracts` 引用
- 加 `granularity_exception` approval ref 流程

## Risk & Guardrails

| 风险 | Guardrail |
|---|---|
| **5 slot 与 7 subtask 被误解为跨 slot 并行** | Decision 7 显式声明 1 Requirement = 1 slot binding；同需求 subtask 串行 |
| **AI 把应 task 写成 checklist 隐藏复杂度** | `materialize: false` 必填 `materialize_reason` + lint 校验 outcome_contracts 非空时不能 materialize=false |
| **AI 把 checklist 升 task 膨胀** | hard cap 7 + 超 cap 必走 approval / 拆 Requirement / living plan 分流 |
| **outcome_contracts 与 ADR-0034 policy 表漂移** | `policy_version` snapshot + runtime 校验以 `capability-outcome-policy.yaml` 为真相源 |
| **schema 修订破坏 Console indexer** | 双改 plugin schema + Console zod；新字段可选向后兼容 |
| **嵌套 materialized task** | 硬禁；exception 必走 approval ref |

## Consequences

- breakdown-draft schema 增加 6 类字段（outcome_contracts 6 子字段 + planning_metadata 3 子字段 + materialize 判定 2 字段）
- task_breakdown.node.md manifest 改写（Phase 3 实施 spec）
- 4 份模板内容定型（Phase 3 实施 spec）
- AI 拆分流程加判定 + lint
- 已有 breakdown draft：Phase 4c clean start 后无存量，无 migration

## Related

- **ADR-0023** plugin sovereignty
- **ADR-0030** capability paradigm（节点 = capability，不是流水线工序）
- **ADR-0032** multi-slot topology（slot binding sticky 协调；1 Requirement = 1 slot）
- **ADR-0034** capability outcome policy（outcome_contracts policy 真相源）
- **ADR-0033** document taxonomy + 主动清理（Phase 3 合并实施 spec 含本 ADR 输出）

## 协商证据

`consult_evidence` 列 2 个 codex consult job_id：

- **round 1**（rep_8beb3e587abd）：两层物化 paradigm + E+D+A+C 推荐 + 6 字段初版 + 3 open questions（cap / exception / 分流）
- **round 2**（rep_5309321530cf）：audit Claude 拍板（Q1-Q3 站得住）+ **B 重组**（6 字段 → outcome_contracts policy 引用 + planning metadata）+ 漏点扫描（cap=7 不绑 5 slot / capability_id 漏 / schema 双改）+ 明示「无新增信息维度」退出协商

Claude 拍板：
- Q1 hard cap = **7**（不选 5 防混淆 slot WIP 与拆分粒度；不选 10 防过度膨胀）
- Q2 `granularity_exception` 允许但**必须** approval ref，**所有**超 7 都要
- Q3 超 cap **优先拆 Requirement** → 退路 living plan
- B 重组 schema 接受（outcome_contracts policy reference + planning_metadata）

议题 4 不再起 round 3（codex round 2 明示无新增信息维度）。

## 后续

- **Phase 3 合并实施 spec**（议题 3 + 议题 4，本 ADR commit 后启动）：
  - 4 份 `_模板_*.md` 模板内容起草
  - breakdown-draft schema 双改（plugin yaml + business-rules + Console zod / generated validator）
  - `task_breakdown.node.md` manifest 修订
  - Task-vs-Checklist lint check 实施
  - `granularity_exception` approval ref 流程实施
- **Phase 5 议题 1-4 全部形式化完成**：
  - 议题 1 ADR-0034 ✅
  - 议题 2 ADR-0032 ✅
  - 议题 3 ADR-0033 ✅
  - 议题 4 ADR-0035 ✅
- **Phase 5 后续 spec 路线**（议题 3 实施分 Phase）：
  - Phase 2 cleanup spec（议题 3 落档后）
  - Phase 3 合并实施 spec（议题 3 + 议题 4 + 本 ADR 输出）
  - Phase 4 housekeeping spec（议题 3 后续）

## Addendum 2026-05-23 · policy_version 语义澄清

实施前 deep review（job_b57c8a7b45d4 / rep_c1dc75279abb）发现 Decision §6.1 中 `policy_version: <semver>      # snapshot 防漂移` 措辞**误导**。

### 澄清

`policy_version` snapshot 的**真实语义**：

| 用途 | 是 / 否 |
|---|---|
| **审计快照**（记录这个 subtask 起草时 policy 是哪个版本）| ✅ 是 |
| **runtime 校验依据**（按这个版本校验 outcome）| ❌ **不是** |
| **绕过新安全规则**（旧 snapshot 仍 valid 即使新版本拒绝）| ❌ **绝对不是** |

### 关键不变量

**Runtime 校验永远以当前 `capability-outcome-policy.yaml` 为真相源**，不论 subtask 起草时的 `policy_version` 是多少。

具体规则：
- 新版本**收紧**了某 outcome 的 evidence 要求 → 旧 snapshot 的 subtask 在 apply 时**必须**满足新要求，policy_version snapshot 无法豁免
- 新版本**新增** must_ask_refs → 旧 snapshot subtask apply 时**必须**命中新增的 must_ask
- 新版本**移除**了某 outcome → 旧 snapshot 的 outcome 直接 reject（不能 fall back 旧版本）

snapshot 的实际作用 = **audit trail**（"这个 subtask 起草时 AI 看到的是 v1.0 policy"），用于事后调查 / 版本兼容报告，**不是 runtime 行为依据**。

### 影响

- `SP-ADR0034-impl` + Phase 3 合并实施 spec 必须明确这个不变量
- breakdown-draft schema 的 `policy_version` 字段保留（审计用），但 lint **不能**用它绕过当前 policy
- AI 在 breakdown-draft 阶段起草 `outcome_contracts` 时如果 policy 变化，draft 自动 stale，需重新生成
- 修订 Decision §6.1 注释措辞：`policy_version: <semver>` 注释从「snapshot 防漂移」改为「audit trail snapshot；runtime 仍按当前 policy 校验」

### 协商证据

实施前 deep review job_b57c8a7b45d4 / rep_c1dc75279abb 由 codex 独立 audit 提出该语义陷阱。Claude 接受为 ADR-0035 必填 amend。
