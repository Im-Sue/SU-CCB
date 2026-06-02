---
doc_type: architecture
title: "CCB Console V2 E12 UI 全量设计"
updated: 2026-05-28
---

# CCB Console V2 — E12 UI 全量设计

## 设计宗旨

**让用户一眼看到 AI 在做什么、卡在哪、协商了几轮、capability 是不是 OK**。

CCB Console V2 不是工作流编辑器，是协作过程的"观察台"——所有可视化必须**从既有契约 projection**，不引入额外的 UI-only state。设计原则按重要性排序：

1. **数据驱动 ≠ 数据堆砌**：每屏每模块必须回答一个明确问题，不显示无回答价值的字段
2. **节点是真相，phase 是回忆**：Wave 3 后所有视觉以 `currentNode/nodeSubstate/runtimeState` 为锚，phase 只在历史段保留
3. **观察不编辑**：v0.4 不做 node designer，所有节点流转 UI 是 read-only projection + 受控编排（按 manifest 触发）
4. **键盘可达**：Tab focus ring 可见、`⌘K` palette、Esc 关 panel；任何 UI 路径必须有键盘等价
5. **空态有用**：empty state 必须告诉用户"为什么空 + 下一步做什么"，不是"暂无数据"

## 现状审计

| 模块 | 现状 | E12 行动 |
|---|---|---|
| CSS tokens | ✅ tokens.css 含 v2 semantic aliases (cc-color-* / cc-space-* / cc-text-* / cc-shadow-*) | 仅补 trace/timeline 专用 token |
| AppShell + Sidebar + PageHeader | ✅ 已实现 | 仅补"任务运行徽标"角标 |
| 容器策略 (SlidePanel 400 / Modal 480 / 主区双栏) | ✅ 已敲定 | 不改 |
| 10 UI 组件 (Button/Card/Badge/Modal/Input/Toast/SegmentedControl/EmptyState/SlidePanel/Skeleton) | ✅ | 新增 4 个组件（见 §4.2） |
| 8 page (overview/tasks/requirements/runs/documents/ai-cli/recording-play/settings) | ✅ | tasks / overview 新增 v2 视图，不动 ai-cli/runs/recording |
| **节点流转 projection** | ❌ 无 | **新建** Task Detail "Node Flow" tab + 总览节点徽标 |
| **协作可视化 (Consultation Trace + NodeRun timeline + Capability status)** | ❌ 无 | **新建** Task Detail "Consultation" tab + Overview Activity Feed |
| Task Detail 现状 | 仅 timeline tab | 加 "Node Flow" 与 "Consultation" 两 tab |
| 后端 endpoint | timeline / refresh-projection 已有；NodeRun + capability matrix 契约已定 (KA-11)，apply endpoint 已有 (KA-9) | 新增 GET projections（≤3 endpoint） |

**关键约束确认**：
- KA-11 NodeRun timeline + capability status matrix 契约已 archived，本设计直接消费
- KA-10 /ccb:su-flow facade 已收敛，UI 出现"plan flow"入口标签时统一用 `/ccb:su-flow`
- KA-1a parallel_join schema/lint 解锁但 runtime 未实现，本 UI **不显示** parallel_join 视图（runtime 还没 trace 可投影）

## 信息架构

### 3.1 全局导航（Sidebar）保持不变 + 角标增强

```
[ Logo ]
├─ Overview            ← 总览 + Activity Feed（新）
├─ Tasks (N · 🔴M)     ← N 总数 / 🔴 阻塞或异常 capability 任务数（新角标）
├─ Requirements
├─ Runs (N)            ← 同步任务记录
├─ Documents
├─ AI CLI
└─ Settings
```

角标使用 `Badge` 组件，仅显示需要关注的数量（>0 才出现），避免常显数字噪音。

### 3.2 Page-level 信息架构

| Page | 主区 | 右侧 SlidePanel | 新增 |
|---|---|---|---|
| Overview | 4 个 MetricCard 横排 + Activity Feed（最新 10 条 codex_receipt_ready / transition apply / capability fallback） | — | Activity Feed（CA-4） |
| Tasks 看板 | 7 列 currentNode 看板（v0.4 v1 完成线后 phase 列已删除） | Task Detail 三 tab | "Node Flow" / "Consultation" tab（CA-5/CA-4） |
| Requirements | 列表 + Modal 创建 | — | 不动 |
| Runs | 表格 | — | 不动（无单条详情接口） |
| Documents | 主区双栏（列表 + Markdown 阅读器） | — | 不动 |
| AI CLI / Recording / Settings | 不动 | — | 不动 |

