---
doc_type: technical_design
title: "需求详情页嵌入对应 slot 实时终端技术设计"
requirement_id: cmpm4dnh766ea74feb4b5c2d5
---

> 真相源：本文件为 plugin 独立产出的技术设计。可行性已由两轮 Codex 协商 + 端到端 PoC 验证闭环（见 §2），本设计确定「如何实现」。
>
> **需求归属**：本需求与 `07ae88（需求详情页的优化）` 同处「需求详情页」，但范围不重叠 —— 07ae88 是纯前端文档体验修复（明示不动后端/schema/依赖，已 consumed）；本需求是全栈实时终端集成。故立为**独立新需求**，本质是 ccb-console 新 feature。已在 Console 立项（md-first，`requirement_id: cmpm4dnh766ea74feb4b5c2d5`，status=drafting / planningStep=analysis），需求 md：`docs/.ccb/requirements/active/2026-05-26-需求详情页嵌入对应-slot-实时终端-b5c2d5.md`。

## 1. 目标与范围

把需求详情页当前的占位（`RequirementDetailPage.tsx:985` 的 `slotGuidancePanel` —— 一句"终端请在 ccb 原生 sidebar 查看对应 slot 窗口"）升级为**内嵌该需求对应 slot 的实时终端**，可观察 claude / codex 两个 agent，并支持向其输入指令。

**做**：
- 需求 → slot → tmux pane 的解析端点。
- 按 slot 单 pane 粒度的 WebSocket 终端镜像（capture-pane 帧推送）。
- 前端 xterm 终端面板（claude / codex 双 tab），替换现有占位。
- 向 pane 写入（无写锁，单人场景）。

**不做**：
- 不引 ttyd（见 §2 结论：attach 整个 session 才有"全暴露"问题；capture/send-keys 按地址寻址天生隔离单 slot）。
- 不做 writer lease 写锁（用户已拍板：单人使用，不考虑抢占）。
- 不做 sidebar pane 的镜像（只显 claude / codex）。
- 不改 tmux 拓扑、不改 slot 调度 / slot_binding 逻辑。

## 2. 可行性结论与 PoC 证据

方向**坐实**：不用 ttyd，复用 `capture-pane + WebSocket` 的"拍快照"路线。PoC（`tmp/slot-terminal-poc`，未动正式代码，7 个单测通过）实测：

| 指标 | 数据 | 含义 |
|---|---|---|
| capture 耗时 | avg 4.69ms / p95 5.35ms | 相对 200ms 间隔开销可忽略 |
| 单帧大小 | avg 2521B / p95 3516B | 带宽无压力 |
| CPU 增量 | +1.08pp（12.68% vs 11.6% 基线） | 双 pane 200ms 持续刷新成本低 |
| 变更帧比例 | 41.2% | changed-only 推送可省约 59% 带宽 |
| 端到端延迟 | 200.8ms ≈ 刷新间隔 | 延迟主要来自轮询间隔，非处理 |
| 输入验证 | 中文 / 退格 / 回车 / 方向键 / Ctrl-C 全通过 | send-keys 双向闭环成立 |

**核心洞察**：`capture-pane -t 会话:slot-N.pane` 与 `send-keys -t ...` 按地址精确寻址，可点到单个 slot 的单个 pane（已只读验证 slot-2.1 vs slot-3.1 互不串台）；"只能整个 tmux"是交互式 attach 的局限，本方案不 attach，故无此限制。

## 3. 架构设计

**映射链**（真相源已核实）：

```
Requirement.id
 → slot_binding(projectId, requirementId)          [SlotBindingService.findBindingForRequirement]
 → slotId (slot-1..5)
 → Project.localPath/.ccb/ccbd/tmux.sock
 → session (ccb-su-ccb-<hash>，list-sessions 取 ccb-su-ccb- 前缀)
 → window (window_name == slotId)
 → pane (按 window + pane role 解析 claude/codex，不靠 pane_index 硬编码)
```

**数据流**：
- 读：后端定时 `capture-pane -p -e -t <target>` → 规整 → 帧经 WS 推前端 → xterm 渲染。
- 写：前端键盘 / 输入 → WS → 后端按键映射 → `send-keys -t <target>` 灌入 pane。

## 4. 关键决策

