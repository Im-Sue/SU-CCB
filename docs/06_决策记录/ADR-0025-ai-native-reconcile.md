---
id: ADR-0025
title: AI-native Reconcile + Diff Log（/ccb:su-reconcile skill）
status: active
decided_at: 2026-05-22
last_updated: 2026-05-22
decider: 用户（基于父需求 §1 + Phase 3 audit）
reviewer: ccb_codex（rep_4f49ef73fed0 audit）
codename: ai-native-reconcile
related_doc: docs/03_开发计划/ccb-plan/2026-05-21-plugin-sovereignty-roadmap.md
parent_adrs: [ADR-0023, ADR-0024, ADR-0030]  # ADR-0023: plugin sovereignty 主决策; ADR-0024: plugin primitive runtime（Phase 1）; ADR-0030: plugin node paradigm
implements_via: [SP-Phase3-impl 实施 spec（3a / 3b / 3c 内部闸口）]
phase: 3
---

# ADR-0025: AI-native Reconcile + Diff Log

## Status

Accepted（2026-05-22）。Phase 3 v1.0 必做基础设施。

## Context

父需求 `docs/01_架构设计/ccb-plan/2026-05-17-v1.0-plugin-sovereignty.md` 用户原话：

> "如果有漂移问题，最多就是 UI console 上具有一个手动变更的或者触发一下 anchor ai 里的扫描、状态同步指令，让 ai 自己根据实施、任务情况做一次分析是否需要矫正状态、进度、标记来做漂移的补充。"

业务问题：Phase 2 落地后 plugin 写文件 / Console 投影分两端跑，可能出现：
- plugin 写完 → Console indexer 死掉期间漏 scan → DB 投影残缺
- 用户手改 frontmatter → 业务规则违反但已写入文件
- 跨文件冲突（draft consumed 但 subtask md 缺失 / dependencies 指向不存在的 task_id）
- 历史 Task 投影孤儿（DB 有 / 文件无）
- Console 现有 `status-repair` endpoint 直写 DB，违反 plugin sovereignty 主权链路

Phase 3 给"AI 自检 + 修复"通道：用户触发后，AI 扫差异 → 报告 → 用户审批 → AI 修复。

## Decision

### 决策 1 · Reconcile 定位：维护 skill，非第 8 节点

`/ccb:su-reconcile` 是独立维护 skill，**不进 7 节点流程**。理由：
- 节点是"AI 选意图进入的能力"，reconcile 是"维护事件"，跟节点选择无关
- 父需求 line 363-367 已写死 "su-reconcile 不是第 8 节点，是跨节点维护 skill"

### 决策 2 · Truth Priority

reconcile 看到不一致时按以下优先级判定真相：

1. **`docs/.ccb/*` 文件**（plugin canonical，最高真相）
2. **EventJournal `journal.jsonl`**（不可变审计 + 崩溃恢复锚点）
3. **Console DB projection**（最低真相，是 projection 不是 source）

修复方向：1 / 2 不一致时按 EventJournal 重建；2 / 3 不一致时按文件 + Journal 重建 DB。

### 决策 3 · 触发机制

**仅用户主动触发**：`/ccb:su-reconcile`（CLI）或 Console 按钮派发 anchor dispatch（v1.0 范围）。

不做：
- 定时 AI reconcile（不可控副作用）
- Console 检测漂移后自动派发（用户难区分"扫描"和"修复"）

### 决策 4 · 检测范围

**v1.0 minimum**：
- 文件 vs DB 投影差异
- parseStatus partial / parse_error 文档
- DB 有文件无 / 文件有 DB 无（孤儿）
- draft consumed 但 subtask md 缺失
- subtask dependencies 引用不存在的 task_id
- 现有 drift.service 已知 12 类
- status-repair 可迁移项（progress / status / archive / requirement rollup）

**v1.x 推后**：
- 跨文档语义一致性
- ADR / spec 引用完整性
- 跨项目 reconcile
- 周期 reconcile
- 复杂历史事件 replay

### 决策 5 · 报告与审计事件

**报告**：每次跑 reconcile 写一份 markdown 到 `docs/.ccb/reconcile/YYYY-MM/reconcile-<timestamp>.md`，含：
- 检测出的差异清单（按类别分组）
- 每条差异的"可能原因 + 修复建议 + 自动/审批/禁止 分级"
- 用户审批后实际执行的修复清单

**EventJournal 审计**：plugin EventJournal append 以下事件：
- `reconcile_started` / `reconcile_completed`
- `drift_detected`（每条差异）
- `state_reconciled`（每条修复）

Console 不持久化 plugin EventJournal 到 DB（同 Hook 决策——避免 Console 变事件库）。

### 决策 6 · 修复分级

| 分级 | 范围 | 处理 |
|---|---|---|
| **自动** | 纯投影刷新 / scanProject / 重建 DB projection / requirement rollup projection | 无需用户审批，apply 后写 EventJournal |
| **审批** | 改 canonical md/json / 业务状态（archive/done/blocked/progress）/ 删除/移动文件 / 冲突源裁决 | 用户在报告 UI 上勾选后才 apply |
| **禁止** | git reset / git checkout / git commit / 删 archive / 重写 EventJournal / 读 secrets | 永不执行 |