### 3.3 Task Detail SlidePanel 三 tab 切换

```
┌─ Task Detail (SlidePanel 400px) ─────────────────┐
│ [Title] · [currentNode badge] · [runtimeState]   │
│ ────────────────────────────────────────────────│
│  Tab: [Timeline] [Node Flow] [Consultation]     │
│ ────────────────────────────────────────────────│
│  (active tab content)                            │
└──────────────────────────────────────────────────┘
```

3 tab 各自承担一类问题：
- **Timeline**（已有，仅 align v2 token）：任务全周期事件流
- **Node Flow**（新，CA-5）：节点流转 projection
- **Consultation**（新，CA-4）：协商 trace + capability status

## 视觉系统增量

### 4.1 新增 design token

```css
/* trace/timeline 专用 */
--cc-trace-event-claude: var(--blue-500);
--cc-trace-event-codex: var(--purple-500);
--cc-trace-event-system: var(--gray-500);
--cc-trace-event-error: var(--red-500);
--cc-trace-event-warn: var(--yellow-500);
--cc-trace-rail-color: var(--gray-200);
--cc-trace-rail-active: var(--green-500);
--cc-node-stepper-active: var(--green-600);
--cc-node-stepper-pending: var(--gray-300);
--cc-node-stepper-blocked: var(--red-500);
--cc-capability-resolved: var(--green-500);
--cc-capability-fallback: var(--yellow-500);
--cc-capability-missing: var(--red-500);
```

### 4.2 新增 UI 组件（4 个）

| 组件 | 职责 | 替代/补充 | 复用 |
|---|---|---|---|
| `<NodeStepper>` | 7 节点水平 stepper，每节点 currentNode/substate badge + transition arrow 高亮；read-only | 替代任何"流程图"想象 | 内部用 Badge + 自绘 SVG |
| `<TraceTimeline>` | 垂直时间线，每事件一卡（sender/receiver/intent/score/timestamp/payload preview） | Timeline tab 复用 | 内部用 Card + 折叠按钮 |
| `<CapabilityMatrix>` | 横轴 7 节点 × 纵轴 capabilities 的网格，cell = resolved/fallback/missing/skip 4 态颜色 | 配套 NodeRun timeline | 自绘 grid + Tooltip hover |
| `<MetricCard>` | 单值卡：label + 大数字 + 子状态 + 可选 trend chip（仅当后端有历史快照时） | Overview 顶部卡 | Card 包装 |

所有组件用 CSS Modules，遵循已有 `<Badge>` `<Card>` 的 prop 形态（`size: 'sm'\|'md'\|'lg'`、`tone: 'default'\|'success'\|'warn'\|'danger'`）。

## 节点流转 Projection 设计（CA-5）

### 5.1 视觉范式：horizontal stepper，不是 graph

**反 designer**：明确不画 graph editor、不让用户拖节点。原因：
- v0.4 北极星 §5 显式声明"节点是协议级 canonical，不开放扩展点"
- 7 节点是固定序列（requirement → design → breakdown → dispatch → implementation → review → archive）
- graph 视觉会暗示"可拖拽编辑"，违背 read-only projection 定位

```
┌── Node Flow ───────────────────────────────────────┐
│  ●━━━━●━━━━●━━━━○━━━━○━━━━○━━━━○                 │
│  req  des  brk  dis  imp  rev  arc                │
│       ▼ technical_design / drafting               │
│  Substate: drafting · runtimeState: running       │
│  Last transition: requirement_analysis            │
│      __on_done__to__technical_design               │
│  At: 2026-05-04 10:23:11Z                          │
│ ──────────────────────────────────────────────── │
│  Transitions history (compact list, 5 latest):    │
│   • requirement_analysis → technical_design       │
│     · pass · 2026-05-04 10:23:11Z                  │
│   • requirement_analysis · drafting → consult     │
│     · subflow · 2026-05-04 10:18:00Z               │
│   ...                                              │
│  [View full timeline]                              │
└──────────────────────────────────────────────────┘
```

### 5.2 受控编排（control surface，非 designer）

允许的操作：**只放与 K1 apply endpoint 已暴露的 transition 一致的按钮**。
- 当任务在 review 节点 + reviewIntent 已 ready，显示按钮 `Approve & advance to archive`
- 当任务在 implementation 节点 + codex_receipt_ready 事件存在，显示按钮 `Mark ready for review`
- 其他情况（节点不允许人工 transition）按钮 disabled + tooltip 解释原因

按钮调用 K1 apply endpoint（已有），由后端 CAS 写状态、refresh projection。

