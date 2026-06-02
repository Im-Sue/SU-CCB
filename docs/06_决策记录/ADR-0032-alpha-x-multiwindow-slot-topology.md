---
id: ADR-0032
title: Console Plugin · ccb 7.0 Multi-Window Topology + α-X Worktree 模型
status: active
decided_at: 2026-05-23
last_updated: 2026-05-23
decider: 用户（4 轮 codex 协商后拍板核心方向）+ Claude（实施细节 + 拍板 prerequisites/data model/ownership）
reviewer: ccb_codex（round 1-4 设计协商 + round 5 outline audit rep_e59a8a3ace7d）
codename: alpha-x-multiwindow-slot-topology
related_doc:
  - docs/02_需求设计/ccb-plan/2026-05-23-phase5-issue2-alpha-x-worktree-model-conclusion.md
  - docs/.ccb/requirements/active/2026-05-23-phase5-v1x-governance-enhancement.md
parent_adrs:
  - ADR-0023
  - ADR-0024
supersedes:
  - ADR-0018
amends:
  - ADR-0023
prerequisite_adrs:
  - ADR-0024
consult_evidence:
  - job_f340e24f8913   # round 1 治理根因
  - job_c53fa0f0dedd   # round 2 模型选型 α/β/γ/δ
  - job_a3369bdcde38   # round 3 α 工程可行性 X/Y/W
  - job_38bcb48dba37   # round 4 ccb 7.0 形态
  - job_abb3a8830b74   # round 5 outline audit
upstream_reference: github.com/bfly123/claude_codex_bridge v7.0.3
impacted_components:
  - apps-ccb-console-server
  - apps-ccb-console-web
  - claude-plugin-distribution
  - codex-skills-distribution
  - docs-ccb-workspace
---

# ADR-0032: Console Plugin · ccb 7.0 Multi-Window Topology + α-X Worktree 模型

## Status

Accepted（2026-05-23）。基于 4 轮 codex consult 协商（job_id 见 `consult_evidence`）+ 用户 2026-05-23 拍板核心方向 + round 5 outline audit。

## Context

v1.0 plugin sovereignty 发布次日（2026-05-23），用户触发 requirement `cmph5nd2va01cb8b41e07ae88` 的 "AI 解析" 操作时，Console UI 投影未亮起。深入 4 轮 codex 协商后确认：

1. Console 现行 `anchor-broker` + per-subject worktree 与 ccb v7.0.3 upstream 设计**根本不符**。upstream 把 worktree 设计为 per-agent opt-in（git branch 工作流），Console 改造为 per-subject 强制 + 无 merge/promote 流程。
2. ccb v7.0.3 原生提供 multi-window topology + workspace_mode 三档 + queue_policy 内层串行。
3. 沿 per-subject worktree 走会让 canonical artifact root 歧义持续恶化（"AI 写之前先知道 artifact 属于哪个 root" 即根因）。

用户拍板核心方向为 **α-X 模型** = single project ccbd + 静态 agent pool + subject/job routing。

## Decision

### 1. ccb 7.0 Multi-Window Topology

**1.1 Single Project ccbd**：整个项目运行**唯一一个** ccbd 实例，由 ccb 7.0 OwnershipGuard + file lock + socket bind 排他保证。废止 per-subject 独立 ccbd（ADR-0018 决策 1）。

**1.2 Static 5-Slot Topology**：固定 6 个 window —— `main` + `slot-1..slot-5`。N=5 是**硬数字**，改 N 需要起新 ADR + ccb config topology 重建，不接受 env var / runtime config 调整。

**1.3 Canonical Root = Inplace**：所有 canonical artifact（需求 md / spec / state / draft / EventJournal）只在主仓项目根，所有 slot 共享同一 cwd。`workspace_mode = inplace`。废止"artifact 属于哪个 root"的歧义。

**1.4 Worktree = Opt-In Non-Canonical**：git worktree 不再是 slot 模型必要组成，仅在 opt-in 代码隔离场景启用，产物**不进 canonical root**。废止 `git-worktree.service` 强制每需求 worktree（ADR-0018 决策 4）。

### 2. Slot Binding 状态机 + Sticky 约束

**2.1 状态集合**：`idle` / `bound` / `busy` / `unhealthy` / `recovering` / `draining`（项目级 `queued` 是 Console 外层 queue 而非 slot 自身状态）。

**2.2 Sticky 约束**：需求 ↔ slot 绑定一旦建立，**不可被其他需求抢占**。释放仅两种触发：(a) 需求归档自动 `draining → idle`；(b) UI 显式释放，busy slot 默认禁止释放，需 cancel job 或 force release 二次确认。

