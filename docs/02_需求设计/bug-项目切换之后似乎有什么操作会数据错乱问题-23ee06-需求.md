---
id: cmq3m1i8r5ac97ea38323ee06
title: BUG：项目切换之后似乎有什么操作会数据错乱问题
doc_type: requirement
status: delivered
created: 2026-06-07T09:59:31.227Z
analysis_input_hash: 0fc60f622bb123be75e8c4e03ab3bd77f6f604351baae9df2d5fa5ecea908dea
analysis_applied_at: 2026-06-07T13:30:46.758Z
expression_spec: v1
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

我现在浏览器打开两个tab，然后一个tab在CCB项目，一个tab在realtime_translator项目，多项目操作，然后操作CCB的添加slot会报错 CCB bridge错误。如果操作realtime_translator的需求详情页的绑定slot1，似乎会触发消息到CCB的slot1里？（我不确定，你深度排查一下），然后还要深度排查一下其他类似的按钮、交互、操作的这类的问题是否有？
## 原话（verbatim）

我现在浏览器打开两个tab，然后一个tab在CCB项目，一个tab在realtime_translator项目，然后操作CCB的添加slot会报错 CCB bridge错误。如果操作realtime_translator的需求详情页的绑定slot1，似乎会触发消息到CCB的slot1里？（我不确定，你深度排查一下），然后还要深度排查一下其他类似的按钮、交互、操作的这类的问题是否有？

## 二、背景与目标

用户在同一 Console 实例下双 tab 并行操作两个项目（CCB + realtime_translator），出现两类现象：① CCB tab 添加 slot 报「CCB bridge 错误」（Bug C，待排查）；② RT 项目绑定 slot1 的 `/new` 消息进入 CCB 项目的 slot1（Bug B，已实测确证）。姊妹需求 e9f09f（绑定 slot 报 slot terminal unavailable = Bug A）与本需求为同根因簇，其分析已完成（status: planning）并实测确证 Bug B。

**目标**：确证/排除跨项目串扰并修复；按完整档系统性扫描全站隔离风险面；落地「多 tab 多项目并发」的架构级支持（URL 编码 projectId），恢复并保障多项目并发使用 Console 的隔离正确性。

## 三、讨论与决策

- `sc:analyze --focus requirement-clarity` 产出 5 项分级歧义（HIGH×2/MED×2/LOW×1），`sc:research`/`sc:business-panel` 以 Explore 代码深扫＋必问扫描替代（内部 bug，无外部领域与新增业务面）。
- Codex 协商轮 1（job_aa064a070a8b，consult）：Codex 质疑单层「前端隔离失效」framing，提出双层隔离问题，并定位 default resetter 根因候选；Claude 逐行核验 4 处 file:line 全部属实后采纳。
- Claude 反思（4 锚点）：**同意**双层 framing（server 归属校验可拦前端错配写操作，单层解释不了消息真实进入 CCB slot1）；**不同意**将前端 store 问题降级为纯错觉（仅依赖 projectId 的端点会被直接打错），且 JobSlotRouter 队列缺 projectId filter 应升为正式排查项；**盲点**：漏看 bind/release 的 onSlotBound 副作用链，教训是排查跨项目串扰应优先枚举「默认构造回落进程级上下文」的构造点；**下一步**：升级 2 个拍板项后进入技术设计（与 e9f09f 统一设计）。
- **联动修正（2026-06-07，e9f09f 分析落盘后）**：e9f09f 流程实测确证 Bug B（在 RT 绑 slot-1 清空 CCB slot1 双 agent 会话上下文；`input.projectId` 只回显不参与路由），并修正本需求早先对 e9f09f 现象的归因——「slot terminal unavailable」直接根因是独立的 Bug A（slot-terminal.service.ts:13 硬编码 `SESSION_PREFIX="ccb-su-ccb-"`），而非「RT pane 未被 /new 触达」。Bug A/B 修复实现归 e9f09f；本需求承接其显式移交项（anchor-terminal/native-terminal `ccb-su-ccb-task-` 硬编码清理、Bug C 排查、系统性审计）。
- **用户拍板（2026-06-07）**：① 范围档位 = **完整档**（用户判定问题严重，全站审计 + 多 tab e2e 全做）；② 「多 tab 多项目并发」= **必须支持**（URL 编码 projectId 架构改造纳入范围）。

