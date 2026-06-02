---
id: ADR-0023
title: Plugin Sovereignty and Console Projection Boundary
status: active
decided_at: 2026-05-17
last_updated: 2026-05-17
decider: Claude (with user authorization)
reviewer: ccb_codex (6 rounds consult)
clean_start: true
codename: plugin-sovereignty
related_doc: docs/01_架构设计/ccb-plan/2026-05-17-v1.0-plugin-sovereignty.md
consult_evidence:
  - job_cce8bd55182a  # round 1 baseline
  - job_f2f425747d01  # round 2 infrastructure
  - job_2c53550e11d0  # round 2 verbatim patch
  - job_169ff6d00b99  # round 3 tech stack + UI buttons
  - job_60a01c53558c  # round 4 risks
  - job_479b6557503d  # round 4.5 reconcile logic
  - job_3ea2d6009b2b  # round 5 deliverables
  - job_797f7337ed4d  # round 6 clean-start simplification
supersedes_as_normative_baseline:
  - ADR-0001  # self-built engine (有效定位被本 ADR 吸收)
  - ADR-0010  # su-flow facade (入口语义被本 ADR 吸收)
  - ADR-0011  # ReactiveScheduler (Console driver 语义失效)
  - ADR-0012  # task projection consistency (被新真相源模型覆盖)
  - ADR-0014  # ProjectionOutbox worker (DB→file 方向冲突，ProjectionOutbox 在 v1.0 不存在)
  - ADR-0017  # epic multi-pr materialization (模型保留，draft 写入路径替代)
  - ADR-0018  # task anchor runtime (anchor 模型被本 ADR 吸收)
  - ADR-0019  # field ownership (被 ADR-0026 完全替代)
new_companion_adrs:
  - ADR-0024  # plugin-side primitive runtime + md-first
  - ADR-0025  # AI-native reconcile + diff log
  - ADR-0026  # entity field ownership v1.0
  - ADR-0027  # EventJournal v1.0
impacted_components:
  - apps-ccb-console-server
  - apps-ccb-console-web
  - claude-plugin-distribution
  - codex-skills-distribution
  - docs-ccb-workspace
deprecated_in: null
removed_in: null
grace_window: null
---

# ADR-0023: Plugin Sovereignty and Console Projection Boundary

## Status

Accepted（2026-05-17）。基于用户 2026-05-17 提出的系统定位重定位 + 6 轮 Claude / ccb_codex consult 协商 + 用户明确"全新接入"授权。

## Context

v0.3.2 实施期把节点工作流的执行权固化在 Console server 内（ReactiveScheduler、transition-consumer-wrapper、breakdown-draft API、ProjectionOutbox），形成 Console driver 与 anchor ai cli driver 的**事实双轨**。具体表现：

1. Task 表的 `currentNode / runtimeState / status` 等字段在 prisma schema 中标注为 projection-only，但 Console 服务实际在写入这些字段（违反自己的 schema 承诺）
2. 同一语义动作（如 transition apply）可由 Console HTTP route、scheduler tick、或 plugin skill 三处触发
3. plugin 已存在的"直写"例外（`su-approve` 写 state frontmatter、`requirement-reanalyze` 写 requirement md）暗示了 plugin 主权的早期试水

用户 2026-05-17 提出：

> 整套系统应该 Plugin 或者 skills 驱动 db、md 的状态和业务流程的流转而不是由 UI 系统，UI 系统是展示层。UI 上的操作性、决策性、状态流转的按钮和交互本质上应该是触发 Anchor 的 ccb 里的 ai cli 的指令。

并授权 v1.0 是**全新接入**：不需要兼容旧数据，可以完全清空数据库重启。

## Decision

### 决策 1 · 业务主权完全归 Plugin / Skill

L3 主权层位于 anchor 内 ai cli 跑的 plugin / skill。**唯一负责**业务节点状态机推进（requirement_analysis → archive 全链）、transition apply、materialize、cancel、review、approve、replan、derive、reconcile。

### 决策 2 · Console 退为展示 + 投影 + 物理资源 + 远控代理

Console server 在 v1.0 **不再做业务推进**。保留职责：

- Anchor 物理生命周期：start / stop / reset / worktree cleanup
- File watcher + indexer：监听 docs/.ccb/state/、刷新 sqlite projection
- EventJournal collector：接收跨 anchor 事件、提供查询 API
- Broker：路由 ask / cancel / queue / trace
- AI CLI 远控代理：让 UI 按钮能发指令到指定 anchor
- Operational 字段 CRUD：priority / 用户关联字段 / settings