**2.3 持久化**：binding 持久化在 Console SQLite（`SlotBinding` entity，详见 Data Model 4.1），**不在** ccbd / pane / tmux 内存态。Console / ccbd 重启后从 DB 恢复。

### 3. `.ccb/ccb.config` 所有权 = Console 托管

ccb 上游把 `.ccb/ccb.config` 视为 user-authored project config，但 α-X 要求严格 topology（main + 5 slot + 12 stable agent 名），用户手抄易错。

**Console 生成 + 托管**：首次启动检测缺 config → 自动生成 managed 版本；后续启动检测 **core 字段**（windows / agents / workspace_mode）漂离 managed schema → 弹通知 + diff 展示 + 二次确认后恢复。**non-core 字段**（log path / colorscheme 等）保留用户改动。升级 ccb 版本时 Console 自动 migrate。

废止旧 anchor-template **静默覆盖**（无通知 / 无确认）。

### 4. Main Window 非业务承载

`main` window **不绑需求**，永远不进 binding queue。承载 ADR / 设计文档起草、`/ccb:su-reconcile` 跨需求扫描、跨需求 review / 派工 / 调度、用户人工 debug。避免 main 退化为隐形第 6 个需求 slot。

### 5. ADR-0024 作为实施强制前置

ADR-0032 实施**强制依赖** ADR-0024 plugin primitive runtime（CAS / lock / EventJournal append）落地完成。理由：5 slot 各跑 AI agent 时多个 slot 会写同一 canonical artifact，无 CAS / Lock 必发生 race。详见 Prerequisites 段。

## Data Model

### 4.1 SlotBinding entity（新增）

Console SQLite 新增 `SlotBinding` 表，字段语义：

- `projectId` / `slotId`（取值 `slot-1..slot-5`，main 不入此表）
- `requirementId`（当前绑定的需求；NULL = idle）
- `state`（见 Decision 2.1 状态集合）
- `boundAt` / `releasedAt` / `lastActivityAt`
- `history`（历史绑定 JSON 列表）
- 唯一约束：`(projectId, slotId)`

**Owner = `console-internal`**（ADR-0026 字段所有权）。写入路径**只走** Console operational API（UI 派工 / 归档释放 / 用户显式释放），**不进 requirement md**。

`Requirement.planningAnchorId` 等既有字段保留为兼容投影，新代码统一用 `SlotBinding`。

### 4.2 Stable Naming Contract

| Window | Agent Names | 实例数 |
|---|---|---|
| `main` | `ccb_claude` / `ccb_codex` | 2 |
| `slot-N`（N=1..5）| `slotN_claude` / `slotN_codex` | 5 × 2 = 10 |
| **Total** | | **12** |

agent 名跨 window 不可重复（ccb 7.0 `topology.py` 硬约束）。命名 stable，禁运行时变更。

### 4.3 `anchorId` 字段语义重定义（不 rename）

ADR-0018 决策 7 引入的 EventJournal `anchorId` 字段**沿用名**：

- α-X 前：物理 anchor id（per-subject worktree + 独立 ccbd）
- α-X 后：**runtime locus id**，取值 `main` / `slot-1..slot-5`
- API view 增加 computed `slotId = anchorId`
- `anchorId` 标 **deprecated semantic alias**，新代码统一用 `slotId`
- 不做 prisma migration（避免破坏既有 EventJournal 数据）

## Slot Lifecycle & Recovery

**启动恢复**：Console 启动 → 读 `SlotBinding` 表恢复 N=5 slot 当前 state + 与 ccb 7.0 startup-report 双向校验。

**ccbd 进程退出** → Console 检测 socket lost → 所有 slot 标 `recovering` → 尝试重启 ccbd。

**单 slot pane / provider degraded** → 该 slot 标 `unhealthy` → **不自动归档需求** + UI 提示用户介入。

**Console 重启** → SQLite 持久化保证 binding 不丢，恢复后从 DB 读。

**Cross-slot 通信**：仅允许 ccb 原生 agent name `ask` / `--callback`；canonical write 必走 ADR-0024 lock/CAS；**禁止**通过未加锁文件共享绕过协议。

## Prerequisites

**ADR-0024 必须先 ready**。任何会**写 canonical md/json** 的链路（"AI 解析" / `/ccb:su-flow` 节点推进 / breakdown-draft 写入 / spec materialize / state transition）不得先于 ADR-0024 CAS / lock / EventJournal append 完成。

实施序约束：
- 拓扑落地（Decision 1 + Decision 3）**可先于** ADR-0024
- canonical write 路径**不得先于** ADR-0024

