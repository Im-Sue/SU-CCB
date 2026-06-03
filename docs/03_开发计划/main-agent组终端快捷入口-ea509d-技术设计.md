---
doc_type: technical_design
title: main agent 组终端快捷入口技术设计
requirement_id: cmpxp7yyc6ff3ff4e15ea509d
updated: 2026-06-03
---

# main agent 组终端快捷入口 技术设计

> 一句话：复用需求详情页 slot 终端的下层 substrate，新增一条「按 agent-group(main) 寻址」的并行端点 + 全局悬浮入口弹窗，需求页零行为变化。｜ 最后更新：2026-06-03
>
> **无独立 status** —— 跟随 `requirement_id` 指向的需求（`docs/02_需求设计/增加一个main-agent组的快捷入口-ea509d-需求.md`，status=planning）。

---

## 一、设计概述

| 项 | 说明 |
|----|------|
| 名称 | main agent 组终端快捷入口 |
| 核心职责 | 全局悬浮入口 → 弹窗内嵌 main 组(main_claude/main_codex)实时终端，复用 slot 终端的捕获/帧推/输入能力 |
| 设计原则 | 端点并行不复制核心；冻结现有 requirement 契约；抽 substrate 不污染 requirement 组件；只读铁律(只 capture/send-keys，绝不 attach/resize)；全程 additive |
| 需求来源 | `docs/02_需求设计/增加一个main-agent组的快捷入口-ea509d-需求.md` |
| 覆盖范围 | 后端 agent-group 终端 resolver + 平行守卫 + WS + audit 泛化；前端 substrate 抽取 + MainTerminalPanel + 全局悬浮 launcher + Modal 变体 |
| 不覆盖 | a4017f 入口(独立需求)；任意 window 浏览(只开 main)；多用户权限；全局写锁；DB schema/migration |

---

## 二、方案与架构

```
[全局悬浮 MainTerminalLauncher]  (挂 ConsoleLayout，避开右下角：Toast+a4017f 已占)
   │ click
   ▼
[Modal(contentClassName 变体)] ──装──> [MainTerminalPanel] (main 专用薄壳)
                                            │ target = {kind:"agentGroup", group:"main"}
                                            ▼
                  ┌──── 复用 substrate (requirement-agnostic) ────┐
                  │ TerminalPaneTabs · TerminalSurface · createTerminalClient │
                  └───────────────────────┬───────────────────────┘
                                          │ WS /api/agent-terminal/ws?group=main&pane=
                                          ▼
                  [共享 WS handler 核] (subscription resolver: target union)
                    ├─ frame pump (capture-pane -p -e, changed-only)   [复用零改]
                    └─ input queue (per-conn 串行) + 每写前 guard        [复用零改]
                                          │
                  resolveAgentGroupTerminal({group:"main"})
                    │ allowlist{main} + role 唯一性/agent 名校验
                    ▼
                  resolveSlotPanes({slotId:"main"})                     [复用零改]
                    │ tmux list-panes -t <session>:main → claude %1 / codex %2
                    ▼
                  main_claude / main_codex pane

并列（契约冻结，不动）：
[需求详情页 SlotTerminalPanel(零改)] → 同一 substrate → /api/slot-terminal/ws?requirementId=
```

| 关键原则 | 为什么 |
|----------|--------|
| 端点并行、核心共享 | 冻结刚交付的 requirement 契约/测试面，又不复制 WS/guard/input 大函数 |
| substrate 抽在 Panel 之下 | `SlotTerminalPanel` 含绑定状态/绑定动作/fallback 文案 = requirement-specific，泛化它会污染通用组件；抽下层 viewer/client 才干净 |
| 只读铁律 | 真实 tmux socket 仅 `capture-pane` + `send-keys`/`paste-buffer`，绝不 attach/resize/refresh-client -C（会污染编排 agent 的 client 尺寸）；对 main 尤其关键 |
| allowlist + role 唯一性 | 防任意 window 捕获；防 main window 未来多 claude/codex runtime 时 `break` 静默取错首 pane |

**与现有系统的关系 / 边界**：

