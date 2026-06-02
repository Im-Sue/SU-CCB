---
id: ADR-0034
title: Capability Outcome Policy · plugin 状态变更治理
status: active
decided_at: 2026-05-23
last_updated: 2026-05-23
decider: 用户 paradigm 拍板 + Claude 拍板 outcome-canonical / 禁裸 set_* / 风险归档 approval ref
reviewer: ccb_codex（round 1-3 设计协商）
codename: capability-outcome-policy
related_doc:
  - docs/.ccb/requirements/active/2026-05-23-phase5-v1x-governance-enhancement.md
  - docs/02_需求设计/ccb-plan/2026-05-22-phase5-governance-backlog.md
parent_adrs:
  - ADR-0023   # plugin sovereignty 主决策
  - ADR-0024   # primitive runtime（applyCapabilityOutcome write 路径基座）
  - ADR-0030   # plugin node paradigm（节点 = capability）
amends:
  - ADR-0025   # reconcile apply 必须走 applyCapabilityOutcome
  - ADR-0026   # Requirement.rollupStatus/Progress 改 derived read model
prerequisite_adrs:
  - ADR-0024
  - ADR-0030
consult_evidence:
  - job_8eda8aa7f7ba   # round 1 漂移盘点 + D 混合（事后发现流水线视角偏差）
  - job_25c59f101ff0   # round 2 paradigm reframing → capability outcome policy
  - job_ce3fc5a05d0b   # round 3 outline 前 6 约束吸收 + 退出协商
impacted_components:
  - apps-ccb-console-server
  - apps-ccb-console-web
  - claude-plugin-distribution
  - docs-ccb-workspace
---

# ADR-0034: Capability Outcome Policy · plugin 状态变更治理

## Status

Accepted（2026-05-23）。Phase 5 议题 1 形式化。基于用户 paradigm 校准反馈 + Claude / ccb_codex 三轮 consult 协商收敛 + Claude 拍板 3 项产品契约。

## Context

### 议题 1 用户原话（2026-05-22）

> plugin 如何做好的 md 或者 db 里的需求、任务 status 管理？防止每次更新状态或者进度不是随意更新 flag value。

### 用户 2026-05-23 paradigm 校准

> 1. 基于 AI / plugin 驱动的项目管理和状态管理，**页面上不存在直接手动或者人为修改状态的情况，所有都应该触发 AI 或者我们的 plugin 指令来进行更新**
> 2. 实际执行指令或者有些指令对应使用节点时是灵活的、动态的，**一个需求、任务的状态应该是被动态驱动的，而不是单纯的流程化的**

### 漂移现状盘点（codex round 1 grep 出来）

- `writeTaskState()` 只 enum/range 校验，**无 from→to transition 校验，无 event append**（lib/state/index.mjs:93）
- `Task.status` **双枚举不一致**：kernel `state-schema.yaml` (`proposed/planning/dispatch_ready/...`) vs plugin `business-rules.mjs` (`active/blocked/cancelled/archived/done`)
- `blockedReason` 只校验"如果存在必须 string"，**不强制 blocked 时必填**
- `reconcile set_progress` 任意跳变；`unset_archive` 100→0 无 reason
- `quick_archive` 直接 archived/100/completed，**未校验 review_status=passed**
- `Requirement.status` 最危险：indexer `syncRequirementsFromMarkdown()` 只 create 写 status，**update 分支漏写**；Console rollup helper **跨界回写** Requirement.status → 与 ADR-0026 owner 冲突

### Paradigm-fit 模型

| 旧框架（错） | 新框架（对） |
|---|---|
| 固定 sequential state machine + 字段独立治理 | **capability × outcome × subject_type → state_effects + guards + evidence + must_ask_refs** |
| AI 自己改字段 `status = "planning"` | AI 声明 outcome，runtime 按 policy 表翻译成状态变化 |
| 状态机的合法 transition 是固定图 | policy 表是「capability 完成时**可能**有哪些 outcome；每个 outcome 对应哪些字段变化」|

## Decision

### 1. Capability Outcome Policy 框架

业务状态变更**只能**经 `applyCapabilityOutcome()` 框架函数。语义：

```
applyCapabilityOutcome(
  capability_id,
  outcome_type,
  subject_ref,
  evidence[],
  must_ask_refs[]
) → state_effects | rejection
```

runtime 在 policy 表查 `(capability_id, outcome_type, subject_type)` 元组，得到 allowed state_effects、evidence 类型要求、必须命中的 must_ask 项；校验通过 → 落 canonical（走 ADR-0024 CAS/lock）+ append EventJournal。

### 2. 三大不变量

