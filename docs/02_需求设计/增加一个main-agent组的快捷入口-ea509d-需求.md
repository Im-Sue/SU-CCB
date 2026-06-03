---
id: cmpxp7yyc6ff3ff4e15ea509d
title: 增加一个main agent组的快捷入口
doc_type: requirement
status: delivered
created: 2026-06-03T06:41:54.612Z
analysis_input_hash: bc13e83265967ad9437f1b7174e33118bf97a3baaadd961b5ce64f0ca22677a5
analysis_applied_at: 2026-06-03T08:04:14.893Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

增加一个main agent组的快捷入口，全局悬浮的，并且点击直接打开页面弹窗，弹窗内容和需求详情页里的终端组件一样即可。

## 原话（verbatim）

增加一个main agent组的快捷入口，全局悬浮的，并且点击直接打开页面弹窗，弹窗内容和需求详情页里的终端组件一样即可。

## 二、背景与目标

需求详情页已交付「内嵌对应 slot 实时终端」（claude/codex 双 pane、capture-pane 帧推 + send-keys 写入），但该终端只能从某个具体需求详情页进入、且只显示该需求绑定的业务 slot。CCB 的 main 组（`entry_window=main` 的 main_claude / main_codex）是全局常驻的协调 / 决策层，目前在 Console 内没有任何内嵌终端入口，只能去 tmux pane 或用 `/main-terminal/spawn` 开原生终端看。

**目标**：在 Console 内提供一个不依附任何需求、全局可达的悬浮入口，点击直接打开弹窗，弹窗内复用需求详情页那套终端的 UI 与交互（claude/codex 双 pane xterm、可输入），数据源指向 main 组的两个 pane，让用户随时监看并操作 main 组。

## 三、讨论与决策

经 1 轮 Codex 协商（job_9d2c09fdc9c3）+ 用户拍板：

- **写入能力**：用户拍板「完全和需求详情页终端一样，默认可写」。即弹窗内可直接对 main_claude / main_codex 输入（send-keys），保留现有「正在写 main 的 claude/codex」红字写入目标标注。用户已知悉并接受「往正在编排的决策层 stdin 打字可能打断在途任务」的风险，选择便利优先。
- **与兄弟需求 a4017f 的关系**：用户拍板「两个独立悬浮入口，分占不同屏幕角」，不合并成统一 launcher。a4017f（推进中需求快捷入口）原话占用右下角，故本 main 入口须避开右下角、另选一角，二者实现解耦。
- **技术路线（设计输入，非本节点定稿）**：Codex 给出 3 个方案，推荐 Opt 1「最小全栈并行路径」——新增 main / agent-group 寻址 resolver + WS target scope + 对应 guard / audit scope，复用 `resolveSlotPanes`、帧推泵、输入写入器与前端 xterm surface（需把 surface / WS client 从写死 requirementId 抽成可复用 substrate）。Opt 2「泛化 slot-terminal 为 `targetType=requirement|agent-group`」架构更干净但触及现有协议与测试面，留待 technical_design 评估。

**Claude 对 Codex 协商的 4 锚点反思**：
- **我同意**：main 可复用 `resolveSlotPanes({ slotId: "main" })`；写入 main 不是过度担心（现有 input 把 Ctrl-C / 粘贴 / 多行直接 send 到协调层 pane，误触面高于业务 slot）；a4017f 交互层应慎重协调，避免抢角与 z-index。
- **我修正**：原判「『一样』对前端为真」过于乐观——Codex 正确指出 `SlotTerminalSurface` / `createSlotTerminalClient` 也写死 requirementId、ready descriptor 还要求 `readonly:false`，故是「两端都抽 substrate」而非「换数据源」。接受。
- **我的盲点**：① 误把隐私判成「不命中」——main 全局入口聚合跨需求内容、无 requirement 边界（经「单人本地使用」既有决定降级为 audit-scope 设计项）；② 漏了 Modal 滚动层布局回归；③ 漏了 main 写入需新 audit key / target scope（现有 audit 必填 requirementId）。
- **接下来**：已就 2 个高影响项升级用户拍板（写入能力、与 a4017f 关系）；技术路线默认 Opt 1、Opt 2 留 technical_design；本节点完成后判断进入技术设计。

> 注：用户对「写入能力」拍板为「默认可写」，与 Codex「默认只读」建议相左；这是用户对便利 / 风险的取舍，已记录于上方决策与风险章节，实现侧遵从用户决定。

