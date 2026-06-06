---
id: cmpzoupdv863041443e52441f
title: 整套oriel和plugin缺少主动的消息通知机制
doc_type: requirement
status: planning
created: 2026-06-04T16:07:08.036Z
analysis_input_hash: 15f363447f93a8162970ff5069bca4b322027df3b1978e09ae796a4ebfd0522b
analysis_applied_at: 2026-06-04T16:36:41.384Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

整套oriel和plugin缺少主动的消息通知机制，先调查一下ccb自带的消息通知机制是怎样的？深度分析一下我们系统是直接结合还是有什么刚好的方案可以给到使用者，能够好的触达用户及用户更快速的切换进入到需求、slot。

## 原话（verbatim）

整套oriel和plugin缺少主动的消息通知机制，先调查一下ccb自带的消息通知机制是怎样的？深度分析一下我们系统是直接结合还是有什么刚好的方案可以给到使用者，能够好的触达用户及用户更快速的切换进入到需求、slot。

## 二、背景与目标

### 现状调查（用户要求先查的「ccb 自带通知机制」）

经三路并行勘探 + 源码核验，**整套系统当前没有任何主动触达，全部为被动 / 拉取**：

- **CCB runtime（codex-dual，`~/.local/share/codex-dual`）**：sidebar TUI 约 1s 轮询 `project_view`（1s TTL，重读 `.ccb/ccb.config` tips），显示 agents / comms / tips / provider activity，支持点击或回车聚焦 window / agent——但**是状态面板，不是主动通知**。`[CCB_TASK_COMPLETED]` 等 marker 定义了但未实际 emit；heartbeat 只记录不显示。**邮件通道仅有 `config/mail/config.template.json`（默认 `enabled:false`），本安装 `lib/mail` 不存在、文档已将 mail/maild 退役**——不是「关着的现成开关」。
- **Console（su-oriel）**：已有 **task 级 SSE**（`/api/tasks/:taskId/events` + `useSharedTaskEventStream`，server 1s 轮询 DB → 推浏览器）——但**是按任务的局部流，不是项目级全局通知流**；`publishProjectionSignal` 当前无调用点。`AlertStrip` 只在打开该任务详情页时可见，`pending-interactions` 默认 30s 轮询。无 Browser Notification / 声音 / favicon 或 title badge / 全局 attention 状态。
- **plugin**：`appendEvent` 经 localhost hook POST Console（300ms，fail-open）；Console receiver 只做 reindex / scan / slot activity，不产生用户通知。severity `attention`（review_intent / user_arbitration）已算出，但只被动渲染进 timeline。
- **既有相关产出**：slot-tip 投影（需求 91b0d7 已交付）把 `slot-N: 需求名` 写进 `[ui.sidebar.view].tips`——适合「看见 slot↔需求绑定」，但仍是**被动可见信息**，不标「哪个 slot 在等你」。

### 目标

1. **触达**：当出现「需要用户介入」或「用户的活已完成」的事件时，主动抓住用户注意力（现在完全缺失）。
2. **快速切换**：从该信号一键进入对应**需求**（Console 页）或 **slot**（tmux 窗格）。

## 三、讨论与决策（协商 / 反思 / sc 留痕）

### Codex 协商（slot1_codex，job_f00c008a39e4，consult 模式）

Codex 给出实质质疑（非背书），核心修正三点：

1. **不是「接 CCB 自带 vs Console 自己做」的二选一**；真正要先定的是 **attention 语义**（哪些事件、severity、去重 / ack、点击落点）。
2. **现有 SSE 不能「白捡」**：它是 task 级局部流，**不是项目级全局通知通道**；需先建**单一全局 attention 源（AttentionEvent / Inbox）**，再决定用 SSE 或短轮询投给 Console。
3. **邮件 / OS / IM 不适合做 MVP 主路径**（退役、权限、隐私、WSL2 兼容成本高）；两舱不算过度设计，**前提是只有一个 attention 源、多端只是投影**。

### 4 锚点反思