- **I1 · outcome 是唯一驱动**：status / progress / currentNode / runtimeState / lastTransitionId / blockedReason 等业务状态字段**必须**经 `applyCapabilityOutcome()`。禁止裸 `set_*` / `patch frontmatter`。reconcile / quick_archive / set_progress 等老 actions 全部重构为 capability + outcome。
- **I2 · evidence-bound**：每个 outcome 必须配 evidence[]；缺证据 → state_effects 仅可进 `needs_review / escalated`。
- **I3 · must_ask 钩子**：policy 表 `must_ask_refs` 引用必问清单 12 类项；命中项必须有 approval ref（来自 `/ccb:su-approve`）才放行 state_effects。

### 3. Evidence 三类

| 类 | 名字 | 例子 |
|---|---|---|
| **A** | system-verifiable | codex job_id + reply_ref / test exit code / file hash / git commit ref / EventJournal previous event id+hash |
| **B** | human-approved | `/ccb:su-approve` 产生的 approval record ref（命中 must_ask 后） |
| **C** | narrative + fixed-registry auto-check | AI 叙述 + runtime 跑 fixed registry check（详见 6） |

### 4. Evidence 结构约束

每条 evidence 必填 5 字段：`kind / ref / check_id / observed_at / source_actor`。多条 evidence 可组合（OR / AND 由 policy 字段决定）。

### 5. EventJournal 引用三禁

- 禁止自引用（不能引用当前 outcome 自己即将写的事件）
- 禁止递归证明（不能引用「另一个未结案 outcome 的事件」）
- 禁止「事件存在 = 事件正确」（必须 event id + hash + payload 校验配合，事件存在本身不是证据）

### 6. C 类 fixed-registry auto-check

C 类的 `check_id` **必须**从 fixed registry 选，AI 不能自造检查。首批 5 个 check：

| check_id | 语义 |
|---|---|
| `file_exists` | 文件存在 |
| `schema_valid` | 文件按目标 schema 校验通过 |
| `count_gt_zero` | 集合非空 |
| `hash_matches` | 文件 hash 等于指定 ref |
| `journal_event_exists` | EventJournal 含指定 event_id（需配 payload 校验） |

registry 加 `version` 字段，破坏性变更 → 新 check_id，不 break 旧 evidence。

### 7. Requirement.status 是 outcome-canonical / rollup 是 derived

- **Requirement.status = outcome-canonical**（AI capability outcome 决定）—— Claude 拍板
- **Requirement.rollupStatus / rollupProgress = derived read model**（子任务聚合，UI 展示用，不是 truth source）
- UI 可算 `effectiveStatus = f(status, rollupStatus)` 用于展示
- Console rollup helper **重定位**：只写 `rollupStatus / rollupProgress`，**禁止**回写 `status`

### 8. Progress 治理

- 禁止任何代码裸 set `progress = N` —— Claude 拍板
- progress 只能由 outcome 触发（policy 表中 `state_effects.progress = "to_range:[40,60]" | "set:80" | "regress_to:[20,30] with reason"`）
- 回退允许，但必须来自明确 outcome（`replan_started / scope_expanded / verification_failed`）+ reason + evidence

### 9. quick_archive policy

- 不再是「跳 review」概念，是 capability + outcome 进 policy 表
- **低风险归档**：evidence 类 C（`file_exists + schema_valid + journal_event_exists` 等 registry check）即可
- **带风险归档**（命中必问清单 7-12 任意项）：**必须** evidence 类 B（`/ccb:su-approve` approval ref），AI 自己不能放行 —— Claude 拍板
- 引入 `/ccb:su-quick-review` capability：用户单人快审 → 产生 review_passed outcome → archive 自然走

## Data Model

### 1. policy 表（存储位置 + DSL）

存储：`su-ccb-claude-plugin/references/kernel/capability-outcome-policy.yaml`（plugin-side active kernel）

DSL 示例：

```yaml
- capability_id: requirement_analyze
  outcome_type: analyzed
  subject_type: requirement
  state_effects:
    status: set:analyzed
    progress: to_range:[30, 50]
    currentNode: set:planning
  evidence_required:
    - { kind: A, source: codex, count: ">=1" }
    - { kind: C, check_id: schema_valid, target: requirement_md }
  must_ask_refs: []
```

policy yaml 由 plugin lib 编译为 TS validator，CI 校验 schema；新增 outcome 必须**双改** yaml + validator。

### 2. Requirement.status 取值

`{ drafting | analyzing | analyzed | planning | executing | reviewing | delivered | blocked | cancelled | deferred }`