### 决策 3 · UI 按钮语义二分

UI 上 25 个交互按钮分两类：

- **决策类 / 业务流转类**（18 个）：语义 = 发送 ai cli 指令到 anchor，UI 显示 pending / queued / running / completed / failed
- **Operational 类**（6 个）：调 Console API 直驱（启动 anchor、worktree 管理、UI 队列 CRUD）

假按钮（UI 上有但后端无 handler）在 v1.0 接通或删除。

### 决策 4 · v1.0 不保留第二写入网关

**禁止保留 `CCB_WRITE_DRIVER=plugin|console-fallback|mixed` 这类 fallback 开关**。理由：用户授权全新接入，无需兼容旧路径；保留 fallback 会让 Console 直写长期残留为第二主权轨。

严重 runtime bug 的兜底**不是** reconcile（reconcile 同样依赖 runtime），而是：
1. 停止写入
2. 保留 md / EventJournal 已有证据
3. 回滚 / 修复 plugin runtime 版本
4. 重跑 `/ccb:su-reconcile`

### 决策 5 · 8 份老 ADR 标记为已被替代作为 normative baseline

frontmatter `supersedes_as_normative_baseline` 列出 8 份老 ADR。它们作为决策历史保留，但**实现细节不再约束 v1.0 行为**。

本 ADR 显式吸收以下老决策的有效定位：

- **ADR-0001 的自研引擎定位**：v1.0 仍然自研工作流引擎；只是引擎的**物理实现位置**从 Console server 迁到 plugin runtime
- **ADR-0018 的 anchor runtime 模型**：WIP=2、每 epic 独立 anchor、orphan subtask 例外、Broker 跨 anchor 路由、anchor 主格三槽 (cmd + ccb_claude + ccb_codex) **完整保留**
- **ADR-0010 的 su-flow facade 入口语义**：`/ccb:su-flow` 仍是 SingleTaskScheduler 的公开入口；只是 scheduler 实现位置从 Console 迁到 plugin

### 决策 6 · 全新接入（Clean Start）

v1.0 上线时完全清空 Console SQLite 与所有 task / spec / draft / state / report / reconcile 文件。保留 ADR 历史、templates、index、kernel reference、knowledge base 主目录。用户作为第一个全新接入用户从初始化到完整流程跑一遍 v1.0。

## 非目标（明确不做）

- 不修改 CCB 底层协议（不动 ccbd JSONL fsync、不改通信内核）
- 不做旧数据迁移（用户授权 clean start）
- 不保留 Console 业务直写 fallback
- 不实现多 worker 并行执行同一 task
- 不实现节点 manifest 热加载
- 不在 v1.0 首发做 diff log 自动归档（预留目录给 v1.1+）

## 替代方案

| 方案 | 核心差异 | 拒绝原因 |
|---|---|---|
| A · 维持双轨 + Console 作为受控写入网关 | plugin 仅触发，Console 仍写 db / md | 不符合用户"plugin 驱动 db/md"的根本主张；schema 偏移持续 |
| B · plugin 直写 + 保留 Console fallback 长期共存 | 两条主权轨并存，按 feature flag 切换 | 会让 Console 直写永久残留为第二主权轨；schema / 行为漂移 |
| C · 用 Rust / Go 独立 runtime 不与 Console 同栈 | plugin runtime 完全独立 | schema drift 严重；v1.0 不必要的工程复杂度 |
| D · 不做 v1.0 重定位，继续 v0.3.2 偏移演进 | 接受现状双轨 | 用户已明确主张和大版本变更意愿；偏移会持续扩大 |

## 影响范围

### 替代

- ADR-0014 ProjectionOutbox：**在 v1.0 不存在**（不只是 superseded，是物理删除）
- ADR-0011 Console ReactiveScheduler 作业务推进：失效
- ADR-0017 v2 "draft canonical = Console API 写入"：失效，draft 写入由 plugin runtime 完成
- ADR-0019 字段所有权 DB-owned 主导：由 ADR-0026 完全替代

### 显式吸收（前述决策 5）

- ADR-0001 自研定位
- ADR-0018 anchor runtime 模型
- ADR-0010 su-flow facade

### 新增

- Plugin-side Primitive Runtime（ADR-0024）
- `/ccb:su-reconcile` skill + diff log 契约（ADR-0025）
- 字段所有权矩阵 v1.0（ADR-0026）
- EventJournal v1.0 9 个新事件（ADR-0027）
- UI Action Routing Matrix（待落档模块文档）

