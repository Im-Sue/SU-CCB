---
id: ADR-0029
title: Large-State Command Layer + Boundary Standard + Event Contract
status: active
decided_at: 2026-05-19
last_updated: 2026-05-19
decider: Claude (with user authorization)
reviewer: ccb_codex (consult round 4 §F + round 6 §F)
related_doc: docs/02_需求设计/ccb-plan/2026-05-18-sp-a10-three-tier-model-consult.md
companion_adrs: [ADR-0023, ADR-0028, ADR-0030]  # ADR-0023: plugin sovereignty 总纲; ADR-0028: 两层实体模型 + anchor subject 泛化; ADR-0030: plugin/skill/kernel 实现机制（待论证）
impacted_components: [apps-ccb-console-server, apps-ccb-console-web, claude-plugin-distribution, docs-ccb-workspace]
---

# ADR-0029: Large-State Command Layer + Boundary Standard + Event Contract

## Status

Accepted（2026-05-19）。源于用户 2026-05-18 提出"大状态的管理应该归为独立的指令来处理"原则，codex round 4 §F 确认 + round 6 建议独立 ADR。

## Context

ADR-0028 取消 Epic 后，cancel/defer 等大状态变更的级联询问 UX（旧设计在主流程内塞 case-by-case 询问）显得不健康。用户拍板"一次性 stop + 后续独立指令回滚"，引出更广的设计原则：

> 大状态的管理应该归为独立的指令来处理；不在主流程 transition 里塞级联询问

这原则适用范围超过 ADR-0028 实体模型，独立成 ADR-0029。

## Decision

### 决策 1 · 命令清单 = plugin skills

以下动作是**独立指令（plugin skill）**，不是主流程 transition：

| 命令名 | 用途 | 已存在? |
|---|---|---|
| `/ccb:su-cancel` | 取消（Requirement / SubTask） | ❓ firm 占位 |
| `/ccb:su-defer` | 暂缓 | ❓ firm 占位 |
| `/ccb:su-reactivate` | 重新激活 | ❓ firm 占位 |
| `/ccb:su-resume` | 恢复 | ✅ |
| `/ccb:su-pause` | 暂停 | ❓ 占位 |
| `/ccb:su-abort` | 强制终止 | ❓ 占位 |
| `/ccb:su-replan` | 重规划 | ❓ 占位 |
| `/ccb:su-regroup` | 二次分组（v1.1+） | ❓ 占位 |
| `/ccb:su-split` | 拆分 | ❓ 占位 |
| `/ccb:su-merge` | 合并 | ❓ 占位 |
| `/ccb:su-parallelize` | 放开需求内并行（v1.1+） | ❓ 占位 |
| `/ccb:su-materialize-requirement` | 需求拆分为 SubTask | ❓ firm 占位 |

占位指令的具体 SKILL.md 字段定义留 ADR-0030 / SP-A11；占位命名规则见 SP-B92 mapping doc。

### 决策 2 · 边界判定标准

一个动作**必须是独立指令**当且仅当满足以下任一：
- 影响**多个 subject**（如 cancel Req → 影响所有 SubTask）
- 改变**长期生命周期**（如 deferred / archived）
- 涉及 **anchor / worktree 资源**（如 anchor lifecycle）
- 需要**审计父子结果**（如 batch 操作）
- 可能需要**补偿 / 回滚**（如 cancel 后 resume）

否则是**主流程内 transition**（单节点确定性推进，如 implementation → review）。

### 决策 3 · 事件契约

每个独立指令 emit 以下事件序列：

| 事件类型 | 触发时机 |
|---|---|
| `command_invoked` | 用户 / 系统触发命令时 |
| `command_planned` | AI orchestrator 规划完调用方案后 |
| `capability_invoked` | 每个 capability 节点被调用前 |
| `capability_completed` | capability 成功完成 |
| `capability_denied` | precondition DENY |
| `command_failed` | 命令执行失败（不可补偿）|
| `command_completed` | 命令成功完成 |
| `command_compensated` | 命令被回滚 / 补偿 |