## 四、功能 / 范围

**已拍板范围（完整档）**，与 e9f09f 统一技术设计协调分工：

1. **Bug C 排查**：「添加 slot 报 bridge 错误」复现与根因——覆盖 reload_rejected 与 reload_failed 两路径，记录精确报错，交付根因链+复现步骤。
2. **前端架构改造（多 tab 必须支持的直接推论）**：URL 编码 projectId（路由挂 `/projects/:projectId/` 前缀或等效方案）；URL 成为项目身份真相源；移除 `projects[0]` 静默 fallback；切项目导航语义与旧链接兼容策略在 technical_design 定稿。
3. **服务端防御纵深**：JobSlotRouter.tick 队列查询按 projectId 过滤（查询层而非事后 continue）；EventJournal 支持 projectId 过滤（schema 评估后定迁移方案）；「默认构造回落进程级上下文」构造点枚举与类型层面禁用（如 projectRoot 必填化）。
4. **e9f09f 移交项**：anchor-terminal/tmux.service.ts:8、native-terminal.service.ts:12 的 `ccb-su-ccb-task-` 硬编码清理（与 Bug A 同方向：以 ccbd project_view 为 session 名真相源）。
5. **全站审计**：selectedProjectId 入口审计（含文档/任务/需求 CRUD）+ 仅依赖 projectId 端点审计，交付扫描矩阵（入口 × projectId 来源 × 隔离结论）。
6. **多 tab 多项目 e2e**：双 tab 双项目并发操作互不串扰的端到端验证（测试设施选型在 technical_design 评估，引入新依赖属必问项）。

**不在本需求修**：Bug A（SESSION_PREFIX 硬编码）与 Bug B（default resetter）的修复实现——归 e9f09f（option 1），本需求负责验收其跨项目串扰侧的回归证据。

## 六、边界 / 不做项

- Bug A/B 修复实现归 e9f09f，本需求不重复修（统一设计防两边抢修或漏接）。
- 不改 ccbd（codex-dual runtime）侧命名规则与协议——以其为真相源做适配。
- 不触碰 `docs/99_归档/`；EventJournal/queue 若需 schema 级迁移，先在技术设计中升级用户再动。
- 数据层错乱（DB 写串项目）目前无证据：不预设修复；若审计中发现，另行升级为新需求。
- e9f09f 的交付验收不并入本需求（统一设计、分开验收）。

## 七、开放问题 / 假设

**已拍板（2026-06-07）**：范围 = 完整档；多 tab 多项目并发 = 必须支持。

**移交 technical_design 的取舍（届时按必问升级）**：① URL 改造的旧链接兼容策略；② e2e 测试设施选型（引入 Playwright 等新依赖属必问）；③ EventJournal projectId 过滤的 schema 迁移方向；④ 架构改造与防御纵深是否拆分交付批次。

**工作假设**（排查中验证）：requirement/task id 全局唯一；Console server 运行于 CCB 根；realtime_translator 的 ccb runtime 正常（用户截图佐证，e9f09f 已采信）。

## 八、拆分预览

预期拆分方向（task_breakdown 节点定稿）：① Bug C 复现与根因排查；② 前端 URL/projectId 架构改造（路由+store+导航+兼容）；③ 服务端防御纵深（队列过滤+EventJournal 过滤+构造点禁用）；④ anchor-terminal 硬编码清理；⑤ 全站审计矩阵；⑥ 多 tab 多项目 e2e；⑦ 与 e9f09f 共享的统一技术设计文档（两份互相引用，各锚定自己的 requirement）。

## 十二、交互 / 流程

串扰链路（Bug B，已实测确证，修复归 e9f09f）：
```
RT tab 绑定 slot1
 → POST /api/projects/{RT}/requirements/{id}/bind-slot（归属校验通过，DB 绑定落 RT ✅）
 → onSlotBound 回调（slot-binding.service.ts:554-563，两条消费路径）
 → createDefaultSlotContextResetter() → new CcbdClientService()（无 projectRoot，模块级单例）
 → resolveCcbProjectRoot() = Console server 进程的 CCB 根
 → projectView() 返回 CCB 项目窗口表 → 按窗口名匹配 slot-1
 → /new 被 send-keys 进 CCB 项目 slot1_claude/slot1_codex panes ✗（清空其会话上下文）
（e9f09f 的 slot terminal unavailable 为独立 Bug A：SESSION_PREFIX 硬编码 → 非 SU-CCB 项目终端 resolver 必然 404）
```

