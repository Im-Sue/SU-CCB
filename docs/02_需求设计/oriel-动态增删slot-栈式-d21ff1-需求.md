---
id: cmmq2a2x3p25029cbd6d21ff1
title: "oriel 支持动态增删 slot（栈式）"
doc_type: requirement
status: delivered
created: 2026-06-06T11:37:17.887Z
analysis_input_hash: bffe03d0c24e1c7f91a298a0aba28b0935b2278013c732e9be9e20246fb543ad
analysis_applied_at: 2026-06-06T11:50:13.919Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

oriel console 支持按项目动态调整业务 slot 数量（当前硬编码 3 个）：managed config 按 slot 数量参数化生成，调度层 SLOT_IDS 动态化，新增 `ccb reload` 集成实现运行中增删 slot（不重启项目、不干扰其他 slot）。已拍板栈式语义（方案 A）：slot 编号永远连续，只从尾部增删；删除要求尾部 slot 无绑定，busy 则拒绝。

## 原话（verbatim）

> 我现在的.ccb的ccb.config里是有3个slot的，如果我现在想追加slot，直接改ccb.config我们的oriel会自动加载到对应的solt吗？还有slot拓扑会有什么情况？

> 首先我们先确定一下，CCB本身已经支持动态加载slot和对应的agent了对吧？如果它支持的话，那么也就是说我们本质上也可以支持

> ok，我们回到正轨，现在我想让oriel可以支持动态增删slot是否支持、可行？大概需要做哪些改动？

> 先按照方案A立项

（注：「方案 A」指 Claude 提出、用户拍板的栈式增删——slot 编号永远连续，只从尾部增删；删除要求尾部 slot 无绑定，busy 则拒绝。备选「方案 B 任意删（允许编号空洞）」被用户放弃。）

## 二、背景与目标

2026-06-06 用户实验「手改 ccb.config 追加 slot-4」全链路验证：CCB bridge v7.3.2 `ccb reload` 可动态 add_window/add_agent/remove idle（fail-closed、对运行中 slot 零干扰，实测成功）；但 oriel 三层硬编码使手改不可持久——managed-config.service.ts 白名单（MANAGED_WINDOW_NAMES/MANAGED_AGENT_NAMES/AGENT_CORE）导致 syncSlotTips 触发的 ensureManagedCcbConfig 回写抹除 slot-4（实测 11:09:54Z 发生），随后 ccbd 重启 reconcile 将 slot-4 window/agents/目录连根回收（实测 11:10Z）；slot-binding.service.ts SLOT_IDS 硬编码使 slot-4 永远收不到需求派发。

**目标**：oriel 原生支持按项目动态调整业务 slot 数量——bridge 在线时运行中增删（写 config → `ccb reload` → 解析 plan，不重启项目、不干扰其他 slot），离线时写 desired 下次启动生效。

## 三、讨论与决策

经 1 轮 Codex 协商（job_941c3722dc10 / rep_152db330779d）+ 用户拍板：

- **栈式语义（方案 A，用户拍板）**：slot 编号永远连续，只从尾部增删；备选「任意删（编号空洞）」被放弃。
- **数量边界（用户拍板）**：min=1；不设业务硬上限，UI 提示资源开销，实现留防御性上限（数值留技术设计）。
- **缩容/扩回（用户拍板）**：不删磁盘文件 + 扩回强制全新会话；slot 编号复用不恢复旧上下文（化解 Codex 风险#1 状态串话）。
- **删除资格（设计默认，Codex 建议采纳）**：无 SlotBinding 或 idle 且 requirementId=null，且无 pending/submitted dispatch queue、无 active runtime job 三重空才可删。
- **架构方向（Codex 建议采纳）**：新建 ProjectSlotTopology 服务统一提供 slotIds(projectId)/agent-window 命名/core signature/删除资格；禁止各模块各自计算 N。slot-context-reset.service.ts 的 project_view 动态枚举是参照模式。
- **并发一致性（Codex 建议采纳）**：per-project config mutation lock，将 slotCount 变更、tips 重算、config 写入、reload/rollback 串行化；「失败仅回滚 config」被否决为不充分。

**Claude 对 Codex 协商的 4 锚点反思**：

- **我同意**：ProjectSlotTopology 统一入口、删除资格三重检查、config mutation lock、anchor-dispatch-worker isSlotId 漏改点、缩容丢 non-core 配置风险——全部进设计输入。
- **我不同意**：max 取「保守小值」——上限本质是单机资源问题，用户已拍板不设业务硬上限；需求层只绑定 min=1 + 防御性上限存在。
- **我的盲点**：派发 worker 的 isSlotId 路径未查到；preserve 逻辑读过代码未推演缩容场景；只从技术看状态串话，未上升到 lane identity 产品语义。
- **接下来**：2 项用户拍板 + 4 项设计默认已全部落定，进入技术设计。

## 四、范围与边界

**范围内**：
1. ProjectSlotTopology 统一拓扑服务（新建）。
2. managed config 参数化生成：windows/agents 段、core signature、drift 检测按 slotCount 动态化（managed-config.service.ts）。
3. 调度/派发动态化：slot-binding.service.ts SLOT_IDS、job-slot-router、slot.routes.ts 过滤、anchor-dispatch-worker isSlotId。
4. CcbdClientService 新增 reload 封装（协议/CLI 集成 + plan 解析 + 错误映射）；resize 流程：lock → 写 config → reload → 失败回滚。
5. Prisma project 表 slotCount 字段（默认 3）+ 迁移。
6. ProjectCcbdManager.ensureStarted / startup recovery / confirmRestore 全部消费 slotCount。
7. SlotsPage UI：动态渲染 + 增删入口 + 资源开销提示 + 失败原因展示。
8. lint_main_anchor_config.py 参数化；关联 spec 同步（参照 su-oriel e6d3663 文件面反向）。
9. 缩容时保留 retired slot 的 non-core agent 配置（model/startup_args）供扩回复用（Codex 风险#4 防护，机制留技术设计）。