事件 envelope schema 复用 ADR-0027 generic subject envelope（ADR-0028 决策 7）。

### 决策 4 · "stop"语义（cancel / defer 拍板 A）

对 Requirement 触发 cancel/defer 时，对所有关联 SubTask 一致**软标记**：

| SubTask 当前态 | stop 行为 |
|---|---|
| queued | 标 stopped |
| running（anchor 内跑） | **让它跑完**再标 stopped |
| reviewing | **让审完**再标 stopped |
| done / archived | 不动 |

**不**强制中断 anchor 进程（避免丢失 AI/Codex 中间产物）。后续恢复用独立指令（`/ccb:su-resume` / `/ccb:su-reactivate`）。

### 决策 5 · 不级联 UI 询问

主流程 UI 不塞"你要取消所有子任务吗？" / "确认 N 个 SubTask 都 stop?" 这种级联询问。命令一次性触发 + 一次性 stop + 后续独立恢复。

UI 上的 cancel/defer 按钮位置：
- **Requirement 详情页 header**（**不**在任务看板 / 列表卡片）
- 详见 SP-B15 §5.7 / SP-B20 §5（用户拍板）

### 决策 6 · UI 恢复入口必须显性

`/ccb:su-reactivate` / `/ccb:su-resume` 入口必须在 3 处可发现：
1. 命令面板
2. Requirement 详情页主操作区
3. timeline 事件旁

## 非目标

- 不定义 SKILL.md 字段具体形态 → ADR-0030 / SP-A11
- 不实现 command 具体逻辑 → 后续独立 PR
- 不规定主流程 transition 表 → kernel manifest 改造（ADR-0030）

## 替代方案

| 方案 | 拒绝原因 |
|---|---|
| 把所有大状态变更塞主流程 transition | 主流程会变成 N×N 状态机；UI 充满级联询问 |
| 不区分"独立指令" vs "transition" | 无边界标准 → 命令滥用 |
| 暴力中断 anchor（B/C 候选）| 丢失 AI/Codex 中间产物 |

## 影响范围

### 新增
- 12 个 plugin skill 占位（4 个 firm 命名 + 8 个 placeholder-loose）
- 8 个事件类型（复用 ADR-0027 envelope）

### 改动
- Requirement / SubTask 上的 cancel / defer / resume / reactivate UI 入口
- 主流程 transition 表瘦身（大状态相关 transition 移除）

### 不影响
- 节点 manifest 字段 / SKILL.md 字段（→ ADR-0030）

## 验收

- ADR-0028 同步落档
- ADR-0030（SP-A11）跟进定 SKILL.md 形态
- ADR-0027 EventJournal 补 8 个事件类型
- SP-B15 / SP-B20 中 cancel / defer / resume / reactivate 按钮可用占位指令命名
- v1.1+ 独立 PR 实施每个占位指令的内部逻辑

## Risks

| # | 风险 | 缓解 |
|---|---|---|
| R1 | 占位指令过多阻塞实施 | 优先固化 4 个 firm 命名（materialize / cancel / defer / resume） |
| R2 | 边界标准过松 → 命令滥用 | ADR-0030 起草时建议加 lint 检查 |
| R3 | stop 软标记被误解为"立即停" | UI 明示"已请求停止，等正在执行的完成" |

## 协商证据

- codex round 4 §F：原则评估 approved（job_4706242b2c92 / rep_2e5932169347）
- codex round 6 §F：建议独立 ADR-0029
- codex round 7：4 个推荐 + stop=A 拍板（job_a3f78d7fef3d / rep_9b78d8e4c722）

## 后续

- ADR-0030（SP-A11）：节点 capability spec + SKILL.md 形态 + AI orchestration runtime 实现
- 12 个占位指令实施：v1.1+ 独立 PR
- UI 恢复入口实现：随各 SP-B 实施
