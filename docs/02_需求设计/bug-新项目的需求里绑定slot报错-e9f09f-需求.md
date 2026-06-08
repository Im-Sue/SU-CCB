---
id: cmq3lp9jy559ead7b3fe9f09f
title: BUG：新项目的需求里绑定slot报错
doc_type: requirement
status: delivered
created: 2026-06-07T09:50:00.096Z
analysis_input_hash: bf8c81f7a4d14de7921aef6ede94173d0598444ebffb2b6145e60331a5834b96
analysis_applied_at: 2026-06-07T10:23:14.058Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

我在一个新项目里（realtime_translator）的cmq3ll4ypc0b9319181f0ef14需求详情里操作绑定slot绑定后提示：slot terminal unavailable
我似乎发现我在realtime_translator项目的需求里绑定的slot1，在影响CCB项目的slot1的终端（我不确定，但是我感觉是这样的），还要联动思考下是否和cmq3m1i8r5ac97ea38323ee06这个需求会有什么关联性导致的吗？
我可以确定我在wsl的终端里运行了ccb![](./assets/requirements/cmq3lp9jy559ead7b3fe9f09f/3e02261477c3d58664453d3891a7461fb570aee280d2baddac6e2eb582a90612.png)
## 原话（verbatim）

我在一个新项目里（realtime_translator）的cmq3ll4ypc0b9319181f0ef14需求详情里操作绑定slot绑定后提示：slot terminal unavailable
我可以确定我在wsl的终端里运行了ccb![](./assets/requirements/cmq3lp9jy559ead7b3fe9f09f/3e02261477c3d58664453d3891a7461fb570aee280d2baddac6e2eb582a90612.png)

## 二、背景与目标

**现象**：在新项目 realtime_translator（Console projectId `cmq3i7ffr03xdqr8g4gb0khi2`，localPath `/home/sue/dev/realtime_translator/`）的需求 `cmq3ll4ypc0b9319181f0ef14` 详情页绑定 slot 后，终端面板提示 `slot terminal unavailable`。

**已核验事实链**（2026-06-07 实测）：

1. 绑定本身成功：Console DB `SlotBinding` 中 `cmq3ll4ypc0b9319181f0ef14 → slot-1, state=bound`（boundAt 2026-06-07T09:48:51Z）。
2. 报错来自绑定后的终端 resolver：`su-oriel/server/src/modules/slot-terminal/slot-terminal.service.ts:13` 硬编码 `SESSION_PREFIX = "ccb-su-ccb-"`；`resolveSessionName()`（同文件 :177-200）在项目自有 socket（`<projectRoot>/.ccb/ccbd/tmux.sock`）上 list-sessions 后只认该前缀。
3. ccbd session 命名真相源：codex-dual runtime `lib/project/ids.py:45-50`（`project_slug = <basename>-<sha256[:8]>`）+ `paths_ccbd.py:137-138`（session 名 = `ccb-<project_slug>`）。实测 realtime_translator session 为 `ccb-realtime_translator-a8ae9ed1`，SU-CCB 为 `ccb-su-ccb-08e65391`。
4. 因此任何目录名不是 SU-CCB 的项目，slot 终端 resolver 必然 `SlotTerminalNotFoundError` → 路由 404 → 前端 `console-api.ts:288` 显示 `slot terminal unavailable`（**Bug A**）。`resolveAgentGroupTerminal()` 复用同一 resolver，main 组 agent 终端（`/api/projects/:projectId/agent-terminal/:group`）在新项目同样失效。
5. 跨项目影响属实（**Bug B**）：`slot-context-reset.service.ts:141-142` 模块级单例默认 `new CcbdClientService()`（:49，全仓生产代码唯一无参用法）不带 projectRoot → `resolveCcbProjectRoot()` 从 server 进程 cwd 爬到 SU-CCB 根。bind 回调（`slot.routes.ts:92-118`、`slot-binding.service.ts:554-563` 两条消费路径）触发 `/new` 上下文重置时，`projectView()` 打到 SU-CCB 的 ccbd，按窗口名 `slot-1` 匹配 SU-CCB 的 slot1_claude/slot1_codex panes 并 send-keys——在 realtime_translator 绑 slot-1 会清空 CCB 项目 slot-1 双 agent 的会话。`input.projectId` 只回显进结果对象，不参与路由。

**目标**：新项目绑定 slot 后终端面板可用；绑定/解绑动作严格按项目隔离，不影响其他项目同名 slot。

## 三、讨论与决策

**Codex 协商**（1 轮 consult，job_50cf58e2d4cb，2026-06-07）：

