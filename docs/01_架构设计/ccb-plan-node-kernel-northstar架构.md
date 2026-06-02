---
doc_type: architecture
title: "CCB 协作协议内核 v0.4 Node Kernel 终态北极星"
updated: 2026-05-28
---
# CCB 协作协议内核 v0.4 — Node Kernel 终态北极星

> 状态：北极星草案（design 分支）
> 角色：v0.3.2 实施期的方向锚点。所有 v0.3.2 设计决策都必须能朝本文档收敛。
> 来源：v0.3.1（协议内核）+ Claude-Codex 4 轮协商（R1-R4）共识
> 最后更新：2026-04-28

---

## 0. 本文档的用途

v0.3.2 是**节点化的 thin facade**，目的是验证节点抽象。
v0.4 才是**节点化的最终公开心智模型**，统一所有 scheduler / skill / console。

本文档不规定 v0.4 的全部细节，只锚定 v0.3.2 期间不能违反的"长期方向"——避免做出"短期对、长期错"的兼容决策。

> **使用规则**：任何 v0.3.2 设计决策提出时，必须自检：
> - "这条决策朝 v0.4 收敛吗？" → 是 / 否
> - 答 "否" 必须在 v0.3.2 文档对应位置标注 `[v0.4-deprecation]`，说明何时拆除

---

## 1. v0.4 终态心智模型

### 1.1 一句话定义

CCB v0.4 = **节点状态机引擎 + 协议内核五件套 + 三方治理协作**。

LLM 的决策面只剩 **"下一个节点是什么"**；节点内一切（动作序列、插件绑定、子流程）都由 manifest 静态定义。

### 1.2 三层心智结构

```
┌──────────────────────────────────────────────────┐
│  L3 调度层（Scheduler）                            │
│  - SingleTaskScheduler   ←  /ccb:su-flow          │
│  - BatchScheduler        ←  批次自主              │
│  - ReactiveScheduler     ←  hook / resume 驱动    │
└────────────────────┬─────────────────────────────┘
                     │ select_next_node(state)
                     ▼
┌──────────────────────────────────────────────────┐
│  L2 节点引擎（Node Engine）                        │
│  - 7 个 canonical 节点                            │
│  - 节点 manifest = 节点真相源                      │
│  - 子流程必经 manifest 声明                        │
│  - 节点级 guard + transition + capability         │
└────────────────────┬─────────────────────────────┘
                     │ invoke_primitive(name, ctx)
                     ▼
┌──────────────────────────────────────────────────┐
│  L1 原语层（Primitives）                           │
│  - 15 个 mutation/coordination 原语               │
│  - 由节点 manifest 调用，对调度层不可见            │
│  - 所有写入走 primitive executor wrapper（CAS）    │
└──────────────────────────────────────────────────┘
```

**关键不变量**：
- L3 不能跳过 L2 直接调 L1
- L2 不能定义新 transition；只能 ref L0 全局 transition-table
- L1 不能写 batch_state；只能写 task_state（batch_state 由调度器维护）

### 1.3 与 v0.3.1 的本质差异

| 维度 | v0.3.1 | v0.4 |
|---|---|---|
| LLM 决策面 | 选下一个原语（24 选 1） | 选下一个节点（7 选 1） |
| 调度器数量 | 2 种（su-plan 固定 + su-agent ReAct） | 1 种节点引擎 + 3 种调度策略 |
| 真相源 | SKILL.md 散文 + 部分 references | 6 份 canonical 文件 + 7 份节点 manifest |
| 原语暴露 | 一等公民 | 节点内部机制（implementation detail） |
| consult 表达 | 原语级 ad-hoc | 节点 subflow 显式声明 |
| 插件绑定 | 运行时按 hint 查表 | manifest 静态声明 capability |
| 状态字段 | task_state + batch_state | + current_node + node_substate + runtime_state |

---

## 2. v0.4 终态节点列表（与 v0.3.2 完全一致）