## 十三、风险

- URL/projectId 架构改造影响全站导航、深链与书签，回归面大——需在技术设计中定分批打法（先 server 防御纵深后 URL 改造）与回滚策略。
- EventJournal/queue 若无 projectId 字段，过滤能力需小迁移或兼容策略（技术设计中评估并升级用户）。
- Bug B 修复（e9f09f 侧）后 `/new` 将真正打到目标项目 panes——跨需求回归需确认目标项目 agent 对 `/new` 的处理符合预期。
- 多 tab 多项目 e2e 可能引入新测试依赖（必问项）；若用户否决引入，需降级为集成测试+手工验证清单并明示覆盖缺口。
- 多项目并发为新近启用场景，可能存在本次未观察到的同类串扰点；以扫描矩阵覆盖而非逐例修补。

## Claude 解读

这是一个「多项目并发使用 Console 时项目上下文隔离失效」的 bug 排查+修复型需求，经 Codex 协商修正为**双层隔离问题** framing，并经姊妹需求 e9f09f 的联动分析实测确证关键链路（2026-06-07）。

**第一层（前端上下文层）**：路由 URL 不含 projectId（App.tsx:714-792，如 `/requirements/:requirementId`），项目身份完全依赖单 tab 内存 Zustand store（project-store.ts:61，无 persist）；`resolveSelectedProjectId` 失效时静默 fallback `projects[0]`（project-store.ts:44-49）；切项目时 `handleSelectProject` 不处理 requirement 详情页路由，可形成「URL 是 A 项目的需求、store 是 B 项目」组合。对带归属校验的写操作该层只产生错觉与报错；但对仅依赖 projectId 的端点（resize/slots 投影/ccbd status）错配会直接生效。**用户已拍板（2026-06-07）「多 tab 多项目并发为必须支持的使用方式」，该层修复从可选 guard 升级为 URL 编码 projectId 的架构级改造，纳入本需求范围**。

**第二层（server 运行时路由层，已实测确证 = Bug B）**：`SlotContextResetService` 模块级单例默认构造 `new CcbdClientService()`（slot-context-reset.service.ts:49、:141-142），不传 projectRoot 回落 `resolveCcbProjectRoot()` 即 Console server 自己的 CCB 根（ccbd-client.service.ts:122）；bind/release 后的回调经该 default resetter 发送 `/new`（slot-binding.service.ts:554-563 两条消费路径），`projectView()` 返回 CCB 项目窗口表，按窗口名 slot-1 匹配 → `/new` 被 send-keys 进 **CCB 项目 slot1_claude/slot1_codex panes，清空其会话上下文**；`input.projectId` 只回显进结果对象，不参与路由（e9f09f 流程实测确证，本需求现象②属实）。对照组：`SlotResizeService` 显式传 projectRoot（slot-resize.service.ts:120-122）是正确模式，全仓生产代码无参 `CcbdClientService()` 唯一命中即 slot-context-reset。

**归因修正（联动 e9f09f）**：e9f09f 的「slot terminal unavailable」直接根因不是早先推测的「RT 自身 pane 未被 /new 触达」，而是独立的 **Bug A**：slot-terminal.service.ts:13 硬编码 `SESSION_PREFIX = "ccb-su-ccb-"`，任何目录名 ≠ SU-CCB 的项目终端 resolver 必然 404（实测 RT session 为 `ccb-realtime_translator-a8ae9ed1`）。**Bug A/B 的修复实现归 e9f09f（option 1 最小修，统一技术设计协调）**；本需求承接 e9f09f 显式移交项：anchor-terminal/tmux.service.ts:8 与 native-terminal.service.ts:12 的 `ccb-su-ccb-task-` 硬编码清理、「CCB bridge 错误」排查、多项目系统性审计。