| # | 决策点 | 结论 | 依据 |
|---|---|---|---|
| 1 | pane 寻址 | 按 `window_name=slotId` + `list-panes` 解析 claude/codex 角色，**不硬编码 index** | sidebar 可开关、pane 顺序会变（PoC 硬编码 `{sidebar:0,claude:1,codex:2}` 仅验证用） |
| 2 | 刷新策略 | changed-only 推送 + 可见性降频：活动 100–200ms / 静止 500–1000ms / 隐藏 tab 暂停或 1s 心跳 | PoC 实测 changed-only 省 ~59% 帧 |
| 3 | 需求→slot | 接 `slot_binding` 表 resolver（PoC 跳过了） | source of truth 比 `planningAnchorId` 可靠 |
| 4 | 渲染 | 全屏 repaint 会闪 → diff / 渲染节流；评估 `pipe-pane` 增量流替代全量 capture | PoC 用全量 repaint |
| 5 | 写入安全 | 无写锁（已定），但 UI **必须显式标注"正在写哪个 slot 的哪个 agent"**，写入需显式开关 | 防误打正在工作的 agent |
| 6 | 端点鉴权 | WS 接 Console 鉴权（PoC 是 127.0.0.1 裸开）；真实 socket **只读铁律**：仅 capture-pane，绝不 attach / resize-window / refresh-client -C | 避免污染正在工作 agent 的 client 尺寸 |
| 7 | 多 pane 呈现 | claude / codex 双 tab（默认只连可见 tab）；双列自适应可选 | PoC 双列已验证 |

## 5. 接口契约（草案，实施时定稿）

**解析端点**（只读）：
```
GET /api/projects/:projectId/requirements/:requirementId/slot-terminal
→ 200 { slotId, sessionName, panes: [{ role: "claude"|"codex", target, paneIndex }] }
→ 404 该需求无 slot 绑定 / slot 已回收
```

**WS 终端**：
```
WS  /api/slot-terminal/ws?projectId=&slotId=&pane=claude|codex
server→client: { type: "ready"|"frame"|"error", pane, generation, data, ... }
client→server: { type: "input"|"ping"|"close", data }
```

**前端**：新增 `SlotTerminalPanel`（xterm + claude/codex tab + 可见性降频），替换 `RequirementDetailPage.tsx` 的 `slotGuidancePanel`。PoC `server-lib.mjs` 的按键映射（`keyToTmuxSendArgs` / `inputToTmuxSendArgsList` —— 已覆盖 Enter/方向键/Ctrl-C 等，文本走 `-l`）可移植为正式 lib。

## 6. 安全边界

- 真实 tmux socket **只读**：捕获仅 `capture-pane -p -e`；写入仅 `send-keys -t`；禁止任何改 client 尺寸 / attach 的命令。
- WS 端点须接 Console 现有鉴权，不暴露裸端口。
- 写入路径需后端二次校验 target 属于该 project 的 managed session（防越权写到其他 slot / 任意 pane）；slot/session/pane 入参做白名单校验（PoC 已有 `SLOT_PATTERN` / `SESSION_PATTERN` / pane 范围校验，移植）。
- 无写锁是已知取舍：人工输入与系统派工（`ccb ask`/dispatch 同样 send-keys）可能文字交错，靠 UI 标注 + 用户自律规避，不在本期做忙闲协调。

## 7. 任务切片（拆分铺垫）

| 切片 | 内容 | 依赖 |
|---|---|---|
| T1 后端 resolver | `slot-terminal` 端点：查 slot_binding + list-panes 解析 claude/codex pane role，返回 target | — |
| T2 后端 WS（读） | capture 镜像 + changed-only + 可见性降频；移植 PoC server-lib 帧逻辑；只读铁律守卫 | T1 |
| T3 后端 WS（写） | send-keys 输入映射（移植 PoC 按键表）+ target 越权校验 | T2 |
| T4 前端面板 | `SlotTerminalPanel`（xterm 双 tab + 降频/暂停）替换 `slotGuidancePanel` 占位 + 写入目标 UI 标注 | T1 |
| T5 安全收口 | WS 接 Console 鉴权；端到端只读/写入回归 | T2,T3,T4 |

估算：中等复杂度，全栈，T2/T3 是主要风险点（刷新策略 + 控制键转义）。

## 8. 风险与未决

- **R1 渲染闪烁**：全屏 repaint 在高频更新时闪，T4 需 diff/节流，必要时回到 §4-4 的 `pipe-pane` 增量流。
- **R2 slot 重绑/回收**：slot 与需求是 sticky 绑定，若 slot 被回收或重绑，前端视图需感知并降级（解析端点返回 404 → 回退到占位提示）。本期需定义降级 UX。
- **R3 衔接**：已 Console 立项（`cmpm4dnh766ea74feb4b5c2d5`，status=drafting / planningStep=analysis）。正式拆分（breakdown draft）前需走 requirement_analysis 衔接 —— 技术设计已完成，可走精简分析把本文件结论回填到需求的解读 / 歧义字段。
- **未决（交用户/实施期）**：刷新间隔的最终默认值；是否首屏并排双 pane（建议 MVP 仅 tab）。