**不显示**：未在 transition-table 注册的 ad-hoc 跳转、跨多节点的 jump、撤销已 apply 的 transition。

### 5.3 数据契约 + endpoint 复用策略

**Endpoint 复用矩阵**（codex round 1 共识修订）：

| 用途 | endpoint | 来源 | 备注 |
|---|---|---|---|
| NodeRun timeline raw | GET `/api/noderuns/:taskId` | KA-11 已有 | UI 直接消费，无需 wrapper |
| Capability status global | GET `/api/capabilities/status` | KA-11 已有 | UI 在前端按 task 上下文 filter |
| Node flow projection (task-scoped) | GET `/api/tasks/:id/node-flow` | **新增** | 整合 noderuns + transitions history + K1 guard projection 出 applicable_actions |
| Consultation trace | GET `/api/tasks/:id/consultation` | **新增** | EventJournal codex_* 事件 + ReviewIntent 投影 |
| Activity feed | GET `/api/activity/recent?limit=10` | **新增** | 跨项目 EventJournal 最近事件 |

总：**3 新 + 2 复用**，避免重复定义 capability matrix / NodeRun 语义。

新建 GET `/api/tasks/:id/node-flow` 返回（基于 NodeRun timeline 契约 noderun-v0.1）：
```json
{
  "currentNode": "technical_design",
  "nodeSubstate": "drafting",
  "runtimeState": "running",
  "lastTransitionId": "requirement_analysis__on_done__to__technical_design",
  "lastTransitionAt": "2026-05-04T10:23:11Z",
  "transitions": [
    { "transition_id": "...", "source_node": "...", "target_node": "...",
      "verdict": "pass" | "wait" | "fail", "at": "...", "evidence_ref": "..." }
  ],
  "applicable_actions": [
    { "transition_id": "review__pass__to__archive", "label": "Approve & archive",
      "guard_status": "satisfied" | "blocked", "guard_reason": "..." }
  ]
}
```

实施由 Console server 从 EventJournal + Task state 投影；不引入 kernel 改动。

## 协作可视化 Trace View 设计（CA-4）

### 6.1 Consultation Tab 视觉范式：垂直 timeline + 折叠卡

```
┌── Consultation ───────────────────────────────┐
│  Round 3 · technical_design / consult         │
│  ┌──────────────────────────────────────────┐│
│  │ Claude → Codex · plan_review_request    ▶││
│  │  intent_score: 8.6 · tokens: in 2.1k    ││
│  │  → out 0.4k · 2026-05-04 09:45:12Z       ││
│  └──────────────────────────────────────────┘│
│  ┌──────────────────────────────────────────┐│
│  │ Codex → Claude · plan_review_reply      ▶││
│  │  verdict: pass · score: 8.6 · tokens... ││
│  └──────────────────────────────────────────┘│
│  Round 2 · ...                                │
└────────────────────────────────────────────── ┘
```

每张卡 collapsed 仅显示头行；点击 ▶ 展开完整 payload preview（≤500 字符 + Markdown render）。

### 6.2 Capability Status Matrix（依 KA-11 cap-matrix-v0.1 契约）

```
        req  des  brk  dis  imp  rev  arc
governance.escalation  ●    ●    ●    ●    ●    ●    ●
spec.linting           ●    ●    ●    -    ●    ●    -
project.indexing       ●    -    ●    -    -    -    -
analysis.deep         ◐    ◐    -    -    -    ◐    -
trace.persistence      ●    ●    ●    ●    ●    ●    ●
```

`●` resolved (green) / `◐` fallback (yellow) / `○` missing-allowed (gray) / `✗` missing-blocking (red) / `-` not-required

Hover cell 显示 tooltip：resolved provider / fallback chain / 上次 resolve at / evidence_ref。

**4 态来源说明**（codex round 1 共识修订）：matrix cell 颜色**不**来自 cap-matrix-v0.1 的 `active/deprecated/disabled`（那是 capability registry **global lifecycle**），而是来自：
- 主源：`NodeRun.capability_decisions` per-noderun 的实际 resolve outcome（resolved / fallback / missing）
- 兜底：global `/api/capabilities/status` 的 capability availability（区分 missing-allowed vs missing-blocking）

这样 cell 反映"这个任务在这个节点用这个 capability 实际发生了什么"，而非 capability 本身的 lifecycle 状态。

### 6.3 Activity Feed（Overview）

`Overview` page 顶部 4 MetricCard 之后是 Activity Feed（最近 10 项跨任务事件）：