### 决策 7 · status-repair 迁移策略

Console 现有 2 个 status-repair endpoint：
- `POST /api/tasks/:taskId/status-repair`
- `POST /api/requirements/:requirementId/status-repair`

迁移路径（按用户拍板"直接删"，与 ADR-0031 一致）：
1. 旧 5 个 action（`quick_archive / set_progress / set_status / unset_archive / rollup_requirement`）变成 reconcile apply 阶段的 action 类型
2. 前端 HealthPanel "一键修复"按钮改为 anchor dispatch `/ccb:su-reconcile`
3. **直接删** 2 个 endpoint（不留 410 wrapper / 双轨）
4. AI tools registry 同步去掉 status-repair 工具

### 决策 8 · Console 边界

Console v1.0 在 reconcile 范畴只承担：
- **触发器**：按钮派发 anchor dispatch `/ccb:su-reconcile`
- **展示**：读 `docs/.ccb/reconcile/` 报告 markdown 并渲染
- **审批入口**：用户在报告 UI 上勾选 apply action → 再次 dispatch
- **scanProject** 仍是 Console 内 indexer 的"快通道"，与 AI reconcile 是两个层级

Console **不做**：
- 直写 Task / Requirement DB（status-repair 已迁走）
- 持久化 plugin EventJournal
- 自动决定修复 action（必须 AI 出报告 + 用户审批）

### 决策 9 · 并发 / 中断 / 幂等

- reconcile 持 project-level 锁，同一项目同时只跑一个
- apply 阶段单 action 走 lib/runtime 的 CAS + safeWriteFile + EventJournal append
- 中途中断：reconcile_started 已发但 reconcile_completed 未发 → 下次跑时 detect 阶段会看到中间状态（写到一半的报告）→ 警告用户 + 继续重跑
- 用户连点 2 次按钮 → project 锁排队 + 第二次跑 detect-only 看新差异 → 报告 no-op 或新差异

### 决策 10 · 实施分阶段（3a / 3b / 3c）

| 阶段 | 范围 | 工程量 |
|---|---|---|
| **3a** | `skills/su-reconcile/SKILL.md` + `lib/reconcile/detect/` + markdown 报告 + EventJournal events | 1.5-2d |
| **3b** | `lib/reconcile/apply/` + approved action schema + status-repair 迁移 + HealthPanel UI 改 | 2-3d |
| **3c** | Console indexer resilience（启动补扫 + projection retry/backoff + stale → orphan）| 1.5-2d |

总计 5-7d。同一 SP 内分 3 阶段验收（每阶段验收通过才进下一阶段）。

## 非目标（明确不做）

- 不做定时 AI reconcile（v1.x 可能加 Console 定时 scanProject）
- 不做跨项目 reconcile（v1.x）
- 不做 SSE / WebSocket 实时反馈（v1.x）
- 不做报告归档 / 清理（v1.x）
- 不持久化 plugin EventJournal 到 Console DB（违反核心理念）
- 不把 reconcile 做成第 8 节点

## 替代方案

| 方案 | 拒绝原因 |
|---|---|
| Console 自动检测漂移触发 reconcile | 用户难区分"扫描"和"修复" |
| 全部修复自动执行 | 风险大（删文件 / 改状态 / 冲突裁决都自动太冒险）|
| 全部修复用户审批 | 低效（纯投影刷新这种无业务影响也要审批）|
| status-repair endpoint 双轨过渡 | v1.0 没真稳定，跟 ADR-0031 不一致 |
| reconcile 作为 review 子流程 | review 是节点内职责，reconcile 是跨节点维护 |

## 风险

| 风险 | 缓解 |
|---|---|
| **最大风险**：把旧 status-repair "搬家"而不是重构语义 | reconcile apply action 必须走 lib/runtime CAS / safeWriteFile / journal，不允许直写 DB |
| HealthPanel 一键修复绕过 AI 深度判断 | Phase 3b 必须改 HealthPanel 走 anchor dispatch |
| cleanup_stale_task_projections 现在删 DB Task projection | v1.0 改成 orphan / report 不直接删（用户拍板）|
| reconcile 报告积累占磁盘 | v1.x 加归档/清理，v1.0 接受 |
| reconcile apply 期间 Hook 触发 Console scan 看到中间状态 | apply 持锁 + scanProject 在 reconcile 持锁期间 skip |

## 关联

- 父需求：`docs/01_架构设计/ccb-plan/2026-05-17-v1.0-plugin-sovereignty.md`
- 路线图：`docs/03_开发计划/ccb-plan/2026-05-21-plugin-sovereignty-roadmap.md`
- 触发 audit：codex `rep_4f49ef73fed0`
- 父 ADR：0023 / 0024 / 0030
- 关联 SP：Phase 3 实施 spec（3a / 3b / 3c）
- 吸收的老 SP：SP-A03（本 ADR） / SP-A08（reconcile skill manifest） / SP-A12（status-repair 迁移） / SP-C07（reconcile 实现）

## 协商证据

- codex audit `rep_4f49ef73fed0`（Phase 3 设计 audit）
- claude 4 锚点反思 2026-05-22 主对话
- 用户拍板 2026-05-22 5 项必问决策（按 claude 推荐方向走）