**三个子诉求（范围已拍板：完整档，2026-06-07）**：① 诊断 CCB tab 添加 slot 报「CCB bridge 错误」（= Bug C，resize 链路显式传 projectRoot 属正确模式，证据未闭环，独立排查 reload_rejected/reload_failed 两路径）；② 「RT 绑定 slot1 → CCB slot1 收到消息」已确证为 Bug B（tmux 输入流 `/new`）；③ 系统性扫描：全站 selectedProjectId 入口审计（含文档/任务/需求 CRUD）+ 仅依赖 projectId 端点审计 + 「默认构造回落进程级上下文」构造点枚举 + JobSlotRouter.tick 队列过滤（job-slot-router.ts:174-198）+ EventJournal projectId 过滤 + 多 tab 多项目 e2e。

**验收口径（默认，review 可调整）**：每个怀疑点交付「确证/排除 + 根因链 + 复现步骤」三件套；扫描面交付风险清单矩阵（入口 × projectId 来源 × 隔离结论）；修复项附回归验证证据；多 tab 双项目并发操作互不串扰的 e2e 证据。

**与 e9f09f 的关系**：同根因簇（Bug B 共享），统一技术设计同轮定稿、互相引用，两个 requirement 实体分开交付验收；Bug A/B 修复落 e9f09f，本需求落架构改造+排查+审计+移交项。
## 歧义点

1.【已确证-Bug B】「触发消息到CCB的slot1」三义性（tmux 输入流 / 错误绑定 / dispatch job）：经 e9f09f 流程实测确证为 (a) tmux 输入流——bind 回调的 `/new` 被 send-keys 进 CCB slot1 双 agent panes 并清空其会话上下文；DB 绑定本身正确落在 RT 项目，无错误绑定，无跨项目 dispatch。

2.【已消解-双路径排查】「CCB bridge错误」精确文案未知（= Bug C）：代码候选 reload_rejected（「ccb bridge 拒绝了拓扑变更」）vs reload_failed（「ccb reload 执行失败」），两者根因路径不同；resize 链路显式传 projectRoot 属正确模式，故 Bug C 独立于 Bug B，排查须同时覆盖两路径并在复现时记录精确报错。

3.【已拍板 2026-06-07·完整档】「其他类似的按钮、交互、操作」扫描面：用户拍板**完整档**（理由：问题严重）——含 Bug C 排查、前端 URL/projectId 架构改造、JobSlotRouter/EventJournal project 范围过滤、slot 交互入口审计、全站 selectedProjectId 入口审计（含文档/任务/需求 CRUD）、多 tab 多项目 e2e、e9f09f 移交的 anchor-terminal 硬编码清理。

4.【已拍板 2026-06-07·必须支持】「多 tab 多项目并发使用」为必须支持的使用方式：URL 编码 projectId 的架构级改造纳入本需求设计范围；是否拆分为独立交付批次（先 server 防御纵深、后 URL 改造）在 technical_design 节点定稿。

5.【已消解-以正文为准】标题「数据错乱」范围宽于正文：分析以正文+扫描面为准；若排查中发现真实数据层错乱（DB 写串项目），属新发现另行升级。

当前无待用户拍板项；技术实现取舍（URL 兼容策略、e2e 依赖引入、EventJournal schema 迁移方向）属 technical_design 节点必问项，届时按命中升级。
## 保真差异

1. 「需求描述」较「原话（verbatim）」多出「多项目操作，」四字：属语义强调，无实质漂移。
2. 标题「项目切换之后似乎有什么操作会数据错乱问题」中「项目切换」「数据错乱」均宽于原话实际描述（原话是双 tab 并行操作而非切换动作；描述的是 slot 操作串扰而非数据错乱实例）：分析按原话事实框定，标题视为用户的直觉概括。
3. 原话中「（我不确定，你深度排查一下）」的不确定性标注处理结果：「RT 绑定 slot1 影响 CCB slot1」已由排查**确证为真**（Bug B，e9f09f 流程实测：`/new` 被 send-keys 进 CCB slot1 双 agent panes），且比用户感知更具体——属破坏性跨项目副作用（清空会话上下文），不只是「出现消息」。
4. 原话只描述现象与排查诉求，未要求架构改造：「URL 编码 projectId」的范围扩展源于用户后续拍板（2026-06-07：完整档 + 多 tab 必须支持），非分析者自行加戏。