| node_id | 中文 label | 入口源 | 出口去向 | 是否含 subflow |
|---|---|---|---|---|
| `requirement_analysis` | 需求分析 | 用户提需求 / Review 回退 | `technical_design` | consult subflow |
| `technical_design` | 技术设计 | requirement_analysis | `task_breakdown` | consult subflow |
| `task_breakdown` | 任务拆分 | technical_design / Review 回退 | `dispatch` | — |
| `dispatch` | 待派工 | task_breakdown | `implementation` | — |
| `implementation` | 执行实现 | dispatch | `review` | — |
| `review` | 评审验收 | implementation | `archive` / 回退到上游 | replan subflow |
| `archive` | 归档收尾 | review pass | 终态 | — |

**v0.3.2 → v0.4 节点列表零变化**。意味着 v0.3.2 写的 7 份节点 manifest 在 v0.4 不需要重命名或拆分。

---

## 3. v0.4 终态形态的关键决议（必须在 v0.3.2 期间被遵守）

### 3.1 manifest transitions 必须是 refs-only

**v0.4 终态**：
- 全局 `transition-table.md` 是唯一定义 transition 的地方（含 transition_id / source / target / trigger / guard_refs / state_effects）
- 节点 manifest 的 `transitions` 字段只能写 `{ transition_id, target_node }`
- 不能在 manifest 内重复 guard 或 trigger 逻辑

**v0.3.2 必须遵守**：写第一份节点 manifest 时就强制 refs-only，**禁止短期偷懒把 guard 直接 inline 在 manifest 里**——这是多真相源漂移的入口。

### 3.2 phase 字段在 v0.4 完全废弃

**v0.4 终态**：
- console DB schema 删除 `Task.phase` 列
- `Task.phase` 由 `currentNode + nodeSubstate` 派生（API 层导出，不存储）
- 看板列改用 `currentNode` 分组

**v0.3.2 必须遵守**：
- 加 `currentNode/nodeSubstate` 字段（additive migration）
- **必须** 把 `/api/tasks/:id` PATCH 的 phase 字段标 `deprecated`，禁止用户手写
- 看板暂保 phase 列布局，但每个卡片必须显示 node badge（让用户提前感知 node 即将成为真相源）

### 3.3 capability 三层 resolution 是永久结构

**v0.4 终态**：
- global / user / project 三层永久存在
- precedence: `project deny > project rank > user deny > user rank > global`
- 不会回退到"两层"或"单层"

**v0.3.2 必须遵守**：第一版 capability registry schema 必须支持 `deny` 字段（即使 v0.3.2 实际数据里只用 `rank`）。否则 v0.4 加 deny 会触发 schema 不兼容。

### 3.4 subflow 在 v0.4 允许 parallel_join

**v0.4 终态**：
- subflow `execution_mode` 可选 `sequential` / `parallel_join`
- parallel_join 必须显式声明 `branches[]` 和 `join_condition`
- 仍然不允许"隐式并发"或"节点内 task queue"

**v0.3.2 必须遵守**：
- node-manifest-schema.yaml 必须声明 `execution_mode` 字段，但 v0.3.2 期间 lint 规则限制只能取值 `sequential`
- 这样 v0.4 解锁 parallel_join 时只是放宽 lint，不是 schema 变更

**runtime scaffolding 已交付**（2026-05-08，ref e15 KA-1b · `runtime_scope: scaffolding`）：
- schema/lint 解锁来源：[E12.5 KA-1a](../../.ccb/specs/archive/2026-05-03-e12-5-ka1a-parallel-join-schema-lint.md)（branches/join_condition/done_when 必填 + 6 lint rule + 7 fixture）
- runtime scaffolding 来源：[E15 KA-1b](../../.ccb/specs/archive/2026-05-07-e15-ka1b-parallel-join-runtime.md)（SchedulerBranchState + intent contract + manifest-scan 解锁 + 4 fixture deterministic + done_when AST safe eval）
- contract: [parallel_join Runtime Contract RFC v0.1](2026-05-07-parallel-join-runtime-rfc.md)；模块规格: [parallel-join 模块规格](../../04_模块规格/ccb-plan/2026-05-08-parallel-join-runtime.md)
- lint warning 主 id 已改写为 `parallel_join_runtime_ready_v0.4_second_wave`（旧 id `parallel_join_runtime_not_ready` 仅 alias 元数据）
- **v0.5 follow-up**：real K1 调用 + branch step 实际并行执行（通过 `primitive_executor branch_context` 改造 + 9 类 EventJournal event payload 携带 branchSetId/branchId 解锁）