| 涉及模块 | 本设计如何动它 | 保留 / 不动 |
|----------|----------------|-------------|
| `slot-terminal.service.ts` | 新增 `resolveAgentGroupTerminal` + `assertTargetBelongsToAgentGroup` + 抽私有 `matchPane` | `resolveRequirementTerminal` / `resolveSlotPanes` 零改 |
| `slot-terminal.ws.ts` | 抽共享 handler 核 + subscription resolver 泛化 target union；新增 `/api/agent-terminal/ws` 薄路由 | `/api/slot-terminal/ws` 路由字节不变 |
| `slot-terminal.routes.ts` | 新增 `GET /api/projects/:projectId/agent-terminal/:group` | 现有 requirement 路由不动 |
| `slot-terminal.input.ts` | audit 事件 additive 加 `contextKind/contextId`；文件名按 context | `requirementId` 字段保留；writer 零改 |
| web `slot-terminal/*` | 抽 `TerminalPaneTabs/TerminalSurface/createTerminalClient` substrate；`SlotTerminalPanel` 改薄壳调 substrate(行为不变) | xterm / FrameRenderer 零改 |
| web `ui/Modal.tsx` | 加 additive `contentClassName?` | 现有调用零改 |
| web `App.tsx(ConsoleLayout)` | 挂 `MainTerminalLauncher` | 其余不动 |

---

## 三、关键决策与取舍

> Claude/Codex 协商结论落点（consult `job_b99e9bc57b6b` / reply `rep_0228fdd6d0b4`，达成共识 + 3 项修正）。

- **后端复用形态**：选「端点并行 + 内部共享核」(Opt1+)。否决「单一泛化端点」(动 ready descriptor / client parser / 现有测试 / 已交付需求页，回归面不抵收益)、否决 sentinel 假 requirementId(污染 guard/audit/需求语义)、否决复用 `/main-terminal/spawn`(native attach，非内嵌 xterm)。
- **前端接缝**（Codex 关键修正，我接受）：选「抽 Panel 之下的 substrate + 新建 `MainTerminalPanel`」。否决「把 `SlotTerminalPanel` 泛化成判别联合」—— Panel 含绑定状态/动作/fallback = requirement-specific，泛化会把需求语义分支塞进通用组件且改需求页行为。
- **main pane 解析硬化**（Codex 提出的盲点）：`resolveAgentGroupTerminal` 除 allowlist `{main}` 外，再校验 role 唯一性(每 role 恰一 pane) / 预期 agent 名，拒绝 main window 出现多 claude/codex runtime 时静默取首 pane。
- **写入**：默认可写(用户拍板)；每条 input 写前重解析 + guard `target ∈ main panes`；保留写入目标红字标注；承认多 tab/多窗口无全局写锁的输入交错(单人取舍)。
- **audit**（Codex 修正）：additive —— requirement 事件**保留** `requirementId`(测试/日志格式依赖)，**新增** `contextKind/contextId`；main 落 `agent-group-main.jsonl`。

**4 锚点反思（对 Codex 协商）**：
- **我同意**：① 前端抽 substrate 在 Panel 之下、另起 `MainTerminalPanel`(更稳、需求页零行为变化)；② `resolveSlotPanes` 选 pane 不校验 agent_name，需加 role 唯一性/agent 名校验防未来取错；③ audit additive 保留 `requirementId` 而非替换。
- **我修正**：初版「参数化 `SlotTerminalPanel` 吃 target 联合」会污染 requirement 组件 —— 接受抽下层 substrate。
- **我的盲点**：① 没意识到 `SlotTerminalPanel` 含 bind 状态/动作/fallback 的需求语义(不只是终端壳)；② 没想到 main pane role 唯一性的未来风险；③ audit 替换会动现有测试/日志格式。
- **接下来**：定稿本设计 → 判断进入 task_breakdown；实现期死守「共享核不复制」「需求页零改」两条红线。

---

## 四、核心流程 / 逻辑