## 四、功能 / 范围

1. 一个全局悬浮入口（浮标 / 按钮），在 Console 各页面常驻可见，避开 a4017f 占用的右下角。
2. 点击直接打开弹窗（modal），无需中间跳转。
3. 弹窗内是 main 组的实时终端：claude / codex 双 pane（tab 切换），复用需求详情页终端的渲染与交互。
4. 终端默认可写：可对当前 pane 输入并回显，带写入目标标注。
5. 数据源固定指向 main 组（window_name=`main`，按 runtime.json 解析 claude / codex pane），不依赖任何 requirement 绑定。

## 五、业务规则

- main 组是 `lane:"coordination"`、`canBindBusiness:false`；本入口只读写其终端，不触碰 slot_binding，不对 main 做 bind / release / archive / cancel。
- 写入目标必须显式标注（沿用现有红字标注），让用户清楚正在往 main 的哪个 pane 打字。
- main 组在项目内是同一个（项目级常驻），入口不随需求切换而变。

## 六、边界 / 不做项

- 不复用 `/main-terminal/spawn` 的原生终端通道（那是本机 attach，不满足「页面弹窗内嵌」）。
- 不在本需求内合并 a4017f 的入口（用户拍板分开）。
- 不新增 kernel capability / transition（本阶段不动协议内核）。
- 不改 main 组的 agent 构成或 tmux 拓扑。
- 不做多用户权限模型（项目已拍板单人本地使用）。

## 七、开放问题 / 假设

**假设**：
- 「main agent 组」= 当前项目 `entry_window=main` 的 claude / codex 双 pane（已核验）。
- 用户要的是浏览器内嵌 xterm，不是外部 native terminal（已由用户拍板「和需求终端一样」确认）。
- 单人本地使用，故 main 终端聚合跨需求内容的可见性不构成用户暴露问题，降级为 audit-scope 设计项。

**留给 technical_design 的设计决策（非用户拍板项）**：
- Opt 1 vs Opt 2 寻址路线最终选型。
- main 写入的 audit key / target scope 怎么落（现有 audit 必填 requirementId）。
- 悬浮入口具体落哪一角、弹窗尺寸、关闭后 WS 是否断开。

## 八、拆分预览

预计全栈，粗分（最终切片在 task_breakdown 节点定）：
1. 后端：main / agent-group terminal resolver（复用 `resolveSlotPanes({ slotId: "main" })`）+ WS target scope + guard / audit scope。
2. 前端 substrate：把 `SlotTerminalSurface` / `createSlotTerminalClient` 从写死 requirementId 抽成可复用 substrate（按 targetType / target 寻址）。
3. 前端入口：全局悬浮按钮 + 弹窗壳（处理 Modal 滚动层 / 稳定高度），接入 substrate 指向 main。

## 十一、界面 / 页面布局

- 全局悬浮浮标：Console 各页面常驻，避开右下角（a4017f 占用），具体角位设计时定。
- 弹窗：modal 内嵌 main 组双 pane 终端；需解决 Modal 默认 `overflow-y:auto` 与终端 surface 稳定高度 / 单滚动层的冲突。

## 十二、交互 / 流程

1. 用户在任意 Console 页面点击悬浮浮标。
2. 直接弹出 modal（无中间页跳转）。
3. modal 内显示 main 组 claude / codex 双 pane 终端，默认连上实时帧。
4. 用户可在当前 pane 输入（默认可写），带写入目标标注。
5. 关闭 modal（WS 生命周期设计时定）。

## 十三、风险

- **写入误触**（用户已接受）：默认可写，往 main 协调层 pane 误发 Ctrl-C / 粘贴 / 多行可能打断在途编排，影响面高于业务 slot；靠写入目标标注缓解。
- **审计语义缺口**：现有 input audit 必填 requirementId 并落需求文件；main 写入无 requirementId，需新 audit key / target scope，否则写入不可审计。
- **前端复用比预期深**：surface 与 WS client 也写死 requirementId，需抽 substrate，改动面比「换数据源」大。
- **Modal 布局回归**：Modal 默认 `overflow-y:auto` 与终端 surface 稳定高度 / 单滚动层冲突，直接塞有布局回归风险。
- **重复拉流性能**：弹窗与某需求详情页可能同时开 WS，capture-pane 150ms + 初始历史重复拉取。

## Claude 解读