### Lint / CI

- Console PATCH 改业务状态字段：CI 强制禁止
- plugin 直接 sqlite SQL（绕过 runtime）：CI 强制禁止
- ProjectionOutbox 模块：源码删除

## 验收

v1.0 上线时：

- Console SQLite 与 docs/.ccb/{state,specs,drafts,reports,reconcile}/ 完全清空
- ProjectionOutbox 模块代码已删除
- Console 内 transition-consumer-wrapper / scheduler 业务推进逻辑已删除
- plugin runtime（ADR-0024）已分发，contract test 通过
- UI 25 个按钮按本 ADR 决策 3 分类完成迁移
- 用户从初始化（`/ccb:su-init`）跑一遍完整节点链（requirement → archive），不依赖任何 Console 业务写网关
- `/ccb:su-reconcile`（ADR-0025）可被 UI 按钮触发并完成全扫自修
- 严重 runtime bug 演练：runtime 回滚 + 重跑 reconcile 能恢复正常

## 关联

- 主文档：`docs/01_架构设计/ccb-plan/2026-05-17-v1.0-plugin-sovereignty.md`
- 配套 ADR：ADR-0024 / ADR-0025 / ADR-0026 / ADR-0027（依赖本 ADR 拍板才可起草）
- v0.4 北极星：`docs/01_架构设计/ccb-plan/v0.4-node-kernel-northstar.md`（七节点结构保留；scheduler 物理位置由本 ADR 重定位）

## 协商证据

frontmatter `consult_evidence` 列出 8 个 codex consult job_id。每轮回执存于 EventJournal `consult_reply_received` 事件。完整时间线见主文档第"协商证据"节。

## 风险

1. **runtime 严重 bug 时无 Console fallback**——按决策 4 已明确以"回滚 + reconcile"处理，但首版 runtime 必须 contract test 严格
2. **plugin / kernel / Console 版本漂移**——必须强 pin runtime contract、kernel hash、prisma schema 一致性测试
3. **anchor busy 模型未细化**——manual_attached / command_inflight / ai_busy / idle_dirty 状态机需在 v1.0 首发前在 ADR-0024 或独立模块文档明确

## 后续

- ADR-0024 / 0025 / 0026 / 0027 起草后，本 ADR 与四份配套 ADR 一并锁定为 v1.0 normative baseline
- 实施前必须完成的最小文档集：本 ADR + ADR-0024 + ADR-0026 + ADR-0027
- 实施期由用户决定启动时机（用户明确"等我搞完手头工作再考虑真正实施"）

## Addendum: AI Orchestrator + Capability Registry 哲学（2026-05-19）

ADR-0028 + ADR-0029 落档后，本 ADR 增补以下哲学说明，作为下游 ADR 的设计锚点。

### 核心模型（一句话）

> Command skill 接收用户意图，AI orchestrator 基于 subject context 调用 capability nodes，runtime 负责 guard / CAS / event / loop budget，EventJournal 提供可追溯证据。

### 节点 ≠ 流水线工序

7 节点（requirement_analysis / technical_design / task_breakdown / dispatch / implementation / review / archive）从"DAG 流水线工序"重新定位为"可调用 capability"（类似 LangChain Tool Calling / LangGraph / ReAct agent）。

- AI agent (in anchor) 是 orchestrator，自己决定调用哪个 capability
- 节点不固定绑 subject
- 节点 manifest 改为 capability spec（具体字段定义留 ADR-0030 / SP-A11）
- transition-table 从"决定下一步走哪"降级为"事件 / outcome registry"

### Skill = 指令 = 用户意图入口

- UI 按钮 → 指令 → anchor → plugin skill → AI agent → capability nodes
- SKILL.md 从 thin facade（引用 fixed_actions.steps）改为 command/intent spec（具体字段 → ADR-0030 / SP-A11）

### 与本 ADR 主体的关系

本 ADR 主体（决策 1-6）仍然有效；增补章节为下游 ADR（0028 / 0029 / 0030）提供哲学锚点，不推翻原决策。

### 适用范围

该哲学在 v1.0 整个 plugin sovereignty 生态生效。具体实现机制（节点 manifest 字段 / SKILL.md 字段 / kernel migration）留 ADR-0030 / SP-A11 论证。

### 关联

- ADR-0028 实体两层 + anchor subject 泛化
- ADR-0029 大状态独立指令原则
- ADR-0030（候选）plugin / skill / kernel 实现机制
- SP-A10 协商备忘 §15.3 / §15.4 / §16