**主链路 1 · 读（帧镜像）**：
```
MainTerminalPanel mount
 → fetchTerminalDescriptor(target=agentGroup:main)
 → GET /api/projects/:pid/agent-terminal/main
 → resolveAgentGroupTerminal: allowlist{main} → findProject → resolveSlotPanes({slotId:main})
       → role 唯一性校验 → { slotId:main, sessionName, panes:[claude %1, codex %2] }
 → 前端按 pane 开 WS /api/agent-terminal/ws?projectId=&group=main&pane=claude
 → 共享 frame pump: capture-pane -p -e -t %1，changed-only(活 150ms/静 1s/隐藏暂停) → frame → xterm
```

**主链路 2 · 写（默认可写）**：
```
xterm 输入 → WS {type:input|paste, data}
 → 共享 input queue(per-conn 串行)
 → 每条写前 assertTargetBelongsToAgentGroup({group:main, role, target}) 重解析比对 target∈main panes
 → TmuxSlotTerminalInputWriter.sendInput/sendPaste(target=%1)            [复用]
 → audit recordInput({contextKind:"agent-group", contextId:"main", ...}) → agent-group-main.jsonl
```

**空态 / main 未起**：
```
resolveAgentGroupTerminal 抛 SlotTerminalNotFoundError(session/window/pane 缺) → 404
 → MainTerminalPanel 显 fallback「main 会话未启动，请在 ccb 启动后重试」→ 不连 WS
```

| 处理规则 | 怎么保证 |
|----------|----------|
| 写前重解析 target | 每条 input 走 guard，防 target 漂移 / 越权写到非 main pane |
| 输入交错 | per-conn 串行；跨连接无全局锁(单人取舍)，UI 红字标注写入目标 |
| changed-only 降频 | 复用现有 frame pump，活 150ms / 静 1s / 隐藏 tab 暂停 |
| 失败降级 | descriptor 404 → fallback 文案；WS capture 失败 → close 1011(复用) |
| 只读铁律 | 仅 capture-pane / send-keys / paste-buffer；review + 测试守 grep 无 attach/resize/refresh-client |

---

## 五、测试策略

- [ ] 单元(后端)：`resolveAgentGroupTerminal`(allowlist 拒非 main / role 唯一性拒多 runtime / resolveSlotPanes(main) 解析 %1%2)；`assertTargetBelongsToAgentGroup`(越权 target 拒)；audit additive(新增 contextKind/contextId 且 requirement 事件仍含 requirementId)。
- [ ] 单元(前端)：substrate(`TerminalSurface/createTerminalClient` 吃 target 联合；requirement target 行为快照不变)。
- [ ] 集成：`GET /agent-terminal/main` 解析；`/agent-terminal/ws` 帧推 + 输入 + guard；main 未起 → 404 → fallback。
- [ ] **回归(关键)**：需求详情页 `SlotTerminalPanel` 行为/契约零变化(`/api/slot-terminal/ws` 字节不变 + requirement audit 格式不变)。
- [ ] 端到端：悬浮入口 → 弹窗 → main 双 pane 实时帧 → 输入回显 → 关弹窗断 WS。

---

## 六、数据设计

无数据模型 / DB schema / migration 变更。`slot_binding` 表不动；main 不进 slot_binding(它是 `lane:coordination`/`canBindBusiness:false`)。input audit 为**文件型** jsonl(`data/slot-terminal/input-audit/<context>.jsonl`)，泛化仅改文件名与事件字段，见 §八 / §十。

---

## 七、接口设计

| 端点 | 方法 | 作用 | 认证 |
|------|------|------|------|
| `/api/projects/:projectId/agent-terminal/:group` | GET | 解析 agent-group(仅 main)终端 descriptor | 复用 Console 现有鉴权 |
| `/api/agent-terminal/ws?projectId=&group=&pane=` | WS | main pane 帧镜像(读) + send-keys(写) | 复用现有 WS 鉴权 + 每写 guard |

descriptor 复用 `SlotTerminalDescriptor` 形如 `{ slotId:"main", sessionName, panes:[{role,target,paneIndex}] }`；WS 帧/输入消息复用现有 `ready/frame/error` 与 `input/paste`。现有 `/api/projects/:projectId/requirements/:requirementId/slot-terminal` 与 `/api/slot-terminal/ws` **契约冻结不变**。