**ccb 7.0.3+ 升级已完成**（2026-05-23 验证 `ccb --version` = v7.0.3 4d13160）。

## Risk & Guardrails

- **ADR-0024 未 ready 启用 canonical write** → CI 强制 fail-on：canonical write 模块未 import ADR-0024 runtime hooks
- **Console 静默覆盖用户 config** → core 字段恢复必须弹通知 + diff + 二次确认
- **slot crash 误归档需求** → `unhealthy` ≠ `archive`；恢复策略仅标 unhealthy + 等手动
- **跨 slot 未加锁文件共享** → lint：plugin 直接 `fs.writeFile` canonical 文件 → CI fail
- **`anchorId` 被新代码当物理 anchor 用** → API computed `slotId` + `@deprecated` annotation + lint warning
- **N=5 被 env var 改动** → runtime config 全部 ignore；只读 ccb.config 静态值

## Consequences

### 模块映射

| 模块 | 当前实施 | α-X 目标态 |
|---|---|---|
| `anchor-broker` | per-subject worktree + 独立 ccbd | `project-ccbd-manager`（单 ccbd 生命周期） |
| `ccbd-launcher` | per-anchor 启动 | 项目级单次启动 |
| `anchor-dispatch-worker` | per-anchor dispatch | `job-slot-router`（按 slotId 路由） |
| `queue-router` | 跨 anchor 队列 | Console 外层 requirement→slot queue + sticky binding |
| `ANCHOR_WIP_CAPACITY=2` | 物理 anchor 上限 | N=5（slot 数量，硬数字） |
| `git-worktree.service` | 每需求强制 worktree | 仅 opt-in 非 canonical 代码隔离 |

### 两层 Queue 区分

- **外层** · Console requirement → slot queue：6th+ 需求等空 slot；FIFO + sticky binding。**Console operational 实现**。
- **内层** · ccbd per-agent queue：同 slot 内多 job 串行；`queue_policy = SERIAL_PER_AGENT`。**ccb 7.0 原生**。

### UI 双层结构

- **ccb 7.0 原生 sidebar**：物理 window + agent pane 状态
- **Console UI 自有 sidebar**：业务映射（"需求 ABC ↔ slot-3" / "需求 XYZ ↔ queued"）+ 用户操作入口

符合 ADR-0023 决策 2「Console 退为展示 + 投影」。

### ccb 7.0.3 硬约束速查

| 维度 | 事实 |
|---|---|
| ccbd 单例 | file lock + socket bind 排他 |
| windows / agent / agent name / sidebar | 进 topology signature，启动锁定 |
| workspace_mode | inplace / git-worktree / copy，α-X 强制 inplace |
| queue_policy | SERIAL_PER_AGENT / REJECT_WHEN_BUSY，默认 `SERIAL_PER_AGENT` |

## Alternatives Rejected

### 模型层（4 轮协商收敛）

| 候选 | 拒绝理由 |
|---|---|
| **β** · per-subject canonical root + project-broker | "AI 写之前先知道 artifact 属于哪个 root" 正是本案根因 |
| **γ** · hybrid | 复杂度叠加 β + α 无明显收益 |
| **δ** · auto-merge worktree | merge 失败 / 冲突 / dirty state 藏进 runtime，长期更黑 |

### α 子候选

| 候选 | 拒绝理由 |
|---|---|
| **α-Y** · 每需求新 fork ccbd | 要改 project identity / runtime root / provider state |
| **α-W** · per-need window 动态 spawn | layout signature 变化要重建 namespace，ccb 7.0 不支持运行时热加 pane |

### 数据模型 / 配置所有权

| 候选 | 拒绝理由 |
|---|---|
| slot 信息塞进 `Requirement` 既有字段 | 看 slot 全局 = 扫所有 Requirement；slot 历史 / 恢复 / 审计无处存 |
| `.ccb/ccb.config` 用户自管 + Console 校验 | 12 agent 名 + N=5 + workspace_mode 用户记不住；ccb 升级时迁移成本压给用户 |

## Supersedes

**ADR-0018**（task anchor runtime）：

- 决策 1-6 + Addendum F6-A1（2026-05-14 direct_pr orphan subtask 独立 anchor 例外）+ Anchor 状态机 9 态大部分 → **全废**
- 决策 7（EventJournal 集中 + anchorId 维度）→ **保留**（`anchorId` 语义重新定义为 runtime locus id，详见 Data Model 4.3）
- Addendum 2026-05-16（Anchor Terminal Read-Write Attach）→ **保留机制**：pane writer lease / 二次确认 / 审计不变；key 由 `<anchorId>:<pane>` 改为 `<projectId>:<slotId>:<agentName/pane>`；审计路径同步