- 同意 Bug A/B 归因，并补充新证据：(a) Bug A 影响面更宽——main 组 agent 终端同受影响；(b) bind 回调有两条消费路径；(c) 无参 `CcbdClientService()` 全仓生产代码唯一命中即 slot-context-reset，其余链路（syncSlotTips / job-slot-router / cancel / slot-resize）均显式传 projectRoot；(d) 新发现 `anchor-terminal/tmux.service.ts:8`、`native-terminal.service.ts:12` 仍硬编码 `ccb-su-ccb-task-`（有 `sessions[0]` fallback，非本 bug 直接根因，但新项目 anchor/worktree 终端存在脆弱性）。
- Codex 质疑并否决了我初版"该 socket 上任意 ccb-* session 即本项目"的修法：tmux socket 理论上可有手工/残留 session，应优先使用 ccbd `project_view.namespace.session_name`。已采纳。
- 建议：本需求最小修 A+B（option 1）；anchor-terminal 硬编码清理与 bridge 错误排查归 23ee06（option 2）。`analysis_depth_hint: human-decision`（范围边界需用户拍板）。

**Claude 4 锚点反思**：

- **我同意的**：(1) 否决"任意 ccb-* session"修法——ccbd `project_view.namespace.session_name` 是单真相源，Codex 给出了我没拿到的命名实现证据（ids.py/paths_ccbd.py），比前缀猜测可靠；(2) 本需求收口 option 1——bug 需求保持最小闭环，全仓默认 projectRoot 语义审计与 bridge 排查归 23ee06，避免单 bug 膨胀成全仓审计。
- **我不同意的**：Codex 把 anchor-terminal 硬编码完全划给 23ee06 而不在本需求留痕——23ee06 原话只覆盖"多 tab 数据错乱与 bridge 错误"，无人显式认领该脆弱点时存在两边漏接风险。处理：归属仍是 23ee06，但本需求在"六、边界/不做项"显式记录移交。
- **我的盲点**：(1) 低估 Bug A 影响面，漏看 main 组 agent 终端入口；(2) 没扫到 anchor-terminal 的 `ccb-su-ccb-task-` 硬编码；(3) 初版修法欠考虑残留 session 场景；(4) 漏看 bind 回调的第二条消费路径（slot-binding.service.ts:554-563）。
- **接下来做什么**：分析落盘本文档；范围拍板项升级用户（默认 option 1，可推翻）；本次 payload step=analysis，节点完成后自然停下不自动进技术设计；进入 technical_design 后重点定 Bug A 实现选型与跨项目回归用例。

**sc 指令替代说明**：`/sc:analyze`、`/sc:research`、`/sc:business-panel` 本环境未安装。替代覆盖：requirement-clarity 由原话逐句模糊点标注+歧义清单覆盖；research 由直接代码证据链覆盖（resolver 全链路追读、双项目 tmux 实测、Console DB 核验、ccbd 命名真相源定位）；business-panel 由必问项扫描覆盖（本地 dev 工具内部修复，无隐私/合规/成本新增面）。

**与需求 cmq3m1i8r5ac97ea38323ee06 的关联判定**（用户显式提问）：部分同根因——其"绑定 realtime 的 slot1 触发消息到 CCB 的 slot1"与本需求 Bug B 同根因；其"CCB 添加 slot 报 CCB bridge 错误"走 slot-resize 链路（`slot-resize.service.ts:122` 起显式注入 projectRoot），暂无证据归到同根因，需在 23ee06 内单独排查日志。

## 四、功能 / 范围

**本需求范围（默认按 option 1 推进，用户拍板可推翻）**：

1. 修复 Bug A：slot terminal resolver 去除 `ccb-su-ccb-` 硬编码，改为按项目解析 session（优先读 ccbd `project_view.namespace.session_name`；实现选型在 technical_design 定稿）。覆盖需求详情页 slot 终端与 main 组 agent 终端两个入口。
2. 修复 Bug B：slot context reset 的 ccbd 路由按目标项目构造（由 `project.localPath` 构造 per-project `CcbdClientService({projectRoot})`），移除跨项目单例 client，两条 bind 回调消费路径同步修正。
3. 回归保障：CCB 项目自身绑定/解绑/终端行为不回退。

**验收口径（原话未定义"修好"，以下为拟定默认）**：

1. 在任意目录名 ≠ SU-CCB 的新项目绑定 slot 后，需求详情页终端面板正常显示双 pane（claude/codex），不再出现 `slot terminal unavailable`。
2. 在项目 X 绑定/解绑 slot-N，项目 Y（≠X）的 slot-N 终端会话零影响（特别是 `/new` 不被跨项目注入）。
3. CCB 项目自身回归通过；main 组 agent 终端在新旧两类项目均可解析。

## 六、边界 / 不做项

1. `anchor-terminal/tmux.service.ts:8`、`native-terminal.service.ts:12` 的 `ccb-su-ccb-task-` 硬编码：本需求不修，显式移交 23ee06（在此记录防两边漏接）。
2. 23ee06 的 "CCB bridge 错误"排查：不在本需求范围（不同链路，证据未闭环）。
3. 不改 ccbd（codex-dual runtime）侧命名规则——以其为真相源做适配，不动 schema/协议。
4. 多 tab 并发与其他交互的系统性跨项目审计：归 23ee06。

## 七、开放问题 / 假设

