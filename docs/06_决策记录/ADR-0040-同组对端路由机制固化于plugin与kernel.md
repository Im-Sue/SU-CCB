---
id: ADR-0040
title: agent 协商/派工默认路由到同组(window)对端，机制固化于 plugin+kernel 而非 CLAUDE.md
doc_type: adr
status: accepted
supersedes: []
superseded_by:
date: 2026-05-31
---

# ADR-0040: agent 协商/派工默认路由到同组(window)对端，机制固化于 plugin+kernel 而非 CLAUDE.md

> 一个决策一篇，记下"为什么这么定"。
>
> **状态**(frontmatter `status`)：accepted ｜ **拍板人**：用户(im.suyejian)

---

## 一、背景

- **触发事件**:某 agent(slot3_claude)做 consult 路由时,未从"我是谁 / 在哪个 window"推出同组对端(应为 slot3_codex),而临时编造"项目级 → main_codex"启发式,投错且全程无信号,直到用户发现。
- **根因**:① agent 有据不用、用臆造规则替代上下文推理(主因);② 机制留白——`ccb ask` 只推 sender,不暴露同组对端、不对跨组投递做任何提示/拦截(次因,放大并隐藏错误)。
- **约束**:`ccb ask` 运行时在仓库外(`/home/sue/.local/share/codex-dual`);CLAUDE.md 仅 Claude 可见且被 CCB 托管注入(易被覆盖);组当前命名为 slot-X,未来可能改名。
- **需求**:`docs/02_需求设计/ccb消息投递错乱问题-c5c98f-需求.md`。

---

## 二、决策

1. 把"识别并默认选择同组对端"做成**机制**(plugin 可确定性解析 + 流程内软提示),**不靠 CLAUDE.md 提示词**。
2. **全局规则真相源放中立层**:路由 / 对端约定写入 `references/kernel/`(provider 中立),`ccb.config [windows]` 为组成员关系数据源;Claude(plugin)与 Codex(codex-skills)各自实现,避免漂移。
3. **组抽象 = window 成员关系**,不绑定 "slot" 字符串(对改名鲁棒)。
4. **对端解析**:同 window 排除自己 → 唯一互补 provider → peer;0/多 → ambiguous/no_peer,要求显式 target。v1 不引入显式 `pairing/role` 配置 schema。
5. **默认路由收窄**:仅"未显式 target 的流程化 consult/dispatch"启用默认对端;Claude→Claude 跨组 review 等合法场景保留显式 target。
6. **跨组软提示**:跨组要 reason / warning,不静默;不硬拦截。
7. **强制力(发错即拦,含手敲命令)= 仓外 ccb runtime 的上游依赖**:本仓只提 contract 诉求(暴露 `current_actor` / `current_window` / `same_group_peers` + 跨组 warning),**不直接改 runtime**(该 contract 部分对上游为 `proposed`)。

---

## 三、否决的方案

| 方案 | 为什么没选 |
|------|------------|
| 只写 CLAUDE.md / 提示词 | 纯提示靠自觉,正是本次失败模式;仅 Claude 可见;被 CCB 注入覆盖易漂移 |
| 直接改仓外 `ccb ask` | 仓外、影响所有项目、所有权不在本仓;改为上游 contract |
| hardcode "slot" 前缀识别组 | 未来组改名即失效 |
| 立即引入显式 `pairing/role` 配置 | 当前 1c+1x 组无必要,改动 / 迁移成本大;留后续 |
| 现在做 Claude 拦截 hook | 仅覆盖 Claude 侧手敲、部分且增工;按增量先做软帮手 MVP,拦截交 runtime |

---

## 四、影响

- **好处**:消除流程化协商 / 派工的错投主路径;组抽象对改名鲁棒;约定中立、两侧一致。
- **代价 / 风险**:plugin 软提示拦不住手敲 `ccb ask`(待 runtime);两侧实现需防漂移(同约定 + 同测试向量兜底);Console 同类默认路由(`usePendingConsult → ccb_codex`)未在本需求处理。
- **受影响**:`references/kernel/`、`su-ccb-claude-plugin`(新增 `lib/agent-group`)、`su-ccb-codex-skills`、(上游)ccb runtime;Console 投影只读。
- **后续 TODO(不在本需求)**:Console `SLOT_IDS` / managed topology 去硬编码泛化;Console `usePendingConsult` 默认目标同类修正。

---

## 五、关联

| 关系 | 对象 |
|------|------|
| 相关需求 | `docs/02_需求设计/ccb消息投递错乱问题-c5c98f-需求.md` |
| 相关设计 | `docs/03_开发计划/ccb消息投递错乱问题-c5c98f-技术设计.md` |
| 落地任务 | PR1 `pr1-group-resolver` / PR2 `pr2-routing-wiring` / PR3 `pr3-codex-skills-peer` / PR4 `pr4-runtime-contract` |

---