**范围外**：
1. claude 首启 self-restart 丢 CLI 参数——Claude Code/CCB bridge 侧问题，单独给 codex-dual 报 issue（keeper recover 有自愈路径）。
2. main 组拓扑变更、per-slot 自定义 provider 组合、slot 模板。
3. 减到 0 slot（禁用业务执行）。

## 五、验收口径

1. 运行中 3→4：UI 操作后 slot-4 window/sidebar/双 agent 自动创建并可被派发需求，main 与 slot-1..3 全程无中断。
2. 运行中 4→3（尾部空闲）：slot-4 window 回收，磁盘文件保留；4→3（尾部 busy/有 queue/有 job）：操作被拒并展示原因。
3. 缩容后扩回：新 slot 为全新空白会话，不恢复旧对话；保留的 non-core 配置（如自定义 model）生效。
4. ccbd 离线时调整：写入 desired，下次启动按新 slotCount 生成拓扑。
5. 存量 3-slot 项目升级后启动：不误报 core drift。
6. resize 与 syncSlotTips/startup recovery 并发：config 不互相覆盖（mutation lock 生效）。
7. typecheck + 既有测试 + 新增测试绿。

## 六、风险与依赖

| 风险 | 应对 |
|---|---|
| 状态串话（编号复用恢复旧上下文） | 已由「扩回全新会话」拍板化解；实现需确保不触发 restore --continue |
| 配置竞态（resize vs tips sync vs recovery 并发写 config） | per-project config mutation lock 串行化 |
| 漏改派发路径（isSlotId/terminal guard/UI 类型） | 已全部列入范围内清单 |
| 缩容丢 non-core 配置 | 缩容时持久化保留（机制留技术设计） |
| bridge reload 行为依赖 | 依赖 CCB ≥ v7.1.0（当前 v7.3.2）；reload 输出格式变化需错误映射兜底 |

## Claude 解读

用户要求 oriel console 原生支持按项目动态调整业务 slot 数量（当前硬编码 3），核心诉求来自今日实测：手改 ccb.config 增 slot 会被 oriel managed config 回写抹除、ccbd 重启 reconcile 连根回收，而 CCB bridge v7.3.2 的 `ccb reload` 已支持动态 add_window/add_agent/remove idle（实测可用、fail-closed、不干扰运行中 slot），地基就绪、缺口全在 oriel 层。方案 A 栈式语义已拍板：slot 编号永远连续，只从尾部增删，删除要求尾部 slot 空闲。架构方向（Codex 协商采纳）：新建 ProjectSlotTopology 服务作为唯一拓扑入口（slotIds/agent 命名/core signature/删除资格），所有消费方（managed config 生成、slot-binding、job-slot-router、slot.routes、anchor-dispatch-worker isSlotId、SlotsPage）统一消费它，不允许各模块各自计算 N；config 写入需 per-project mutation lock 串行化（resize/tips 同步/恢复流程）。

## 歧义点

需求分析期识别 6 项歧义，全部已澄清，无遗留 TBD：
1. slot 数量边界 —— 用户拍板：min=1（减到 0 等于禁用业务执行，超范围）；不设硬上限，UI 调高时提示资源开销（每 slot = claude opus[1m] + codex 两个常驻进程），实现保留防御性上限（如 16，数值留技术设计）防误操作。
2. 删除后扩回语义 —— 用户拍板：缩容不删磁盘文件（.ccb/agents/slotN_*、session 文件保留，可恢复可审计），扩回时强制全新空白会话，不 --continue 旧对话；slot 编号不承载 lane 身份延续。
3. 「无绑定可删」精确定义 —— 设计默认：尾部 slot 仅在 SlotBinding 不存在或 idle 且 requirementId=null，且无 pending/submitted AnchorDispatchQueue、无 active runtime job 时可删；bound/busy/unhealthy/recovering/draining 均不可删。
4. ccbd 离线时调整 —— 设计默认：允许写 desired slotCount + config，下次 ensureStarted 生效；在线时才尝试 ccb reload。
5. reload 被拒（busy）UX —— 设计默认：直接失败并展示 bridge 拒绝原因，不自动排队等 idle，用户处理后重试。
6. 存量项目升级 —— 设计默认：迁移默认 slotCount=3，core signature 按项目 slotCount 渲染，存量 3-slot config 不误报 drift；用户真改 core 仍走现有 drift 确认。

## 保真差异

用户原话仅表达「想让 oriel 支持动态增删 slot、问是否可行和改动面」与「按方案 A 立项」；以下内容为 Claude 推导或后续补充拍板，非原话直接内容：(1) 方案 A 的具体定义（栈式：编号连续、尾部增删、busy 拒绝）是 Claude 提出的设计选项，用户在 A/B 对比中拍板选 A；(2) min=1、不设硬上限、不删文件+扩回全新会话，是需求分析期经 AskUserQuestion 补充拍板；(3) ProjectSlotTopology 统一服务、config mutation lock 等架构方向来自 Codex 协商（job_941c3722dc10），属实现策略推导，不是用户指定；(4) 改动面清单（managed config 参数化、reload 集成等）为 Claude 基于今日代码实证的推导。
