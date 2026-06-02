---
id: ADR-0028
title: Two-Tier Entity Model + Anchor Subject Generalization
status: active
decided_at: 2026-05-19
last_updated: 2026-05-19
decider: Claude (with user authorization)
reviewer: ccb_codex (consult rounds 1-7)
related_doc: docs/02_需求设计/ccb-plan/2026-05-18-sp-a10-three-tier-model-consult.md
companion_adrs:
  - ADR-0023  # plugin sovereignty 总纲（addendum 2026-05-19 引入 AI orchestrator + capability registry 哲学）
  - ADR-0029  # 大状态独立指令原则
  - ADR-0030  # plugin/skill/kernel 实现机制（待论证）
supersedes_as_normative_baseline:
  - ADR-0013  # 三层模型源决策（本 ADR 回归 §D8 原意）
  - ADR-0017  # Epic Multi-PR materialization v2（kind=epic carrier 工程绕路被本 ADR 取代）
impacted_components:
  - apps-ccb-console-server
  - apps-ccb-console-web
  - claude-plugin-distribution
  - docs-ccb-workspace
---

# ADR-0028: Two-Tier Entity Model + Anchor Subject Generalization

## Status

Accepted（2026-05-19）。基于用户 2026-05-18 提出"立项才能 AI 解析与设计本意冲突"+ 7 轮 Claude / ccb_codex consult 协商 + 用户 7 项拍板（SP-A10 备忘 §5）。

## Context

ADR-0017 v2 让 `kind=epic` carrier 跑前三节点（requirement_analysis / technical_design / task_breakdown），根因是 ADR-0018 当时 Anchor API 强校验 epic。这导致：

- "AI 解析"必须先立项（创建 carrier）才能跑——与设计本意（决策审查工具）倒置
- Epic 这一层混入两种职责：业务协调器 + anchor/planning carrier，后者纯属工程绕路
- `state-schema.yaml` 自己写的 `kind=epic ⇒ current_node IS NULL` 与 ADR-0017 让 carrier 跑节点形成内部张力

用户拍板"取消 Epic + Requirement 升格为 planning carrier"，方向回归 ADR-0013 §D8 原意（7 节点只挂 SubTask，Requirement 是独立表）。

## Decision

### 决策 1 · 实体两层

```
Project
└── Requirement（planning carrier）
    └── SubTask（"子任务"，执行单元）*
```

- **Requirement 升格**为 planning carrier：自己挂 anchor + 持有 plan state
- **Task 收敛为 SubTask**（中文 UI "子任务"；schema 标识符保留 `Task.kind="subtask"` 或后续重命名留 ADR-0030）
- **Epic 取消**：不再是必经层
- **DeliveryGroup**（可选分组容器）首版**不做**，留 v1.1+ 独立指令对已拆 SubTask 二次分组

### 决策 2 · Anchor subject 泛化

`AnchorAllocation.boundEpicTaskId` 改为：

```
subjectType: "requirement" | "subtask"
subjectId: string
mode: "planning" | "execution"
```

- `mode=planning` 时 subject = Requirement
- `mode=execution` 时 subject = SubTask

### 决策 3 · Requirement 状态枚举（6 个极简）

| 状态 | 含义 |
|---|---|
| `drafting` | 刚创建，编辑内容中 |
| `planning` | 跑 AI 解析 / 设计 / 拆分（取代旧 `analyzed`）|
| `delivering` | 已拆 SubTask，执行中 |
| `delivered` | 所有 SubTask 归档完 |
| `deferred` | 暂缓 |
| `cancelled` | 取消 |

`planning` 内部细分通过 `currentPlanningStep` 字段（**不扩状态枚举**）：
`analysis` / `design` / `breakdown_draft` / `ready_to_materialize`

**未来如需细分，扩字段不扩状态**。

### 决策 4 · WIP + Anchor 并行

- WIP 从 2 调到 **10 起步**（配置化）
- Requirement planning anchor + SubTask execution anchor 可**并行**
- 同一 Requirement 内多个 SubTask **默认串行**（首版不开放，v1.1+ 通过独立指令放开）
- planning anchor **跟随 Requirement** 到 delivered / cancelled

### 决策 5 · AI Orchestration Runtime 抽象契约

Runtime 必须支持：
- capability registry lookup
- precondition check + DENY 处理
- event emission（capability_invoked / capability_completed / capability_denied）
- loop budget（per-command / per-capability）
- idempotency key
- reflection / escalation hook（同 capability + 同 input_hash 重复 1 次 self-reflect，2 次 escalate）