### 3.5 节点引擎吃掉 su-plan / su-agent 的差异

**v0.4 终态**：
- `/ccb:su-plan` 和 `/ccb:su-agent` 合并为 `/ccb:su-flow`
- 用户体验差异通过 `policy_profile` 切换（interactive-single vs autonomous-batch）
- 不再维护两套 scheduler 代码

**v0.3.2 必须遵守**：
- v0.3.2 期间 `/ccb:su-plan` 仍然保留，但其内部实现必须**已经**通过节点 manifest 驱动（thin facade over 3 节点：requirement_analysis → technical_design → task_breakdown）
- v0.3.2 不要新增 `/ccb:su-agent` 命令；如果需要批次自主，先用 `/ccb:su-plan + policy_profile=autonomous-batch` 做实验
- 这样 v0.4 合并到 `/ccb:su-flow` 时只是更名，不是逻辑迁移

### 3.6 4 + 2 = 6 份 canonical 在 v0.4 不增不减

**v0.4 终态**（最终冻结清单）：
1. `state-schema.yaml`
2. `primitive-executor-contract.md`
3. `guard-registry.md`
4. `transition-table.md`
5. `capability-registry-schema.yaml`
6. `node-manifest-schema.yaml`

**v0.3.2 必须遵守**：v0.3.2 期间不创建第 7 份 canonical。如果在写作过程中发现需要新增（譬如 "subflow-schema.yaml"），先评估能否塞进现有 6 份；不能就先停下来重新协商，**不要在 v0.3.2 静默扩充**。

### 3.7 reactive scheduler 在 v0.4 第二波交付

**v0.4 v1 不实现 ReactiveScheduler**，但 v0.4 v1 实现 Event Journal / event schema integration：Console 持久化 `reactive-event-v1` 的事件投影，按 `event_id` 去重，并供 Console timeline 与后续 A2/A3 接入。

Event Journal 只记录 observed workflow fact，不消费 transition，不写 task_state / batch_state，不触发 scheduler。

**v0.4 second-wave** 才实现 ReactiveScheduler。ReactiveScheduler 必须通过 kernel-level event-store contract 读取事件，不直接读取 Console DB table。

> **交付状态（2026-05-06）**：✅ 已交付 (ref E14, ADR-0011)
>
> - **RFC**: [`docs/01_架构设计/ccb-plan/2026-05-06-reactive-scheduler-contract-rfc.md`](2026-05-06-reactive-scheduler-contract-rfc.md)（pass 8.29 R4）
> - **ADR**: [`docs/.ccb/decisions/ADR-0011-ka2-reactive-scheduler.md`](../../.ccb/decisions/ADR-0011-ka2-reactive-scheduler.md)（9 项关键决策 + 替代方案档案）
> - **核心实施**: `apps/ccb-console/server/src/modules/scheduler/`（E14-T1 pass 8.6 + E14-T2 pass 8.3 + E14-T4 multi-phase fixture pass 8.2 R2）
> - **公开入口**: `/ccb:su-flow` SKILL.md 升级（E14-T3 pass 8.4，policy_profile 持久 2 档 + autonomous-batch 解锁）
> - **测试基线**: scheduler suite 51 + handlers/proposal/consumption ≈ 84 + replay 6 = 全量 server 246/246 green
> - **待续**: T5/T6 dogfooding 真任务实战覆盖多 phase resume + clearPause；模块文档（docs/04_模块规格/）由 codex 后续起草

---

## 4. v0.4 显式废弃清单（v0.3.2 兼容期满后删除）