---

## 八、文件结构 / 变更清单

**后端**：
- `[MODIFY] slot-terminal.service.ts`：新增 `resolveAgentGroupTerminal` + `assertTargetBelongsToAgentGroup` + 私有 `matchPane`(两守卫共用) + `AGENT_GROUP_WINDOWS={"main"}` allowlist + role 唯一性校验
- `[MODIFY] slot-terminal.ws.ts`：抽共享 handler 核 + subscription resolver 泛化 target union；新增 `/api/agent-terminal/ws` 薄路由（**不复制大函数**）
- `[MODIFY] slot-terminal.routes.ts`：新增 `GET /api/projects/:projectId/agent-terminal/:group`
- `[MODIFY] slot-terminal.input.ts`：`SlotTerminalInputAuditEvent` 加 `contextKind/contextId`(additive)；`recordInput` 文件名按 context；`requirementId` 字段保留

**前端**：
- `[NEW] components/slot-terminal/` substrate：`TerminalPaneTabs` / `TerminalSurface`(=旧 `SlotTerminalSurface` 抽 target) / `createTerminalClient` + `buildTerminalWsUrl` + `fetchTerminalDescriptor`(target 联合)
- `[NEW] components/slot-terminal/MainTerminalPanel.tsx`：main 薄壳(target=agentGroup:main + main fallback 文案，无 bind 动作)
- `[MODIFY] components/slot-terminal/SlotTerminalPanel.tsx`：改调 substrate 传 `{kind:"requirement"}`（行为/UI 不变）
- `[NEW] components/.../MainTerminalLauncher.tsx`：全局悬浮(挂 ConsoleLayout，避开右下角，`fetchSlots().main.state` 做可连指示)
- `[MODIFY] components/ui/Modal.tsx`：加 `contentClassName?`(additive)
- `[MODIFY] App.tsx(ConsoleLayout)`：挂 `MainTerminalLauncher`
- `[MODIFY] lib/console-api.ts` + `types/slot-terminal.ts`：target 联合类型 + `fetchTerminalDescriptor`

---

## 九、依赖与配置

无新依赖(xterm / ws 已在)。

| 配置 key | 默认值 | 说明 |
|----------|--------|------|
| `AGENT_GROUP_WINDOWS` | `{"main"}` | 允许内嵌终端寻址的 agent-group window 白名单 |
| frame 间隔 | 复用现有常量 | 活 150ms / 静 1s |
| launcher 角位 / modal 高度 | 前端常量 | 实现期定，避开右下角 |

---

## 十、迁移影响与风险

- **受影响**：slot-terminal 前后端模块、Console `Modal`/`ConsoleLayout`。**无 DB / 无 migration**。
- **打法**：后端先并行端点 + 共享核(需求路径零改)；前端先抽 substrate 跑通需求页回归，再加 `MainTerminalPanel` / launcher。
- **回滚 / 恢复**：纯增量，`git revert` 即可；无数据态。

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 抽 substrate 改坏需求页 | 中 | 高(刚交付) | 需求页行为快照 + 契约冻结回归；substrate 先承载 requirement target 再加 main |
| 共享核退化成复制粘贴 | 中 | 中(维护债) | 设计明确单一 handler 核 + target 联合；review 守 |
| main pane role 取错 | 低 | 中 | role 唯一性 / agent 名校验，多 runtime 即拒 |
| 写入误触编排层 | 中(用户已受) | 中 | 写前 guard + 红字标注；只读铁律 |
| `resolveSessionName` 撞多会话 | 低 | 中 | 继承现状(实测单会话)；可加 session 校验(实现期评估) |
| 多窗口写交错 | 低 | 低 | per-conn 串行 + 单人取舍，不做全局锁 |
| paste 短暂占 tmux buffer | 低 | 低 | `-d` 用后即删(复用) |

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-06-03 | v1.0 | 初版(Claude 设计 + slot2_codex 协商 `job_b99e9bc57b6b` 定稿；3 项修正：前端抽 substrate / main role 唯一性 / audit additive) |