```
[ tasks: 12 ] [ blocked: 1 ] [ rounds today: 8 ] [ fallbacks today: 0 ]

Activity Feed
─────────────
🟢 task-e12-t1  receipt ready (codex)         2 min ago
🟡 task-e11-t3  capability fallback           8 min ago
   (analysis.deep → claude_native)
🟢 task-e12-t2  transition apply              12 min ago
   (implementation → review)
...  
```

Feed 数据源：EventJournal table（已有 D3 A1 落地），按 `at desc limit 10` 简单查询。

**Activity Feed 事件契约**（codex round 1 共识修订）：

| event_type | tone | icon | 文案模板 | 跳转 |
|---|---|---|---|---|
| `codex_receipt_ready` | success (green) | 🟢 | `{task_id} receipt ready (codex)` | `/tasks/:id?tab=consultation` |
| `transition.applied` | success (green) | 🟢 | `{task_id} transition apply ({source}→{target})` | `/tasks/:id?tab=node-flow` |
| `capability.fallback` | warn (yellow) | 🟡 | `{task_id} capability fallback ({cap_id} → {provider})` | `/tasks/:id?tab=consultation` |
| `capability.missing` | danger (red) | 🔴 | `{task_id} capability missing ({cap_id})` | `/tasks/:id?tab=consultation` |

未列出的 event type 默认 tone=info (gray) + 不可点击。

### 6.4 数据契约

新建 GET endpoint：
- `/api/tasks/:id/consultation` → 协商 round 列表（基于 EventJournal `codex_*` 事件 + ReviewIntent table）
- ~~`/api/tasks/:id/capability-status`~~ **不新增**：复用 KA-11 已有 GET `/api/capabilities/status`（global view），UI 在前端按 task 上下文 filter。matrix cell 数据用 GET `/api/noderuns/:taskId` 的 capability_decisions 字段（per-noderun）+ global status 兜底，不需要 task-scoped wrapper
- `/api/activity/recent?limit=10` → Activity Feed（跨项目）

不动 kernel；仅 Console server 投影 + Prisma query。

## 用户交互流程（关键 journey）

### 7.1 "我的任务现在在哪一步"

1. 点 Sidebar `Tasks` → 看板按 currentNode 分列 → 任务卡含 currentNode badge + runtimeState 角标
2. 点任务卡 → SlidePanel 打开 → 默认在 Timeline tab
3. 切到 `Node Flow` tab → 看 7 节点 stepper + 当前节点 substate + 最近 5 条 transition
4. 看到 `Approve & archive` 按钮 → 点击 → K1 apply endpoint 触发 → 状态自动 refresh

### 7.2 "我想知道这次协商发生了啥"

1. 任务卡 SlidePanel → `Consultation` tab
2. 看 round-by-round 折叠卡 → 点击展开看 payload + score + token
3. 滚到底部点 `Capability status` 子段 → matrix 视图，hover cell 看详情

### 7.3 "整个项目有没有异常"

1. Overview page → 4 MetricCard 看 blocked / fallbacks 数量
2. Activity Feed 看最近 10 条事件 → 黄/红色项点击直接跳到对应任务的 Consultation tab

## 不做（边界）

- **不做 node designer UI**（北极星 §5 明确，v0.5 候选）
- **不做 parallel_join 可视化**（runtime 未实现，无 trace 可投影；等 E15）
- **不做 multi-worker 并行执行 UI**（北极星 §5）
- **不做跨项目 batch scheduler view**（北极星 §5）
- **不做 manifest 热加载 UI**（北极星 §5）
- **不实现自定义节点扩展**（北极星 §5）
- **不替换现有 ai-cli / Recording 模块**（独立维护）
- **不引入新 UI 框架**（保持 React 19 + CSS Modules + Zustand）
- **不引入新 charting 库**（Activity 与 capability matrix 用自绘 SVG/HTML grid）
- **不引入实时 WebSocket push**（v2 用 polling + manual refresh；WS 留 Wave 4）

## task 拆分预览（3 条线 + 共享）

按 master roadmap §3 Wave 3 E12 硬要求"必须分 UI foundation / projection data / trace view 三条线"：