### 3. Task.status 取值（首批，待 implementation spec 细化）

`{ planning | dispatch_ready | dispatched | implementing | reviewing | done | blocked | cancelled | archived }` —— 收敛 kernel `state-schema.yaml` 与 plugin `business-rules.mjs` 当前双枚举不一致。

### 4. Evidence registry

存储：`su-ccb-claude-plugin/references/kernel/evidence-check-registry.yaml`（plugin-side active kernel）

```yaml
version: v1.0
checks:
  - check_id: file_exists
    signature: (path: string) → bool
  - check_id: schema_valid
    signature: (path: string, schema_ref: string) → bool
  - check_id: count_gt_zero
    signature: (query: string) → bool
  - check_id: hash_matches
    signature: (path: string, expected_hash: string) → bool
  - check_id: journal_event_exists
    signature: (event_id: string, expected_hash: string) → bool
```

### 5. EventJournal 新事件类型（ADR-0027 扩展）

| event_type | 触发 |
|---|---|
| `capability_outcome_applied` | outcome 经 policy 校验后落 canonical |
| `capability_outcome_rejected` | evidence 不足 / must_ask 未命中 / state_effects 非法 |
| `evidence_check_failed` | C 类 registry check 失败 |

旧 `state_write_intent / state_write_done`（ADR-0027 已定义）沿用，不重复造。

## Prerequisites

1. **ADR-0024 CAS/Lock/EventJournal runtime** ✅（Phase 1 完成 2026-05-22）—— `applyCapabilityOutcome()` 内部 write 走 ADR-0024 primitive
2. **ADR-0030 manifest 形态** ✅（Phase 0 完成 2026-05-21）—— manifest ⑥ 三档样例**承载 outcome 训练**（区分真 passed / 看似 passed / failed），policy 真相在本 ADR + implementation spec
3. **Active kernel path 显式声明**：
   - plugin-side active kernel = `su-ccb-claude-plugin/references/kernel/`
   - root `references/kernel/` = legacy/compat，**本 ADR 不删除**（housekeeping 另起）
   - policy / evidence registry 文件**只**放 plugin-side active kernel

## Risk & Guardrails

| 风险 | Guardrail |
|---|---|
| **false outcome**（AI 声称 passed 证据不足）| evidence-bound + 缺证据强制 needs_review/escalated；C 类 fixed-registry 防 AI 造检查 |
| **multi-slot last-write-wins** | outcome 携带 base hash/revision，applyCapabilityOutcome 走 ADR-0024 CAS/lock（按 subject/file 锁，非 slot 锁；遵循 ADR-0032） |
| **EventJournal 循环证明** | 三禁规则由 runtime 校验：自引用 / 递归 / 「事件存在即证据」 |
| **旧 reconcile actions 重构破坏面** | 增量重构：reconcile 各 action 重定义为 capability + outcome，旧 patch 路径标 deprecated + lint warning，下个 phase 移除 |
| **Console rollup helper 跨界写 status** | 重定位 helper 只写 rollup\*；Console PATCH 加 owner lint 拒绝 |
| **policy 表与代码漂移** | policy yaml 由 plugin lib 编译为 TS validator，CI 校验；新增 outcome 必须双改 yaml + validator |
| **evidence registry 版本治理** | registry `version` 字段；破坏性变更 → 新 check_id，不 break 旧 evidence |

## Amends

### ADR-0026（Entity Field Ownership v1.0）

- `Requirement.status` owner 不变（仍为 plugin / requirement-md），**补充值域** = outcome-canonical（见 Data Model 2）
- `Requirement.rollupStatus / rollupProgress` 字段语义**修订**：从「derived from 子任务」改为「derived read model · 不是 truth source · **不可反向决定 Requirement.status**」
- Console rollup helper 重定位：只写 `rollupStatus / rollupProgress`，**禁止**回写 `status`
- 其余 ADR-0026 字段所有权矩阵**不动**

### ADR-0025（AI-native Reconcile + Diff Log）

- `reconcile apply` 必须走 `applyCapabilityOutcome()`
- reconcile 各 action（`set_progress / set_status / quick_archive / unset_archive`）**重定义为 capability + outcome**：
  - `reconcile_drift_repaired` outcome（evidence 类 A：previous events + repair plan）
  - `reconcile_quick_archive` outcome（evidence 类 B / C 由 must_ask 命中决定）
- 旧 patch 路径标 deprecated + lint warning
- ADR-0025 9 步工作流 + 硬边界**不动**

## Related

