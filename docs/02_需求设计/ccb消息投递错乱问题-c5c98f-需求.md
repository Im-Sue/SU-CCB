---
id: cmpmlnqxd02346a524ec5c98f
title: ccb消息投递错乱问题
doc_type: requirement
status: delivered
created: 2026-05-26T12:16:44.305Z
analysis_input_hash: 42d2461b8600f518b22a2582aa27b5f6fcffee8b52e802bb370684a1ccbd10a2
analysis_applied_at: 2026-05-31T12:09:35.408Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

“为什么会出现这种错误的投递，是我们的机制问题还是你什么问题？

● 两者都有,但主因在我,机制只是没拦住、也没把规则写明,放大了我的错误。拆开说:

  我的问题(主因)
  关键不在于"我不知道该发给谁",而是我手上已经有足够信息却没用:
  - 我清楚自己是 slot3_claude(CLAUDE.md/memory 路径就在 .ccb/agents/slot3_claude/)。
  - 我还亲手读过 ccb.config,看到 slot-3 = slot3_claude + slot3_codex。
  - 但路由协商对象时,我没有从"我是谁、在哪个槽"推到"我的同槽搭档是 slot3_codex",而是临时编了一条"项目级 → main_codex"的启发式。

  也就是说,这是一次有据不用、用臆造规则替代上下文推理的失误,不是能力缺口。正确做法应该是:任何派工/协商前先锚定"我的身份和所属 slot",再就近选同槽对端。

  机制的问题(次因,让错误得以发生且没被发现)
  - CCB 规则里(全局 CLAUDE.md、项目 CLAUDE.md、su-flow SKILL)只说"用 ccb ask 找其他可见 agent 协商",没有明确默认路由约定(比如"consult 默认走同槽
  codex")。规则留白,我就容易自由发挥。
  - ccb ask 的 sender 是自动从当前 workspace agent 推断的,但没有把"你的同槽对端是谁"主动暴露给我,也没有对跨槽投递做任何提示/拦截。所以投错了也没有任何信号,直到你发现。

  怎么让它不再犯(机制层面可固化,任选)
  1. 在项目 CLAUDE.md 的协商约定里加一条:consult/派工默认目标 = 当前 agent 同槽对端(如 slot3_claude → slot3_codex),跨槽需显式理由。
  2. (可选)给 ccb ask 在 slot agent 跨槽投递时加一条 warning,让这类错投当场可见。”  

我觉得不应该固化到cluade.md或者ccb ask应该固化到我们的plugin里？如何制定自动寻找同一个agent组下的对应agent(可能未来不叫slotX 或者slot-X，所谓的slot-X就是个agent组的概念)?

## 原话（verbatim）

“为什么会出现这种错误的投递，是我们的机制问题还是你什么问题？

● 两者都有,但主因在我,机制只是没拦住、也没把规则写明,放大了我的错误。拆开说:

  我的问题(主因)
  关键不在于"我不知道该发给谁",而是我手上已经有足够信息却没用:
  - 我清楚自己是 slot3_claude(CLAUDE.md/memory 路径就在 .ccb/agents/slot3_claude/)。
  - 我还亲手读过 ccb.config,看到 slot-3 = slot3_claude + slot3_codex。
  - 但路由协商对象时,我没有从"我是谁、在哪个槽"推到"我的同槽搭档是 slot3_codex",而是临时编了一条"项目级 → main_codex"的启发式。

  也就是说,这是一次有据不用、用臆造规则替代上下文推理的失误,不是能力缺口。正确做法应该是:任何派工/协商前先锚定"我的身份和所属 slot",再就近选同槽对端。

  机制的问题(次因,让错误得以发生且没被发现)
  - CCB 规则里(全局 CLAUDE.md、项目 CLAUDE.md、su-flow SKILL)只说"用 ccb ask 找其他可见 agent 协商",没有明确默认路由约定(比如"consult 默认走同槽
  codex")。规则留白,我就容易自由发挥。
  - ccb ask 的 sender 是自动从当前 workspace agent 推断的,但没有把"你的同槽对端是谁"主动暴露给我,也没有对跨槽投递做任何提示/拦截。所以投错了也没有任何信号,直到你发现。

  怎么让它不再犯(机制层面可固化,任选)
  1. 在项目 CLAUDE.md 的协商约定里加一条:consult/派工默认目标 = 当前 agent 同槽对端(如 slot3_claude → slot3_codex),跨槽需显式理由。
  2. (可选)给 ccb ask 在 slot agent 跨槽投递时加一条 warning,让这类错投当场可见。”  

我觉得不应该固化到cluade.md或者ccb ask应该固化到我们的plugin里？如何制定自动寻找同一个agent组下的对应agent(可能未来不叫slotX 或者slot-X，所谓的slot-X就是个agent组的概念)?

## 二、背景与目标

> 把原话复盘从业务角度收敛成「要解决什么、做成什么样」。

- **背景**:CCB 多 agent 协作里,agent 在 consult / dispatch 路由时缺乏「同组对端」的确定性机制。曾发生某 agent 有据不用——明明可从「我是谁、在哪个 window」推出同组对端,却临时编造「项目级 → main_codex」启发式,投错且全程无信号。根因有二:① agent 上下文推理缺位(主因);② 机制留白——`ccb ask` 只推断 sender,不暴露同组对端、也不对跨组投递做任何提示/拦截(次因,放大并隐藏了错误)。
- **目标**:
  1. 把「识别并就近选择同组对端」从「靠 agent 自觉」升级为「仓内可确定性解析 + 错投可见」。
  2. 定义一个对命名鲁棒的「agent 组」抽象,以 `ccb.config [windows]` 成员共属关系为真相源,不绑定 "slot" 字符串。
  3. 给跨组投递可见信号(reason / warning),让错投当场暴露。
  4. 明确交付边界:仓内(plugin / Console)优先直接交付,仓外 runtime 能力以 contract 诉求形式上游推进。

---

## 三、讨论与决策

### 讨论:路由知识固化在哪一层

- **各方观点**:用户倾向「别固化进 CLAUDE.md,机制宜进我们的 plugin」;同组对端 slot1_codex 协商建议「主放 O2 + O1 兜底,O3 判 direct-change out-of-scope 但保留为上游 contract」。
- **最终倾向(待用户确认)**:
  - **O2 仓内 resolver** 为主交付:确定性解析同组对端 + 收窄默认路由 + 跨组软提示。
  - **O1 文档** 兜底:补「先锚定身份 → 同组对端」协商约定,但不单独依赖。
  - **O3 改仓外 `ccb ask` 不在本需求直接交付**:改为向 codex-dual runtime 提 contract(暴露 actor / window / peers + 跨组 warning)。
- **理由**:O2 仓内可控、立刻消除错投主路径;O1 单独无法防自由发挥(正是本次失败模式);O3 在仓外、影响所有项目、所有权不在本仓,不宜作为本需求直接交付项。

---

## 四、功能 / 范围

### 4.1 agent 组抽象

| 项 | 说明 |
|----|------|
| 做什么 | 以 `ccb.config [windows]` 同一 window 的成员集合定义「agent 组」;"slot-X" 仅为当前命名,不作为判定依据 |
| 谁用 | 所有发起 consult / dispatch 的 agent 与编排流程 |
| 预期结果 | 给定任一 agent 名,可确定其所属组及组内成员,命名变更不影响判定 |

### 4.2 同组对端 resolver

| 项 | 说明 |
|----|------|
| 做什么 | 输入当前 agent,输出同组对端,或 `ambiguous` / `no_peer` |
| 怎么触发 | 路由前(workflow consult / dispatch 未显式指定 target 时) |
| 前置条件 | 能从 workspace 推断自身 agent 名与所属 window |
| 预期结果 | 唯一互补成员→返回对端;0 个或多个候选→返回 ambiguous/no_peer 并要求显式 target |

### 4.3 默认路由收窄

| 项 | 说明 |
|----|------|
| 做什么 | 仅当「未显式指定 target」且「解析出唯一同组对端」时,默认投同组对端 |
| 边界 | Claude→Claude 跨组 review / cross-check 等合法场景保留显式 target,不被默认收窄误伤 |

### 4.4 跨组软提示

| 项 | 说明 |
|----|------|
| 做什么 | 跨组投递要求带 reason,或触发 warning,不静默通过 |
| 预期结果 | 错投在当场可见;合法跨组协作仍可进行(带理由) |

---

## 五、业务规则

| 编号 | 规则 | 说明 |
|------|------|------|
| R1 | 组定义 | agent 组 = `ccb.config` 同一 window 的成员集合;"slot-X" 仅为当前命名,规则不得 hardcode 该前缀 |
| R2 | 自身锚定 | 路由前先从 workspace 推断自身 agent 名与所属 window,再选对端;禁止臆造路由规则 |
| R3 | 对端解析 | 同 window 排除自己 → 优先显式 pairing/role → 无显式配置时仅当存在「唯一互补 provider 成员」才自动选定 → 否则 ambiguous/no_peer 并要求显式 target |
| R4 | 默认值范围 | 默认同组对端仅适用于「未显式指定 target 且解析出唯一对端」的 workflow consult/dispatch |
| R5 | 跨组可见性 | 跨组投递必须带 reason 或触发 warning,不得静默 |
| R6 | 边界守恒 | 本需求不直接修改仓外 ccb runtime;runtime 能力以 contract 诉求形式记录并上游推进 |

---

## 六、边界 / 不做项

- 不直接改 `/home/sue/.local/share/codex-dual` 的 `ccb ask`(仓外、所有权不在本仓)——仅产出 contract 诉求。
- 不在本需求内强制硬拦截跨组(默认软提示;是否硬拦截属开放问题)。
- Console `SLOT_IDS` / managed topology 的全面去硬编码泛化:倾向拆为后续独立任务,避免范围膨胀(待用户定)。
- 不在需求文档写实现细节 / 文件清单(留给《技术设计》)。

---

## 七、开放问题 / 假设

| 问题 / 假设 | 当前倾向 | 待谁定 |
|------|----------|--------|
| 现在就给 `ccb.config` 显式 pairing/role,还是先用「唯一互补 provider」v1 fallback | v1 fallback 先行 | 用户 |
| 跨组投递软提示(reason/warning)还是特定流程硬拦截 | 软提示起步 | 用户 |
| Console SLOT_IDS/managed topology 泛化纳入本需求还是拆独立 | 拆独立 | 用户 |
| 假设:本需求交付边界限定仓内 plugin/Console,runtime 改动仅作上游 contract | —— | 用户确认 |

---

## 八、拆分预览

- 块A:agent 组抽象 + 同组对端 resolver(仓内,以 `[windows]` 为真相源)
- 块B:workflow consult/dispatch 默认路由收窄 + 跨组软提示接线
- 块C:文档兜底(CLAUDE.md / 协商约定补「先锚定身份→同组对端」)
- 块D:向 codex-dual runtime 提 contract 诉求(暴露 actor/window/peers + 跨组 warning)
- 块E(候选,可拆后续):Console SLOT_IDS / managed topology 去硬编码泛化

---

## 十二、交互 / 流程

> 路由前的对端解析决策流(草案):

```
路由前:
  推断自身 agent 名 + 所属 window(组)
        │
        ▼
  目标已显式指定? ──是──> 跨组? ──是──> 要 reason / warning ──> 投递
        │                   └─否──> 直接投递
        否
        ▼
  解析同组对端(同 window 排除自己)
        │
  唯一互补成员? ──否(0 个 / 多个)──> ambiguous / no_peer ──> 要求显式 target
        │ 是
        ▼
  默认投同组对端
```

---

## 十三、风险

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 只做 O2,手工 `ask` 跨组仍不被 runtime 拦住 | 中 | 错投仍可能发生 | O1 文档约定 + 上游 contract 诉求 |
| provider 互补启发式在未来多成员组误选 | 中 | 选错对端 | 唯一性校验 + ambiguous 回退 + 显式 pairing/role |
| 现在就泛化所有 SLOT_IDS 致范围膨胀 | 中 | 交付延期 | 拆为后续独立任务 |
| 默认路由过度收窄正常跨组协作 | 低 | 协作体验下降 | 默认仅覆盖「无显式 target」场景,显式 target 不受限 |

## Claude 解读

这条需求表面像「复盘一次投错」,真实诉求是:把「识别并就近选择同组对端」从「靠 agent 自觉」升级为「机制可确定性解析 + 错投可见」,并给出一个对命名鲁棒的「agent 组」抽象(不绑定 "slot" 字符串)。

经与同组对端 slot1_codex 协商(本次 consult 即按「先锚定身份 slot1_claude → 就近选同 window 对端 slot1_codex」正确路由,是对目标行为的现场示范),落点建议:

- **主交付 O2(仓内)**:以 `ccb.config [windows]` 的成员共属关系为「组」真相源,提供确定性的「同组对端 resolver」+ 收窄后的默认路由 + 跨组软提示。仓内可控、能立刻消除错投主路径。
- **兜底 O1(文档)**:在 CLAUDE.md / 协商约定里补「路由前先锚定身份→同组对端,跨组需理由」,但仅作兜底——单独的文档约定正是「留白→自由发挥」失败模式本身,不能依赖。
- **O3(仓外 ccb ask)判为本需求 direct-change out-of-scope**:`ccb ask` 在仓库外的 codex-dual runtime,所有权不在本仓且影响所有项目;改为向上游提 contract 诉求(暴露 current_actor / current_window / same_group_peers,支持跨组 warning/reason),不在本需求直接改它。

对端解析语义(避免在多成员 / 纯单 provider 组误选):同 window 内排除自己 → 优先显式 pairing/role → 无显式配置时仅当存在「唯一一个互补 provider 成员」才自动选定 → 否则返回 ambiguous / no_peer 并要求显式 target。默认路由仅覆盖「未显式指定 target 且解析出唯一对端」的 workflow consult/dispatch;Claude→Claude 跨组 review/cross-check 仍合法,保留显式 target(带 reason/warning)。

深度判定 = **human-decision**:固化层、是否给 ccb.config 引入 pairing/role schema、跨组软/硬策略、SLOT_IDS 是否纳入本需求,均为高影响产品契约,须用户拍板后再进技术设计。
## 歧义点

> 4 项已全部由用户在 su-flow 中拍板;决策记录见 ADR-0040;技术设计 + 4 片 dev_task 已生成物化。

1. 固化层 ✓:plugin 机制 + 中立 kernel 约定,**非** CLAUDE.md 提示(详见 ADR-0040)。
2. 对端解析 ✓:v1「同 window 唯一互补 provider」,非唯一 → ambiguous/no_peer 要显式;显式 pairing/role 留后续。
3. 跨组策略 ✓:软提示(reason/warning),不硬拦截;真正拦截交上游 runtime contract(PR4)。
4. 范围 ✓:Console SLOT_IDS/managed topology 泛化拆后续;新增同类项「Console usePendingConsult 默认 ccb_codex」亦拆后续(见 ADR-0040 后续 TODO)。
## 保真差异

- **原话主体其实是一段「先前事件根因复盘」**(关于某 agent 把项目级协商臆造路由到 main_codex、而非同组对端)。真正的需求是末尾两句:① 别把规则固化进 CLAUDE.md、机制宜进 plugin;② 如何自动找到同一 agent 组下的对端,且不绑定 slot 命名。本分析以末尾两句为交付主轴,把前文复盘当作背景证据而非交付项。
- **去特化**:原话举例用 slot3_claude→slot3_codex;本需求泛化为「任意 agent → 同 window 互补对端」,不特化 slot3,也不 hardcode "slot" 前缀,以贴合用户「未来可能不叫 slot-X,slot-X 只是 agent 组概念」。
- **拆解二选一发问**:原话把「ccb ask 固化」与「plugin 固化」并列发问;经查证 `ccb ask` 在仓库外 runtime,故不作二选一,而拆为「仓内 plugin/Console 直接交付 + 仓外 runtime 上游 contract」两条并行路径。