1. 假设：ccbd 当前一项目一 namespace session（协商确认的现行为）；若未来一 socket 多 session，以 `project_view` 返回为准。
2. 假设：Oriel DB `project.localPath` 是项目根真相（与 docs-structure 契约一致）。
3. 已排除：slotCount 差异（CCB=5 / realtime=4）不构成 `isSlotId` 边界问题（`slot-binding.service.ts:376` 按派生集合成员检查，slot-1 在 4 槽项目合法）。

## 十三、风险

1. Bug A 若选"复刻 ccbd 命名规则"有双真相源漂移风险（python 实现变更时 TS 复刻悄然失效）——推荐优先读 `project_view`，复刻仅作降级。
2. Bug B 修复后 `/new` 重置将真正打到新项目 panes——需回归确认新项目 agent 对 `/new` 的处理与预期一致。
3. 残留/手工 tmux session 干扰 resolver 的容错语义需在技术设计中明确。

## Claude 解读

这是一个 Console(su-oriel) server 侧的多项目隔离缺陷，包含两个独立根因。Bug A（报错直接根因）：`su-oriel/server/src/modules/slot-terminal/slot-terminal.service.ts:13` 硬编码 `SESSION_PREFIX = "ccb-su-ccb-"`，导致任何目录名不是 SU-CCB 的项目（如 realtime_translator，实测 session=`ccb-realtime_translator-a8ae9ed1`）终端 resolver 必然 404，前端 `console-api.ts:288` 显示 "slot terminal unavailable"。绑定本身成功（Console DB 已核验 `cmq3ll4ypc0b9319181f0ef14 → slot-1, state=bound`）。影响面覆盖需求详情页 slot 终端与 main 组 agent 终端（`resolveAgentGroupTerminal` 复用同一 resolver）两个入口。Bug B（跨项目副作用，用户怀疑属实）：`slot-context-reset.service.ts:141-142` 跨项目单例（:49 无参 `CcbdClientService()` 默认解析到 server 自身项目根 SU-CCB），bind 回调触发 `/new` 上下文重置时经 SU-CCB 的 ccbd/tmux 按窗口名匹配并 send-keys——在 realtime_translator 绑 slot-1 会清空 CCB 项目 slot1_claude/slot1_codex 的会话上下文；`input.projectId` 只回显不参与路由。与需求 cmq3m1i8r5ac97ea38323ee06 部分同根因（其"绑 realtime slot1 触发消息到 CCB slot1"=Bug B；其"CCB bridge 错误"走 slot-resize 链路、显式 projectRoot，独立待查）。默认修复范围为最小修 A+B（option 1），anchor-terminal 硬编码与 bridge 错误移交 23ee06；范围拍板项已升级用户。
## 歧义点

1.【升级用户拍板中，默认已定】范围边界：本需求只修 Bug A+B（option 1，默认采纳），还是合并 anchor-terminal 硬编码清理与 23ee06 成一轮扩展修复（option 2）。已按 option 1 写入"四、功能/范围"，用户拍板可推翻；anchor-terminal 硬编码已在"六、边界/不做项"显式移交 23ee06 防两边漏接。2.【协商后收敛】Bug A 修复方向：原话未约束修法；经 Codex 质疑收敛为"优先读 ccbd `project_view.namespace.session_name`，复刻 ccbd 命名规则仅作降级（有双真相源漂移风险），'该 socket 上任意 ccb-* session' 因手工/残留 session 风险否决"。最终实现选型在 technical_design 节点定稿。3.【已拟默认】验收口径：原话未定义"什么算修好"；已拟三条默认验收（新项目终端可用 / 跨项目零影响 / CCB 自身回归+main 组终端两类项目可解析），见"四、功能/范围"，review 时可推翻。4.【已排除】slotCount 差异（CCB=5 / realtime=4）：`isSlotId("slot-1", 4)` 按派生集合成员检查通过（`slot-binding.service.ts:376` 代码核验），不构成歧义。说明：本需求为根因明确的 bug 类需求，歧义集中在范围与验收而非业务含义；隐私/合规/成本类不命中——本地 dev 工具内部修复，无新数据流、无新依赖、无外部服务调用。
## 保真差异

1. 用户感知"绑定后报错"→ 事实是绑定在 DB 层成功（state=bound），失败的是绑定后的终端面板解析；报错不阻断绑定状态机。2. 用户自述"我似乎发现在影响CCB项目的slot1的终端（我不确定）"→ 已证实为真，且比感知更具体：bind 触发的 `/new` 上下文重置被 send-keys 到 SU-CCB 的 slot1_claude/slot1_codex panes，会清空其会话上下文，属破坏性跨项目副作用。3. 用户问"是否和 cmq3m1i8r5ac97ea38323ee06 有关联"→ 判定部分同根因：其 slot1 跨项目消息症状与本需求 Bug B 同根因；其 "CCB bridge 错误"症状独立（slot-resize 链路显式传 projectRoot，证据未闭环），归 23ee06 单独排查。4. 用户强调"我可以确定我在wsl的终端里运行了ccb"（附截图）→ 采信且与诊断一致：runtime 侧正常（oriel 显示 slot1 双 agent 均在 realtime_translator），缺陷在 Console server 侧 resolver/路由，与用户操作无关。
