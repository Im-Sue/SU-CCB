---
id: cmq3m1i8r5ac97ea38323ee06
title: BUG：项目切换之后似乎有什么操作会数据错乱问题
doc_type: requirement
status: planning
created: 2026-06-07T09:59:31.227Z
analysis_input_hash: 0fc60f622bb123be75e8c4e03ab3bd77f6f604351baae9df2d5fa5ecea908dea
analysis_applied_at: 2026-06-07T10:18:54.210Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

我现在浏览器打开两个tab，然后一个tab在CCB项目，一个tab在realtime_translator项目，多项目操作，然后操作CCB的添加slot会报错 CCB bridge错误。如果操作realtime_translator的需求详情页的绑定slot1，似乎会触发消息到CCB的slot1里？（我不确定，你深度排查一下），然后还要深度排查一下其他类似的按钮、交互、操作的这类的问题是否有？
## 原话（verbatim）

我现在浏览器打开两个tab，然后一个tab在CCB项目，一个tab在realtime_translator项目，然后操作CCB的添加slot会报错 CCB bridge错误。如果操作realtime_translator的需求详情页的绑定slot1，似乎会触发消息到CCB的slot1里？（我不确定，你深度排查一下），然后还要深度排查一下其他类似的按钮、交互、操作的这类的问题是否有？

## 二、背景与目标

用户在同一 Console 实例下双 tab 并行操作两个项目（CCB + realtime_translator），出现两类现象：① CCB tab 添加 slot 报「CCB bridge 错误」；② 疑似 RT 项目绑定 slot1 的消息进入 CCB 项目的 slot1。姊妹需求 e9f09f（绑定 slot 报 slot terminal unavailable）原文明确引用本需求要求联动思考，二者经协商确认为同根因簇。

**目标**：确证/排除跨项目串扰并给出根因链与修复；系统性扫描同类风险面，恢复多项目并发使用 Console 的隔离正确性。

## 三、讨论与决策

- `sc:analyze --focus requirement-clarity` 产出 5 项分级歧义（HIGH×2/MED×2/LOW×1），`sc:research`/`sc:business-panel` 以 Explore 代码深扫＋必问扫描替代（内部 bug，无外部领域与新增业务面）。
- Codex 协商轮 1（job_aa064a070a8b，consult）：Codex 质疑单层「前端隔离失效」framing，提出双层隔离问题，并定位 default resetter 根因候选；Claude 逐行核验 4 处 file:line 全部属实后采纳。
- Claude 反思（4 锚点）：**同意**双层 framing（server 归属校验可拦前端错配写操作，单层解释不了消息真实进入 CCB slot1）；**不同意**将前端 store 问题降级为纯错觉（仅依赖 projectId 的端点会被直接打错），且 JobSlotRouter 队列缺 projectId filter 应升为正式排查项；**盲点**：漏看 bind/release 的 onSlotBound 副作用链，教训是排查跨项目串扰应优先枚举「默认构造回落进程级上下文」的构造点；**下一步**：升级 2 个拍板项后进入技术设计（与 e9f09f 统一设计）。

## 四、功能 / 范围

三个子诉求：
1. 诊断「添加 slot 报 bridge 错误」：覆盖 reload_rejected 与 reload_failed 两路径，复现并记录精确报错。
2. 确证/排除「RT 绑定 slot1 → CCB slot1 收到消息」：覆盖 tmux 输入流 / 错误绑定 / dispatch job 三条链路；最高优先验证 default resetter 假设。
3. 风险面扫描：默认构造回落点、仅依赖 projectId 的端点、JobSlotRouter 队列过滤、EventJournal project 过滤、9+ 个 slot 交互入口。

范围档位（待拍板，推荐**推荐档**）：
- 最小：修 default resetter + 确证两个已报现象根因。
- 推荐：最小 + 前端 project guard 或 projectId 显式化 + 队列/EventJournal project 范围过滤 + slot 交互入口审计。
- 完整：推荐 + 全站 selectedProjectId 入口审计 + 多 tab 多项目 e2e。

## 六、边界 / 不做项