「main agent 组的快捷入口」= 在 Console 内新增一个不依附任何需求、全局悬浮的入口，点击直接弹出 modal，modal 内复用需求详情页那套终端组件（claude/codex 双 pane xterm + 输入），但数据源从「某需求绑定的业务 slot」改为「main 组的 main_claude / main_codex 双 pane」（window_name=`main`，已核验 runtime 可按同一套 pane 解析机制寻址）。

关键判断：「弹窗内容和需求详情页里的终端组件一样即可」这句对**前端呈现 / 交互**成立（同样双 pane、同样可输入），但对**后端寻址**不成立——现有终端整条链路（HTTP 路由、WS 参数、`assertTargetBelongsTo` 鉴权、input audit）都硬绑定 requirementId 与 slot_binding，而 main 既无 requirementId 也不在 slot_binding（main 是 `lane:"coordination"`、`canBindBusiness:false`）。因此本需求是**全栈**：需新增「按 main / agent-group 寻址」的并行路径，并把前端终端 surface（`SlotTerminalSurface` / `createSlotTerminalClient` 也写死 requirementId）抽成可复用 substrate，而非纯前端换数据源。复用程度高（pane 解析 `resolveSlotPanes`、帧推泵、输入写入器可直接复用），但不是「照搬」。

用户已拍板：① 终端默认可写（保持「一样」字面语义，接受往协调层 stdin 误触的风险）；② 与兄弟需求 a4017f 的全局悬浮入口分开实现、分占不同屏幕角（main 避开 a4017f 占用的右下角）。
## 歧义点

原文一句话，歧义来自系统现状而非文本。已核验 + 处理：

1. **「一样即可」的复用边界（P0）**：是复用前端组件 + 新寻址路径，还是连后端端点都复用？→ 已核验：后端整条链 requirement-bound，main 无法照搬，必为全栈新增 main 寻址路径；Codex 进一步指出前端 surface / WS client 也写死 requirementId，需抽 substrate。**处理**：判定为全栈，技术路线（Opt1 最小并行路径 vs Opt2 泛化 `targetType`）留 technical_design 选型。
2. **写入能力（P0 · 命中必问 · 用户已拍板）**：main 是协调 / 决策层 pane，默认可写 = 可往「正在编排的 claude / codex」stdin 注入。→ **用户拍板：完全和需求终端一样，默认可写**，保留「正在写 main 的 claude/codex」红字写入目标标注，接受误触打断在途编排的风险。
3. **与 a4017f 的全局悬浮入口冲突（P1 · 命中必问 · 用户已拍板）**：两需求都要全局悬浮，抢屏幕角与 z-index 层级。→ **用户拍板：两个独立入口分占不同角**，a4017f 占右下角，本 main 入口避开右下角另选一角，二者实现解耦。
4. **可见性 / 隐私（P1 · 引用既有决定）**：main 入口聚合跨需求编排 / 内部决策内容、无 requirement 语义边界（Codex 提出）。→ 引用项目「单人本地使用」既有拍板：非用户暴露问题，降级为「main 写入 audit-scope」设计项。
5. **弹窗 / 连接生命周期（P1 · 设计项）**：modal 关闭后 WS 是否断开、main 会话未起的空态、与详情页同开的重复拉流。→ 非用户决策，留 technical_design。
6. **pane 构成（P2 · 低歧义）**：main 双 pane → 同样 claude / codex 双 tab，已核验，无需追问。
## 保真差异

- 原话「弹窗内容和需求详情页里的终端组件一样即可」——我未按字面理解为「后端照搬同一端点 / 同一组件」。核验后认定后端寻址无法复用（main 非 requirement-bound），「一样」只在前端呈现 / 交互层成立。这是对字面「一样」的**收窄解释**，依据已在 Claude 解读说明。
- 原话「全局悬浮」未指定屏幕角与页面范围——我结合 main 的项目级语义，理解为「项目内各页面常驻」，并因 a4017f 已占右下角而约束本入口避开右下角。屏幕角具体值属设计细节。
- 原话「快捷入口」「点击直接打开页面弹窗」——我理解为单击直出 modal、无中间页跳转。
- 原话未提写入 / 只读——字面「一样」可推得「可写」，已由用户拍板确认（默认可写），消除该推断的不确定性。
- 我**补充**了原文未提但实测存在的约束（main pane 按 window_name=`main` + runtime.json 寻址、Modal 默认 `overflow-y:auto` 与终端 surface 稳定高度冲突、现有 input audit 必填 requirementId 而 main 无）作为设计输入，**不改变需求范围**。