- **同意**：单一 attention 源 + 多端投影；attention 语义先于通道选择；邮件通道非低风险开关、C 必须显式 opt-in；触达强度是产品边界决策（升级用户）；「通知必达」不能建立在 fail-open hook 上、需 scan / 轮询兜底。
- **修正自己**：原说「复用已有 SSE 直接加通知」过度乐观——现有 SSE 是 task 级、非全局通道，`publishProjectionSignal` 无调用点；改为「新建全局 attention 源 + 复用事件输入与浏览器投影模式」。保留「轻量增量」定位（事件输入与到浏览器投影模式确已存在），但承认核心要新增一个全局 attention 源，非纯白捡。
- **盲点**：① 把 task 级 SSE 误当全局通道；② 以为邮件通道是现成开关（实为退役 / 缺失）；③ 漏了「单一 attention 源」这个让两舱不重复造规则的前提；④ 漏了 ack / 已读 / 冷却 / 免打扰这套 attention 预算；⑤ 漏了 ADR-0027 漂移若被依赖需补 ADR / 设计说明。
- **下一步**：落本需求文档 → 仅向用户抛「触达强度」一个拍板题（带默认）→ 据用户意图决定是否进入技术设计。

### sc 指令使用 / 替代说明

本轮未单独调用 `/sc:analyze`、`/sc:research`、`/sc:business-panel`；其视角由**三路并行源码勘探**（需求清晰度 / 隐藏约束）+ **通知领域常见实践推理**（research 替代）+ **显式隐私 / 成本 / WSL2 业务复核**（business-panel 替代）+ **Codex 协商质疑**覆盖。后续若进入技术设计，建议补 `/sc:analyze` 复核 attention 源设计。

## 四、功能 / 范围

| 层 | 内容 | 取材 |
|----|------|------|
| **核心 · 单一 attention 源** | 项目级 `AttentionEvent / Inbox`：归集「需要用户介入 / 用户的活已完成」类事件，带 severity、去重、ack 或已读状态 | 输入复用既有 EventJournal / webhook 事件 |
| **A · Console 通知投影** | Browser Notification + 声音 + favicon 或 title badge，仅作 attention 源的投影；点击 deep-link 直达 `/requirements/:id` 或 `/tasks/:id` | 复用浏览器投影模式；通道需接全局源（非直接复用 task SSE） |
| **B · 终端 / tmux sidebar attention 投影** | 把 attention 标记投到 sidebar tips / comms 风格行（如 `slot-2: ⚠️待你决策 需求名`），辅助 tmux 用户快速聚焦 window / agent | 扩展已交付的 slot-tip 投影 |
| **C · 硬触达 adapter（延后 · opt-in）** | OS 桌面通知 / 邮件 / IM webhook，解决「Console 与 tmux 都关闭」场景 | 显式 opt-in，默认关闭 |

## 五、业务规则（attention 预算）

1. **触发事件（首批，默认）**：仅「等待用户决策」（review gate / user arbitration / consult 待回）与「任务或 agent 完成」两类；其余降级为被动可见，不主动弹。
2. **severity 分级**：至少区分「需要你决策」（高，主动弹）与「仅告知」（低，被动）。
3. **去重 + 已读（ack）**：同一主体重复事件合并；点击或进入即 ack，已 ack 不再弹。
4. **冷却 + 免打扰**：高频事件冷却；提供 DND 开关。
5. **单一来源**：Console 与 sidebar 两端只投影同一 attention 源，不各自算规则。
6. **必达兜底**：plugin hook fail-open，不能把「通知必达」建立在 hook 成功上；需 scan / 轮询兜底对账。

## 六、边界 / 不做项

- 不把 CCB 邮件 / OS / IM 作为 MVP 主路径（仅作 C 的 opt-in adapter）。
- 不改 CCB runtime 本体（runtime 只知 agent / window / job，不懂 requirement attention；attention 语义留在 Console / plugin 侧）。
- 不做跨设备 / 移动端提醒（单机本地工具优先）。
- 不在 Console 与 sidebar 两处重复实现 attention 规则。