- 不在本需求内做 URL 全站编码 projectId 的架构改造，除非用户拍板「多 tab 多项目为必须支持场景」（届时也应评估是否独立成需求）。
- 不触碰 `docs/99_归档/`；不引入新依赖；EventJournal/queue 若需 schema 级迁移，先在技术设计中升级再动。
- e9f09f 的交付验收不并入本需求（统一设计、分开验收）。

## 七、开放问题 / 假设

**待用户拍板**：
1. 排查修复档位：最小 / 推荐 / 完整（Claude 推荐：推荐档）。
2. 「多 tab 多项目并发」是否为必须支持的使用方式（决定修复方向上限）。

**工作假设**（排查中验证）：requirement/task id 全局唯一；Console server 运行于 CCB 根（resolveCcbProjectRoot 指向 CCB）；用户所见「CCB slot1 的消息」最可能是 bind 后的 `/new`；realtime_translator 项目的 ccb runtime 当时已在 WSL 终端启动（用户提供截图佐证）。

## 八、拆分预览

预期拆分方向（task_breakdown 节点定稿）：① 复现与根因确证（含三链路排查报告）；② default resetter 修复 + 回归；③ 风险面扫描矩阵 + 按档位修复；④ 与 e9f09f 共享的统一技术设计文档。

## 十二、交互 / 流程

串扰链路（静态核验，待动态复现确证）：
```
RT tab 绑定 slot1
 → POST /api/projects/{RT}/requirements/{id}/bind-slot（归属校验通过，DB 绑定落 RT）
 → onSlotBound 回调（slot-binding.service.ts:558）
 → createDefaultSlotContextResetter() → new CcbdClientService()（无 projectRoot）
 → resolveCcbProjectRoot() = Console server 进程的 CCB 根
 → projectView() 返回 CCB 项目窗口表 → 按名匹配 slot1
 → /new 发送至 CCB 项目 slot1 的 agents ✗（应发 RT）
同时 RT 自身 pane 未被触达 → 详情页 slot terminal unavailable（e9f09f 现象）
```

## 十三、风险

- 若用户所见「消息」实为 dispatch job 而非 `/new`，需扩查 anchor worker 运行日志（已纳入三链路排查）。
- URL/projectId 显式化改造影响全站导航与深链，不可点修随手做（已设为拍板项约束）。
- EventJournal/queue 若无 projectId 字段，过滤能力需小迁移或兼容策略（技术设计中评估）。
- 多项目并发为新近启用场景，可能存在本次未观察到的同类串扰点；以扫描矩阵覆盖而非逐例修补。

## Claude 解读

这是一个「多项目并发使用 Console 时项目上下文隔离失效」的 bug 排查+修复型需求，经 Codex 协商修正为**双层隔离问题** framing：

**第一层（前端上下文层）**：路由 URL 不含 projectId（App.tsx:714-792，如 `/requirements/:requirementId`），项目身份完全依赖单 tab 内存 Zustand store（project-store.ts:61，无 persist）；`resolveSelectedProjectId` 失效时静默 fallback `projects[0]`（project-store.ts:44-49）；切项目时 `handleSelectProject` 不处理 requirement 详情页路由，可形成「URL 是 A 项目的需求、store 是 B 项目」组合。对带归属校验的写操作（如 bind-slot 校验 requirement∈projectId，slot.routes.ts:178-186）该层只产生错觉与报错；但对仅依赖 projectId 的端点（resize/slots 投影/ccbd status）错配会直接生效。

**第二层（server 运行时路由层，高概率根因候选，代码链路已静态核验）**：`SlotContextResetService` 默认构造 `new CcbdClientService()`（slot-context-reset.service.ts:49），后者不传 projectRoot 时回落 `resolveCcbProjectRoot()` 即 Console server 进程自己的 CCB 根（ccbd-client.service.ts:122）；bind/release 成功后的 `onSlotBound`/`onSlotReleased` 回调经该 default resetter 发送 `/new`（slot-binding.service.ts:558），`projectView()` 返回的是 CCB 项目的窗口表，按 slot 同名（slot1）匹配 → `/new` 打进 **CCB 项目的 slot1**。该链路同时解释：本需求「realtime_translator 绑定 slot1 → CCB slot1 出现消息」与姊妹需求 e9f09f「slot terminal unavailable」（RT 自己的 pane 未被触达）。对照组：`SlotResizeService` 显式 `new SlotContextResetService(new CcbdClientService({ projectRoot }))`（slot-resize.service.ts:120-122）是正确模式，证明这是实现不一致。

