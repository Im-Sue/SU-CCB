---
adr: ADR-0021
title: Status-repair primitive + 三层架构（API 优先 / 平等 callers / AI 编排）
date: 2026-05-15
status: accepted
owner: claude
reviewer: ccb_codex (consult rep_1e453cd95cbc, high confidence)
related:
  - ADR-0011-reactive-scheduler
  - ADR-0020-followup-as-source-marker
addresses:
  - 实施流"快路径"绕过节点 transition 导致 task 状态漂移（ADR-0011 历史债）
  - 7 个 maintenance 脚本各自独立，二次漂移风险高
  - 缺少用户友好的状态/进度/归档操作入口
  - AI Agent 与 UI 操作的入口不统一
---

# ADR-0021 · Status-repair primitive + 三层架构

## Context

CCB 实施流绕过 7 节点 canonical transition，task 状态长期漂移：
- 5 个 ADR-0020 spec 实施完仍 currentNode=requirement_analysis
- 已建 7 个独立 maintenance 脚本各自直改 DB
- 无用户级"修复"入口（UI/CLI）
- AI Agent 间通过命令行 + taskKey 协作，体验差

ADR-0011 reactive scheduler 本意：每个 transition 由 EventJournal 驱动。
我们的快路径不 emit 事件，是历史债，不是设计本意。

## Decision

### 1. 引入 `status-repair primitive`

新增 `POST /api/tasks/:id/status-repair`（业务规则的唯一写入路径）：

```
input: { type, payload, reason, evidence? }
type ∈ {
  quick_archive,    # 跳过 review 归档（标 reviewStatus='skipped_via_quick_archive'）
  set_progress,     # 改 progress
  set_status,       # 改 status (active/blocked/cancelled 等)
  unset_archive,    # 撤销错误归档
  ... 后续按需扩展
}

写入：EventJournal type='task.status_repaired' + sub-type + reason + actor
守卫：内置不变量（不允许把 archived → active 等明显异常）
区分 canonical：reviewStatus / sourceComponent 字段标"非节点流转"
```

废除：7 个独立 maintenance 脚本（迁移为 primitive 的内部实现）。

### 2. 三层架构

```
┌─────────────────────── Layer 1: 业务 API ────────────────────┐
│  Ground truth · 业务规则的唯一住所 · 永远直可达                │
│  POST /api/tasks/:id/status-repair                            │
│  POST /api/tasks/:id/derive       (ADR-0020 Step 4-C 已有)    │
│  POST /api/requirements/:id/materialize                       │
│  ... canonical transition routes（review→archive 等）         │
└────────────────────────────────────────────────────────────────┘
                          ▲
┌────────────── Layer 2: 平等 callers（无优先级）──────────────┐
│  UI 按钮         CLI/Slash 指令          AI tool functions   │
│  ─────────       ────────────           ────────────────    │
│  归档/改进度     /ccb:su-quick-archive    repair_task_status │
│  Health 面板     /ccb:su-status           derive_followup    │
│                  /ccb:su-set-progress     materialize_req    │
└────────────────────────────────────────────────────────────────┘
                          ▲
┌──────────── Layer 3: AI 编排（可选增强）─────────────────────┐
│  Claude/codex 接收复杂指令 → 解析意图 → 顺序/并行调 Layer 2   │
│  "归档 epic X 但保留 followup" → 拆解 + 调多个 API            │
│  "检查所有漂移并修复" → drift detector + repair primitive     │
└────────────────────────────────────────────────────────────────┘
```

**核心原则**：
- 业务规则**住在 Layer 1**（API 是 ground truth）
- Layer 2 三种 callers **平等**（UI/CLI/AI 调同一 API）
- Layer 3 AI 编排是**可选增强**，离线时基础操作仍可用

### 3. AI Tool function 暴露策略

Layer 1 API 通过 `capability/tool registry` 暴露给 Agent：
- Claude / codex 通过工具调用（tool_use）形式
- capability registry 记录可用 tool 名 + schema
- 详见后续 spec（ADR 本身不定义 tool registry 细节）

## Migration Path（6 phase · 渐进可中断）

| # | Phase | 工作量 | 阻塞 |
|---|---|---|---|
| 0 | 本 ADR 落定 | done | — |
| 1 | Layer 1: status-repair primitive + API + 测试 | 2-3 天 | 核心 |
| 2 | Drift detector (E)：archived_spec_active_task anomaly | 1 天 | Phase 1 |
| 3 | Layer 2 CLI: `/ccb:su-quick-archive` + `/ccb:su-status` thin facade | 半天 | Phase 1 |
| 4 | Layer 2 UI: 看板 Ops/Health 面板 + 任务详情修复按钮 | 1-2 天 | Phase 1+2 |
| 5 | Bridge: codex `[CCB_TASK_COMPLETED]` → EventJournal | 2 天 | Phase 1 |
| 6 | Layer 3 准备: AI tool capability registry + AI 编排能力 | 2-3 天 | Phase 1+5 |

7 个旧 maintenance 脚本在 Phase 1 之后保留 1 minor 版本兼容，
新代码必须用 status-repair primitive。

## Consequences

**正面**：
- 业务规则集中（避免 7 脚本各自漂移）
- UI/CLI/AI 统一审计（EventJournal `task.status_repaired`）
- 可用性优先：Layer 1+2 不依赖 AI
- AI 增强：复杂指令通过 Layer 3 编排
- 防漂移：Layer 1 内置不变量守卫

**负面 / 代价**：
- 3 层都要维护（但每层职责单一）
- 短期重复：旧 maintenance 脚本兼容期
- Layer 3 编排能力需要新 Agent 协议

## Open Questions

| OQ | 议题 | 倾向 |
|---|---|---|
| OQ-1 | tool capability registry 怎么定义 | 借鉴 MCP / OpenAI function schema |
| OQ-2 | Layer 3 编排部署位置（client / server） | client side (Claude/codex 本机) |
| OQ-3 | 多 task batch 修复的事务边界 | per-task 事务，整体最终一致 |
| OQ-4 | hook 联动（D 方案）何时引入 | Phase 5 桥接稳定后 Phase 7 引入 |
| OQ-5 | 旧 7 maintenance 脚本完全废除时机 | 1 minor 兼容后移除 |
| OQ-6 | 区分 quick_archive vs canonical archive 的 UI 标识 | 详情页加 badge "快路径归档" |
| OQ-7 | drift checker 误报怎么处理 | 仅生成 repair_proposal，不自动 apply |

## References

- Codex consult: rep_1e453cd95cbc (high confidence)
- Discussion: 5 候选方案 A/B/C/D/E 演化为本 ADR 的 3 层架构
- 用户洞察："AI Agent 作为 tool caller，UI 是快速入口的展示层"
- 工业对照：Linear / GitHub Copilot Workspaces 等混合分层做法