## Amends

**ADR-0023**（plugin sovereignty）：

- **决策 2** Console 职责中"物理资源"部分：per-anchor → per-project-ccbd + slot management（决策本体不动）
- **决策 5** ADR-0018 注释："anchor 模型完整保留" → "anchor 模型由 ADR-0032 替换；EventJournal + read-write attach 子模块保留"
- 决策 1 / 3 / 4 / 6 + Addendum 2026-05-19（AI Orchestrator + Capability Registry）**不动**

## Related

- **ADR-0024** plugin primitive runtime（实施前置，见 Prerequisites）
- **ADR-0026** entity field ownership v1.0（`SlotBinding` owner = console-internal）
- **ADR-0027** EventJournal v1.0（需新增 5 个 event types：`slot_bound` / `slot_released` / `slot_queued_request`（替代 deprecated `anchor_dispatch_queued`）/ `slot_runtime_degraded` / `slot_recovered`）
- **Phase 5 议题 1** plugin 状态字段 flag 治理（待本 ADR + ADR-0024 落档后启动）
- **Phase 5 议题 3** docs/ 命名规范（独立 ADR-0033，与本 ADR 解耦）
- **Phase 5 议题 4** 任务拆分粒度治理（独立讨论）

## 协商证据

`consult_evidence` 列出 5 个 codex consult job_id：round 1-4 设计协商（4 轮收敛 α-X 模型，详见 conclusion 文档）+ round 5 outline audit (rep_e59a8a3ace7d) 补 SlotBinding data model + lifecycle/recovery + `.ccb/ccb.config` ownership + 两层 queue 区分 + main 不绑业务等关键缺口。

完整时间线见 conclusion 文档与 EventJournal `consult_reply_received` 事件。

## 后续

- 实施排期由用户启动；Phase A-F 分批 PR：Topology → SlotBinding → EventJournal → Canonical Write（待 ADR-0024）→ UI 双层 → Cleanup
- 详细实施 spec（`SP-ADR0032-impl`）由 Codex 起草

## Addendum 2026-05-23 · Slot Stale / Busy 释放策略

实施前 deep review（job_b57c8a7b45d4 / rep_c1dc75279abb）发现 Decision §2 sticky 释放**只有** "UI 显式释放 + 归档" 两种条件，**缺失** "长期 busy 但不归档" 的处理。

### 问题

ADR-0032 决策 2.2 释放条件：
- 需求归档 → draining → idle
- UI 显式释放 + busy slot 二次确认

**漏点**：用户开了需求但**长期不动它**（既不 archive 也不显式 release），slot 被半死需求占住。**5 个 slot 容易被半死需求耗尽**，新需求长期 queue。

### 修订 · 第三类释放（stale 检测）

新增 slot 状态机辅助维度：

| 状态 | 触发 | 自动行为 | 用户行为 |
|---|---|---|---|
| **stale** | bound 但 N 天（默认 7d）无 capability outcome 活动 | UI 标 stale + hook 通知 | 用户决定：续期（reset 计时） / 显式 release / 归档 |
| **busy timeout** | busy 状态超过 M 小时（默认 4h）无 outcome 完成 | 标 unhealthy（已有概念，加 timeout trigger）+ hook 通知 | 用户决定：cancel 当前 job / wait / force release |

**关键不变量保留**：
- stale / busy timeout **不自动归档需求**（保留 ADR-0032 决策 5.2 "unhealthy ≠ archive" 规则）
- 释放仍需**用户显式行动**（不自动 release）
- 通知机制走 hook（ADR-0023 决策"hook = 外部通知通道"）

### 配置项

`docs/.ccb/config/slot-stale-policy.yaml`（待 `SP-ADR0032-impl` 起草）：

```yaml
stale_threshold_days: 7         # 默认 7 天
busy_timeout_hours: 4           # 默认 4 小时
notification_channel: hook      # 走 hook 适配 email / slack 等
```

项目可 override 默认值。

### 影响

- `SP-ADR0032-impl` 实施期实施 stale 检测后台任务（Console operational）
- `SlotBinding` entity 已有 `lastActivityAt` 字段，补 `stale_detected_at` / `stale_notified_count`
- 跟 ADR-0035 outcome_contracts 关联：每个 outcome apply 时更新 `lastActivityAt`
- 通知 channel 走 ADR-0031 anchor-dispatch 结构化 payload 协议（hook 调用方）

### 协商证据

实施前 deep review job_b57c8a7b45d4 / rep_c1dc75279abb 由 codex 独立 audit 提出该 slot 释放漏点。Claude 接受为 ADR-0032 必填 amend。