## 七、开放问题 / 假设

- **【待用户拍板 · 已带默认】触达强度**：默认采纳 **local-first**（A+B 现在做、C 显式延后为 opt-in adapter），假设「Console 或 tmux 至少开着一个」。这是产品边界决策，已显式邀请用户改向「全关闭也要叫醒我」——若改向，则 C 不能延后、需现在引入 OS / 邮件 / IM 并接受隐私外泄 + WSL2 成本。未收到改向即按默认推进（非 TBD）。
- **假设 · 首批事件范围**：默认 = 「等待用户决策」+「任务或 agent 完成」；用户可增减。
- **风险记录 · ADR-0027 漂移**：ADR-0027 将「SSE / WebSocket push 到前端」列为 v1.x 非目标，但 Console 现已有 task SSE；若本需求依赖项目级全局 push，须补 ADR / 设计说明，否则后续会被「v1.x 非目标」反向质疑。

## 八、风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| 通知疲劳 | 用户屏蔽或忽略 | severity + 去重 + ack + 冷却 + DND |
| 把 task SSE 误当全局通道 | 漏通知 / 架构返工 | 先建单一全局 attention 源，再选投递通道 |
| fail-open hook 漏事件 | 通知不必达 | scan / 轮询兜底对账 |
| C 触达引入隐私外泄 + WSL2 摩擦 | 成本 / 隐私 | 默认 local-first，C 仅 opt-in |
| ADR-0027 漂移 | 后续治理质疑 | 补 ADR / 设计说明 |

## Claude 解读

用户要给整套 oriel+plugin 补上**主动触达**能力 + **快速切换**入口。我理解为两层：
(1) 主动抓注意力——当“需要你介入”或“你的活已完成”时越过屏幕叫你；
(2) 一键切换——从信号直达对应需求（Console）或 slot（tmux）。

用户原话的“直接结合 ccb 自带 vs 刚好的方案”我理解为开放式方案探索。经 Codex 协商（slot1_codex / job_f00c008a39e4）重构为：**建一个单一全局 attention 源（AttentionEvent/Inbox），Console 通知与 tmux sidebar 都只是它的投影**（CCB runtime 只知 agent/window/job、不懂 requirement attention，故 attention 语义留在 Console/plugin 侧）。

推荐 **local-first**：A（Console 通知投影）+ B（sidebar attention 投影）先做；C（OS/邮件/IM 硬触达）作 opt-in 显式延后。
## 歧义点

1. **触达强度**（最高影响）：“主动”要多硬——Console/tmux 至少开一个即可，还是全关也要叫醒？→ 已带默认（local-first）升级用户拍板。
2. **事件范围**：哪些事件值得主动弹？→ 默认“等待你决策”+“任务/agent 完成”，用户可增减。
3. **主舱**：Console（浏览器）还是终端（tmux）？→ 判断两者互补，前提是单一 attention 源、多端只投影。
4. **切换落点**：deep-link 目标随舱不同（Console `/requirements/:id` vs tmux 跳窗）。
5. **attention 预算**（Codex 补）：去重 / ack / 冷却 / 免打扰——已纳入业务规则并设默认。

少于此不构成偷懒：成本/合规未单列，因 local-first 默认不外泄、本地工具成本可忽略；仅当用户选“硬触达”才升级隐私/依赖问题。
## 保真差异

原话逐字保留（见上）。解读与原话的差异：
1. 原话“消息通知”→ 我具体化为“主动 attention 触达 + 快速切换”两层，未缩放范围；
2. 原话“直接结合还是刚好的方案”字面像二选一，我据 Codex 协商重构为“单一 attention 源 + 多端投影”的第三形态，并把“直接结合 ccb 自带（邮件通道）”依据源码核验降级为 opt-in（本机 `lib/mail` 缺失、mail/maild 已退役）——此为基于已核验事实的方向收敛，非否决用户原意；
3. 触达强度采默认而非替用户定死，已显式邀请改向。