- **ADR-0024** plugin primitive runtime（write 路径基座）
- **ADR-0027** EventJournal v1.0（新增 3 个 event types: `capability_outcome_applied / rejected / evidence_check_failed`）
- **ADR-0030** plugin node paradigm（manifest ⑥ 三档样例承载 outcome 训练；policy 真相在本 ADR）
- **ADR-0032** multi-window slot topology（锁按 subject/file 不按 slot）
- **Phase 5 议题 3** docs/ 命名规范 → 独立 ADR-0033
- **Phase 5 议题 4** 任务拆分粒度治理 → 独立讨论

## 协商证据

`consult_evidence` 列 3 个 codex consult job_id：

- **round 1**（rep_1362224c4489）：漂移盘点 + D 混合方案（事后用户 paradigm 校准发现是流水线视角偏差，对此轮的 finishNode framework 改名 + 状态机框架推翻）
- **round 2**（rep_1ce8486f6032）：paradigm reframing → capability outcome policy 范式 + 3 risks（false outcome / multi-slot / 双 kernel）
- **round 3**（rep_bf1883216b5c）：outline 前 6 约束吸收（evidence 结构 + C 类 fixed-registry + EventJournal 三禁 + manifest ⑥ 训练用 ≠ policy 真相 + active kernel 措辞 + amends 不 supersede）+ 明示「无新增信息维度」退出协商

完整时间线见 EventJournal `consult_reply_received` 事件。

## 后续

- **Implementation spec**（`SP-ADR0034-impl`）由 Codex 起草，范围：
  - `applyCapabilityOutcome()` 框架函数实现
  - policy yaml DSL parser + TS validator generator
  - evidence-check-registry 5 个 check 实现
  - `writeTaskState` / `business-rules` 双枚举收敛
  - reconcile 各 action 重构为 capability + outcome
  - Console rollup helper 重定位 + Console PATCH owner lint
  - quick_archive policy 实施 + `/ccb:su-quick-review` capability
- **housekeeping**（root `references/kernel/` legacy 清理）独立 ADR / hotfix
- **Phase 5 议题 1 启动条件** 已达成；议题 3 / 4 仍待启动

## Addendum 2026-05-23 · EventJournal Fail-Closed

实施前 deep review（job_b57c8a7b45d4 / rep_c1dc75279abb）发现 ADR-0024 ↔ ADR-0034 冲突。

### 问题

ADR-0024 plugin primitive runtime 允许 EventJournal append 失败**不回滚**（warning-only 行为）。但本 ADR (ADR-0034) 把 EventJournal 当**状态可信链**（`capability_outcome_applied` event 是 outcome apply 的证据 + audit）。

**冲突**：如果 EventJournal append 失败但 state_effects 已落 canonical → 状态机断裂，evidence 缺失，后续 reconcile 无法识别该 outcome 是否成功。

### 修订

`applyCapabilityOutcome()` 实现**必须**把 EventJournal append 视为**强一致 / fail-closed** 步骤：

| 步骤序 | 操作 | 失败处理 |
|---|---|---|
| 1 | 校验 evidence + must_ask + policy 匹配 | 不通过 → reject outcome（不写 canonical / 不 append event）|
| 2 | acquire lock + CAS check | 失败 → 进 retry 或返 conflict |
| 3 | append EventJournal `capability_outcome_applied` event（先于写 canonical）| **失败 → 整个 outcome apply 失败**（fail-closed，state_effects 不落 canonical）|
| 4 | 写 canonical state_effects（state.md / sqlite projection）| 失败 → 写 EventJournal `state_write_failed` event + 不释放 lock，转 reconcile |
| 5 | append EventJournal `state_write_done` event | 失败 → warning-only（已有 canonical + applied event，state_write_done 是后置审计）|

**关键**：步骤 3 `capability_outcome_applied` event **不能 warning-only**。这是与 ADR-0024 默认行为的明确差异。

`applyCapabilityOutcome()` 实现层须在调用 ADR-0024 primitive 时显式声明 fail-closed semantic（如 `runtime.appendEvent({ failPolicy: "fail-closed" })`）。

### 影响

- `SP-ADR0034-impl` 实施期必须实施 fail-closed 路径
- ADR-0024 主决策**不动**（warning-only 是默认；fail-closed 是调用方显式选项）
- ADR-0027 EventJournal v1.0 envelope 不变；fail-closed 是 plugin runtime 调用层语义
- 步骤 3 失败可能导致重试风暴 → 实施 spec 加 backoff / max retry / 转 reconcile 路径

### 协商证据

实施前 deep review job_b57c8a7b45d4 / rep_c1dc75279abb 由 codex 独立 audit 提出该硬冲突。Claude 接受为 ADR-0034 必填 amend。