| 线 | Task |
|---|---|
| **共享** | T1 · 4 个新 token + 4 个新组件（NodeStepper / TraceTimeline / CapabilityMatrix / MetricCard） |
| **UI Foundation (CA-9)** | T2 · 现有 page 对齐 v2 token + Sidebar 角标 + Tasks 看板按 currentNode 分列（删除 phase 列） |
| **Projection Data (CA-5 backend)** | T3 · 后端 GET `/api/tasks/:id/node-flow` endpoint 实现（整合 noderuns + transitions history + applicable_actions）+ 单元测试 |
| **Projection Data (CA-5 frontend)** | T4 · Task Detail "Node Flow" tab UI 接入 NodeStepper + 受控编排按钮（基于 K1 apply guard status + 二次确认 Modal） |
| **Trace View (CA-4 backend)** | T5 · 新增 GET `/api/tasks/:id/consultation` + GET `/api/activity/recent?limit=10`；capability matrix 数据**复用** KA-11 已有 `/api/capabilities/status` + `/api/noderuns/:taskId` capability_decisions 字段，**不**新增 capability-status endpoint |
| **Trace View (CA-4 frontend)** | T6 · Task Detail "Consultation" tab UI（协商卡 + capability matrix UI 组合 capabilities/status + noderuns 数据）+ Overview Activity Feed UI（消费 T5 新增的 `/api/activity/recent`，含 event_type → tone/icon/文案/跳转 映射）+ 4 MetricCard |
| **共享** | T7 · Playwright screenshot baseline（每 page + 每新增 tab）+ vitest 单元测试 + e2e smoke + lint baseline |

预计 7 task。WIP=2 仍按 codex 实施 + Claude UI/CLI 文案 review 节奏。

## 验收范围

| 项 | 命令 / artifact |
|---|---|
| 4 新组件存在并可独立 storybook-style 渲染 | NodeStepper / TraceTimeline / CapabilityMatrix / MetricCard 各有 `*.spec.tsx` 单元测试 |
| Task Detail 三 tab 切换 | Playwright 录屏 1 段，Tab 切换无 layout shift |
| Node Flow 投影正确 | 给定 fixture task，stepper 当前节点高亮 + 最近 5 transition 排序正确 |
| Consultation tab 数据 | 给定 fixture task with EventJournal events, round 卡数量与 EventJournal 一致 |
| Capability matrix 4 态 | 4 种状态各有 fixture 单元测试覆盖 (resolved / fallback / missing / skip) |
| Overview Activity Feed | API 返回 10 条 + 颜色按事件类型分配 + 点击跳转任务 Consultation tab |
| 删除 phase 列 | Tasks 看板列源自 currentNode；用户可见 page/component/store 不再以 phase 分组；grep allowlist 允许 type 定义 / 兼容 API enum / migration test fixture 在受控位置残留 |
| Playwright screenshot baseline | 8 page × snapshot 全过 + Task Detail 3 tab snapshot 全过；dev server 启动 = `pnpm dev` background + 等 port 5173；fixture seed = prisma seed script (固定 5 task / 3 round / 2 fallback)；视口 = 1440×900 desktop（v0.4 v1 不验证 mobile） |
| Lint baseline | `python3 references/kernel/tools/lint_all.py --legacy-baseline` ALL_GREEN |
| Type check | `cd apps/ccb-console/web && pnpm build` exit 0 |
| Vitest | `cd apps/ccb-console/web && pnpm test` 全过 |

## 风险

- **后端 projection endpoint 数据契约扩散**：3 个新 GET endpoint 都是投影；mitigation — endpoint 实现纯 SQL/Prisma + 单元测试 fixture
- **Capability matrix 视觉密度**：7 列 × N capabilities，N 大时 overflow；mitigation — 默认按 governance_critical 优先排序，N>10 时折叠
- **K1 apply endpoint 误触**：受控编排按钮一旦 click 即 mutate state；mitigation — 二次确认 dialog（用现有 Modal）+ guard status 不满足时 disabled
- **Activity Feed 性能**：跨项目查询；mitigation — 限 10 条 + index on EventJournal.at + Prisma cursor
- **Playwright baseline 维护成本**：每 page snapshot 一次确定基线；mitigation — 在 PR 模板提示 review snapshot diff 是否有意

## 后续

E12 archive 后下一波是 Wave 4 (E14 ReactiveScheduler + E15 parallel_join 全量)，那时 UI 才需要补 parallel_join 可视化（不在本 epic 范围）。

---

## v2 修订记录（codex round 1 共识落地）

- §5.3 加 endpoint 复用矩阵（3 新 + 2 复用，明确不重复定义 capability matrix 语义）
- §6.2 加 CapabilityMatrix 4 态来源说明（NodeRun.capability_decisions 主源 + global status 兜底）
- §6.3 加 Activity Feed event_type → tone/icon/文案/跳转 映射表
- §9 task 拆分 T3/T4 改成 backend(T3) + frontend(T4) 拆分，与 epic spec 对齐
- §10 验收 Playwright 补 dev server / fixture seed / 视口