**三个子诉求**：① 诊断 CCB tab 添加 slot 报错（前端文案候选 reload_rejected=「ccb bridge 拒绝了拓扑变更」/ reload_failed，SlotsPage.tsx:51-52，根因尚未定位，保留为排查项）；② 确证或排除「RT 绑定 slot1 → CCB slot1 收到消息」并给出根因链（default resetter 为最高优先验证假设）；③ 系统性扫描同类跨项目串扰风险面（重点：所有「默认构造回落到进程级上下文」的构造点、仅依赖 projectId 的端点、`JobSlotRouter.tick` 队列查询缺 projectId filter（job-slot-router.ts:174-198）、EventJournal 不支持 projectId 过滤）。

**验收口径（默认，用户可调整）**：每个怀疑点交付「确证/排除 + 根因链 + 复现步骤」三件套；扫描面交付风险清单矩阵（入口 × projectId 来源 × 隔离结论）；修复项附回归验证证据。

**与 e9f09f 的关系**：同根因簇，统一技术设计做根因分析，两个 requirement 实体分开交付验收。
## 歧义点

1.【已消解-排查覆盖】「触发消息到CCB的slot1」三义性：(a) CCB slot1 的 tmux 终端出现输入流（如 `/new`）(b) CCB slot1 被错误绑定 (c) CCB slot1 收到 dispatch job。用户原话已明示「我不确定，你深度排查一下」，不再踢回用户；排查任务须覆盖全部三条链路并确证实际发生的是哪种。当前证据最支持 (a)（default resetter 发 `/new`）。

2.【已消解-双路径排查】「CCB bridge错误」精确文案未知：代码候选 reload_rejected（「ccb bridge 拒绝了拓扑变更」）vs reload_failed（「ccb reload 执行失败」），两者根因路径不同；排查须同时覆盖，并在复现时记录精确报错。

3.【待用户拍板-范围档位】「其他类似的按钮、交互、操作」扫描面未定义，三档：**最小**=修 default resetter（bind/release/planning-bind 按 projectId→project.localPath 构造 CcbdClientService）+ 确证两个已报现象根因；**推荐**=最小 + 前端 projectId 显式化或详情页 project guard + JobSlotRouter/EventJournal 增加 project 范围过滤 + 9+ 个 slot 交互入口审计；**完整**=推荐 + 全站 selectedProjectId 入口审计（含文档/任务/需求 CRUD）+ 多 tab 多项目 e2e。Claude 推荐**推荐档**。

4.【待用户拍板-产品方向】「多 tab 多项目并发使用」是否为必须支持的使用方式？现架构 URL 不含 projectId，该场景从未被显式设计支持。若必须支持 → URL 编码 projectId 属架构级改造（影响全站导航与深链，不可作为点修随手做）；若仅尽力支持 → 推荐档的 project guard + server 端修复已足够。该决策影响技术设计方向上限。

5.【已消解-以正文为准】标题「数据错乱」范围宽于正文（正文仅描述 slot 操作串扰，未给出数据层错乱实例）：分析以正文+扫描面为准；若排查中发现真实数据层错乱（DB 写串项目），属新发现，另行升级。

少于 3 项待拍板说明：歧义 1/2/5 属技术排查可自行消解项（用户已授权深度排查），仅 3/4 触及用户权利（成本与产品方向），故升级拍板项为 2 个。
## 保真差异

1. 「需求描述」较「原话（verbatim）」多出「多项目操作，」四字（在「...realtime_translator项目，」之后）：属语义强调，无实质漂移。
2. 标题「项目切换之后似乎有什么操作会数据错乱问题」中「项目切换」「数据错乱」均宽于原话实际描述（原话是双 tab 并行操作而非切换动作；描述的是 slot 操作串扰而非数据错乱实例）：分析按原话事实框定，标题视为用户的直觉概括。
3. 原话中「（我不确定，你深度排查一下）」的不确定性标注在分析中完整保留：「RT 绑定 slot1 影响 CCB slot1」作为待确证假设处理，未当作已确认事实；当前 default-resetter 根因链为静态代码核验结论，动态复现确证留给后续节点。