**不在本 ADR**：capability spec 字段、SKILL.md 字段、runtime 具体实现（→ ADR-0030 / SP-A11）。

### 决策 6 · Requirement Schema 升格字段（抽象）

Requirement 新增 planning state 字段族：
- `currentPlanningNode` / `planningSubstate` / `planningRuntimeState` / `lastPlanningTransitionId`
- `planRevision` / `planDocPath` / `breakdownDraftPath`
- `planningAnchorId`（projection）
- `rollupProgress` / `rollupStatus`

具体字段类型 / owner（plugin vs Console operational）留 ADR-0026 字段所有权矩阵。

### 决策 7 · 实施前提（硬前置）

1. **AnchorAllocation 必须 generic subject**（boundEpicTaskId → subjectType + subjectId + mode）
2. **EventJournal envelope 必须 generic subject**（taskId / taskKey → subjectType + subjectId + subjectKey?）
3. 前三节点 manifest applicable subjects 不再硬绑 `[subtask]`（具体 manifest 改造留 ADR-0030）

## 非目标

- 不规定节点 manifest 字段（capability spec）→ ADR-0030
- 不规定 SKILL.md 字段（command intent spec）→ ADR-0030 / ADR-0029
- 不实施 kernel migration → ADR-0030
- 不实施 plugin runtime → ADR-0024
- 不实施字段所有权矩阵 → ADR-0026

## 替代方案

| 方案 | 拒绝原因 |
|---|---|
| A · 三层 + placeholder Task | 把"未承诺的需求"伪装成 Task，制造幽灵 carrier，不解决概念倒置 |
| C · 统一 WorkItem(kind) | 长期 kind 分支会爆炸；语义清晰度不如两层 |
| D · Anchor pool 解耦 | 只解决"先立项才能解析"，不解决载体倒置 / Epic 重叠 |

详见 SP-A10 备忘 §3。

## 影响范围

### 替代
- **ADR-0017 v2** Epic Multi-PR materialization：`kind=epic` carrier 跑节点失效；breakdown draft 改绑 Requirement
- **ADR-0013** §D8 重新激活：7 节点只挂 SubTask + Requirement 独立表

### 显式吸收
- **ADR-0018** anchor runtime 模型（worktree / ccbd / tmux / Broker / WIP 配置化）保留，仅 subject 泛化

### Schema 改动
- 删 `Task.kind="epic"` / `Task.epicStatus` / `Task.materializationState` / `RequirementMaterialization` 表
- `Task.parentEpicId` → 直链 Requirement（或重命名为 parentRequirementId）
- `AnchorAllocation.boundEpicTaskId` → `subjectType / subjectId / mode`
- `EventJournal.taskId / taskKey` → `subjectType / subjectId / subjectKey?`
- 加 Requirement planning state 字段族（决策 6）

## 验收

- ADR-0023 增补章节落档（addendum 2026-05-19）
- ADR-0029 同步落档
- SP-B15 / SP-B20 实施可启动（schema 改完）
- 字段所有权矩阵 ADR-0026 后续跟进

## Risks

| # | 风险 | 缓解 |
|---|---|---|
| R1 | 旧用户失去 Epic 总览 | Requirement 总览 strip 替代（SP-B15 / SP-B20）|
| R2 | planning anchor 持久 → idle 堆积 | Broker 支持 hibernate / 心跳 |
| R3 | EventJournal 不泛化阻塞 reconcile / timeline | 决策 7 硬前置 |
| R4 | 需求内串行限制高级用户 | v1.1+ 独立并行指令；UI 明示"串行队列" |

## 协商证据

SP-A10 备忘 §15 / §16 / §17 / §18 / §协商证据。7 轮 codex consult job_id：

| 轮 | job_id |
|---|---|
| 1 | job_45f993ea6a89（路径 E 推荐）|
| 2 | job_91ef5291762e（sc-spec-panel 6 角度评审）|
| 3 | job_126668774bf1（节点哲学纠正）|
| 4 | job_4706242b2c92（范围对齐综合）|
| 5 | job_a3f78d7fef3d（SP-B15 设计）|
| 6 | job_3fa6833c221f（SP-B20 设计）|
| 7 | job_aeca5c6008c3（剩余 SP-B 处置）|

## 后续

- ADR-0030（SP-A11）论证节点 manifest / SKILL.md 改造形态
- ADR-0024 plugin runtime 按本 ADR 重新设计
- ADR-0027 EventJournal envelope 改 generic subject
- ADR-0026 字段所有权矩阵在 0028/0029/0030 后落档