## 六、决策依据

- 与同组对端 **slot1_codex** 的两轮 `mode=consult` 协商:round-1(需求层:固化层 / 对端模型 / red flags)、round-2(物化前可执行性核验:落点、`[windows]` parser、接线现实性)。
- 用户在 su-flow 中分阶段拍板:固化层 = plugin 机制(非 CLAUDE.md);拦截做软帮手 MVP(选 a);Console consult 同类问题拆后续;PR4 保留。

---

## 七、附录:仓外 ccb ask runtime contract 诉求(status=proposed)

> **状态**:proposed upstream dependency
> **适用对象**:仓外 `ccb ask` runtime(`/home/sue/.local/share/codex-dual`)
> **本仓处理**:仅记录 contract 诉求;不直接修改 runtime;不阻塞 PR1-PR3 已落地的 plugin / codex-skills 软机制。

### 7.1 请求 runtime 暴露的字段

| 字段 | 语义 | 动机 |
|------|------|------|
| `current_actor` | 当前发送方身份;优先为 agent 名,如推断失败显式返回 `user` / `unknown`,不要静默伪装。 | 让发送路径先锚定"我是谁",避免调用方凭项目级默认值猜 sender / target。 |
| `current_window` 或 `current_group` | `current_actor` 所在 `ccb.config [windows]` window;组定义为同一 window 的成员集合,不依赖 `slot` 字符串。 | 让 runtime 能判定同组 / 跨组,并对未来非 slot 命名保持鲁棒。 |
| `same_group_peers` | 当前 window 内排除 `current_actor` 后的候选 peer 列表,至少包含 `{ agent_name, provider }`;若 runtime 能应用互补 provider 规则,可额外给出唯一 `default_peer` 或 `peer_resolution={kind, peer?, candidates?}`。 | 让上层 workflow 和手敲命令都能看到"同组对端是谁";对 0/多候选给出可解释退化。 |
| `target_window` 或 `target_group` | 显式 target 所在 window;target 不存在或无法定位时显式返回 `unknown`。 | 支撑跨组检查与可观测 warning。 |
| `route_warning` | 对跨组、actor 未知、target 未知、peer ambiguous/no_peer 等情况的结构化 warning。 | 避免错投静默发生,便于 CLI 输出、EventJournal 或日志审计。 |
| `cross_group_reason` | 发送方提供的跨组理由;可来自 CLI 参数或交互确认。 | 保留合法跨组 review / cross-check,但要求理由显式化。 |

### 7.2 请求 runtime 支持的行为

1. **默认不猜项目级 target**:当 `current_actor` 可定位且未显式 target 时,runtime 可暴露同组 `default_peer`;若无法唯一解析,应返回 `ambiguous` / `no_peer` 并要求显式 target,不能 fallback 到 `main_codex`、`ccb_codex` 或任意 provider 默认值。
2. **跨组投递提示**:当 `target_window != current_window` 时,runtime 应在 CLI 输出或返回结果中给出 warning;如调用方未提供 `cross_group_reason`,应要求补理由或显式确认。
3. **覆盖手敲命令**:上述检查必须覆盖直接 `ccb ask <target>` / `ask <target>` 的人工手敲路径,因为 plugin 层无法拦截所有 shell 命令。
4. **不硬禁合法跨组**:Claude→Claude review、跨组 cross-check、main agent 协调等显式场景仍允许;要求是 target 和 reason 可见,不是禁止协作。
5. **可审计**:runtime 应把 actor、target、window/group、peer_resolution、route_warning、cross_group_reason 写入提交结果或可检索日志,方便事后定位错投。

### 7.3 与 plugin 软提示的分工

| 层 | 已/应负责 | 不负责 |
|----|-----------|--------|
| plugin / skill helper(PR2) | 流程化 consult / dispatch 内,在发 ask 前读取 `ccb.config [windows]` 并尽力解析同组对端;对跨组 target 产出 warning / reason 要求。 | 不拦截用户在 shell 里手敲 `ccb ask`;不保证所有 provider / 所有项目的 runtime 行为一致。 |
| codex-skills(PR3) | Codex 侧读取同一 kernel 约定和测试向量,在需要判断对端时与 Claude 侧语义对齐。 | 不替代 `ccb ask` runtime 的 sender/target 校验。 |
| ccb ask runtime(本附录诉求) | 统一暴露 actor/window/peers,并在所有提交入口(含手敲命令)对跨组或不可唯一解析目标给 warning / reason 要求。 | 不改变本仓已定义的 `ccb.config` 格式;不要求立即引入 pairing / role schema。 |

结论:PR2 的 plugin 软提示解决"流程内自动错投"主路径;真正能覆盖"手敲 `ccb ask` 错投也发不出去或至少有显式 warning"的强制力,必须由仓外 runtime 提供。本诉求是上游依赖,不阻塞本需求 PR1-PR3 的交付。