| 废弃对象 | 废弃原因 | v0.3.2 处理 | v0.4 终态 |
|---|---|---|---|
| `Task.phase` 列 | node 成为真相源 | 标 deprecated，仍写入 | 删除列 + 删除 PATCH 字段 |
| `phase` API 入参 | 同上 | PATCH 拒绝写入，GET 仍返回 | 完全删除 |
| `/ccb:su-agent` 命名 | 与 su-plan 合并 | v0.3.2 不新增 | 命名为 `/ccb:su-flow` |
| `analysis_depth_hint → /sc:*` 动态映射 | capability 取代 hint | v0.3.2 仍保留 hint，但优先 capability | 删除 hint，仅用 capability |
| `transition_invariants` 散文 | 由 transition-table.md 表达 | v0.3.2 文档双写（散文 + 表） | 仅保留表 |
| SKILL.md 内的工作流 prose | 由 manifest 表达 | v0.3.2 改为引用 manifest | 删除 prose |

---

## 5. v0.4 不会做的事（避免范围漂移）

以下项目**不在 v0.4 范围**，避免 v0.3.2 期间为它们预留接口：
- 节点可视化设计器（node designer UI）
- 多 worker 并行执行（一个 task 同时跑两个 codex session）
- 跨项目的 batch scheduler
- 节点 manifest 的运行时热加载
- capability 的自动发现 / 自动测试
- 用户自定义新节点（节点是协议级 canonical，不开放扩展点）

如果 v0.3.2 期间冒出对上述能力的需求，先记录为 "v0.5 候选"，**不要在 v0.3.2 或 v0.4 设计中预留接口**。

---

## 6. v0.3.2 → v0.4 演进路线图

```
v0.3.2 (thin facade)
  ├─ 6 份 canonical 冻结
  ├─ 7 份节点 manifest 落地（refs-only transitions）
  ├─ su-plan 改为节点驱动，其他 skill 改为 thin facade
  ├─ capabilities/global.yaml 初始数据
  ├─ console 加 currentNode/nodeSubstate 字段（API + 卡片 badge）
  ├─ requirement_analysis 垂直切片跑通（manifest lint + simulator + real run）
  └─ 项目级 capabilities.project.yaml scaffold
            │
            ▼ 跑过 ≥3 个真任务，反馈收敛后
v0.3.3 (consolidation)
  ├─ console 加 archived 视图 + node 转移历史
  ├─ hook 触发的 console 自动刷新
  ├─ user-layer capability registry 引导命令
  ├─ manifest lint 工具发布
  └─ 完整 7 节点切片全部跑通
            │
            ▼ 节点抽象稳定后
v0.4 v1 (full kernel, event integration)
  ├─ /ccb:su-plan + /ccb:su-agent 合并为 /ccb:su-flow
  ├─ Event Journal / event schema integration（codex_receipt_ready first slice）
  ├─ phase 列删除时间表另行锁定
  ├─ subflow parallel_join 解锁  ← ✅ runtime scaffolding 已交付 2026-05-08 (ref e15)
  ├─ NodeRun timeline + capability status matrix
  └─ analysis_depth_hint 完全删除

v0.4 second-wave / A-scheduler
  └─ ReactiveScheduler 实现（事件驱动）  ← ✅ 已交付 2026-05-06 (ref e14)
```

---

## 7. v0.4 不会回答的开放问题（留给 v0.5+）

- 多 worker 编排（如何让 codex + opencode 同时处理一个 task 的不同切片）
- 跨项目 capability 共享
- 节点 manifest 的版本管理与回滚
- 节点引擎的可观测性 SDK（OpenTelemetry 集成等）

这些问题不在 v0.4 解决，但 v0.4 的设计**不应该让它们变得更难**——譬如 capability registry 的 schema 应该天然支持 cross-project 引用，但 v0.4 不消费这个能力。

---

## 8. 与 v0.3.1 的关系

- v0.3.1（协议内核草案）= **L1+L2 概念基础**
- v0.4（本文档预言的终态）= **公开心智模型 + 6 份真相源**
- v0.3.2 = **从 v0.3.1 走向 v0.4 的第一步**

v0.3.1 的所有 governance / async / red_flag / idempotency 硬规则在 v0.4 全部保留；只是"原语级表达"在 v0.4 收敛到"节点 manifest 表达"。

---

## END

*本文档是 CCB v0.4 的方向锚点。任何 v0.3.2 设计决策出现"是否会让 v0.4 难以收敛"的疑问时，回到本文档对照。*
