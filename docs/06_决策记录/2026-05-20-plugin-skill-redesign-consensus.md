---
doc_type: consensus-memo
title: plugin / skill 范式重构 · 共识落档（v1 草案）
authored_by: Claude（与用户多轮对话 + ccb_codex 二次 consult 综合）
authored_at: 2026-05-20
status: draft-pending-product-sample
related_adrs:
  - ADR-0023  # plugin sovereignty 主决策（本文档是其下游具体化）
  - ADR-0023 Addendum (2026-05-19)  # 节点≠流水线工序的哲学锚点
consult_evidence:
  - rep_ddca4d7d3581  # codex 一轮 consult（工程细节倾向，已修正）
  - rep_c5ec94da955a  # codex 二轮 consult（产品语义对齐 + 3 项增量）
next_step: 起草产品语义样张（2 个节点示例 + 多 AI 协商样例）
---

# plugin / skill 范式重构 · 共识落档

## 背景

ADR-0023（2026-05-17）拍板 plugin sovereignty 方向，Addendum（2026-05-19）已写"节点 ≠ 流水线工序"。但实施未启动，且当前 kernel 设计、SKILL.md 写法仍是为旧 ReactiveScheduler 模式服务。

本文档落档**用户 + Claude + ccb_codex 多轮深度讨论后达成的共识**，作为后续 ADR-0030 / SP-A11 起草的基础。不预设决议性——共识可能被产品语义样张验证后调整。

---

## 一、核心思想（4 条，不可偏离）

1. **AI 是会思考的团队，不是流水线工人**
2. **多个 AI 之间真的讨论质疑，不是打招呼就结束**
3. **用户只在该被问的时候才被问，其他时候 AI 自治**
4. **plugin 是核心，Console 是可选 UI**

> 用户原话："整套系统应该 Plugin 或者 skills 驱动 db、md 的状态和业务流程的流转而不是由 UI 系统"
> "如果 codex 回复了 claude，claude 一定要深度思考(防止它偷懒当个传话筒)"
> "要有一个高层次的维度来管理 claude 的哪些类型问题/决策才是需要问用户"
> "这套 plugin 和 skills 需要可以脱离 console 程序运行"

---

## 二、5 点共识

### 共识 ① 节点定义采用"4 个白话问题 + 样例"格式

**解决的业务问题**：当前 kernel 节点 manifest 写得像机器调度指令（fixed_actions.steps / transition / guard），AI 在 anchor 里**根本不读这些 yaml**，只读 SKILL.md 文本。AI 看不懂的规则等于不存在的规则。

**共识方案**：节点定义改为用户能直接读懂的 6 段 markdown：

```markdown
# 节点：<名称>

## ① 什么时候进入这个模式？
（一句话意图描述，AI 自己判断是否进入）

## ② 进入后大概怎么做？
（建议套路 —— 软建议，不是硬性 step 顺序）

## ③ 什么时候算这个模式完成？
（自然语言退出条件）

## ④ 不能干什么？（硬约束）

## ⑤ 推荐可用的专家能力（sc 指令清单，可选）
- /sc:analyze --focus xxx → 用途...
- /sc:research <topic> → 用途...

## ⑥ 好/坏输出样例（质量标杆，codex 增量贡献）
好的样子：[具体例子]
坏的样子（反面教材）：[具体例子]
```

**关键**：
- 不写步骤号、不写 transition、不写 guard registry schema
- 样例不是 schema，是**质量标杆**——让 AI 自己有参照系
- AI 决定停留 / 切换 / 升级，runtime 不干预

**7 个节点身份保留**（requirement_analysis / technical_design / task_breakdown / dispatch / implementation / review / archive），仅改写 manifest 形态。codex 上一轮提的"节点主体重映射"（前 3 转 Requirement / 后 4 转 DeliveryUnit）暂不纳入——属于实体建模问题，与核心思想关联度低，留 SP-A10 单独讨论。

---

### 共识 ② 跨 AI 协商：自由文本 + 4 段锚点

**解决的业务问题**："Claude 找 Codex 沟通时容易当传话筒"——Codex 回复了，Claude 只说"已收到，继续"，没真深度思考。这是 LLM 默认行为，必须有机制约束。

**共识方案**：

**主体形态**：反思是**自由 markdown 文本**沉淀到日志/spec，不是 yaml event payload。

**最低共同格式（4 段锚点，codex 反质疑增量）**：自由不等于无格式，否则多 AI 痕迹不可比较、不可 grep 检索。最低保留 4 段标记：

```markdown
## 反思 codex 的回复

我同意的：
- ...

我不同意的：
- ... 理由 ...

我的盲点（之前没想到的）：
- ...

接下来做什么：
- ...
```

**质量约束**：
- **每次跨 AI 协商必须产生这段反思**（节点退出条件之一）
- **质量靠用户事后审计 + 审查时打回**督促，不靠系统 schema 强制检测
- AI 偷懒写"已收到，继续"→ 用户审计时打回要求补充推理（codex 二轮强调）

**多轮上限**：建议 3 轮。超过未达共识自动升级到用户（详见共识 ③）。

---

### 共识 ③ 必问清单 12 类（前置询问，分 3 大类）

**解决的业务问题**：AI 自治越彻底，跑偏成本越高。**关键决策必须前置问用户**，不能让 AI 跑完一堆错代码再让用户审计回退（codex 二轮反质疑修正）。

**12 类必问清单**：

#### 工程不可逆类（6）
1. 删除 / 覆盖用户文件
2. 数据库 migration（DROP / RENAME / 改类型）
3. 引入 / 移除依赖
4. 改公共 API / schema
5. git push / merge / reset
6. 外部服务凭证 / 集成

#### 用户偏好 / 价值观类（3）
7. **需求歧义澄清**（"用户原意是 A 还是 B"——AI 不能替用户答）
8. 产品方向 / UX 决策 / 命名
9. 业务规则定义（"已交付"是什么意思）

#### 用户权利保护类（3，codex 增量贡献）
10. **隐私 / 敏感数据外发**（解决"AI 帮你发邮件、推到云、调外部 API 时把用户机密带出去"）
11. **显著成本 / 付费资源消耗**（解决"AI 自动跑了个 1000 元 API 调用你不知道"）
12. **法律 / 安全 / 合规风险**（解决"AI 自动签了个 GPL 兼容性有问题的代码进项目"）

**PoC 项目放宽边界**：
- **可放宽**：1-6 工程不可逆类（PoC 接受快速试错）
- **绝不放宽**：7-12 涉及"替用户定义业务含义 / 选择产品方向 / 暴露敏感信息"——这是权利边界，与项目阶段无关

**约束机制**：
- **必问清单的项目必须前置问**（动作发生**之前**停下来 ask 用户）
- 反思痕迹是**后置审计**督促质量
- 两套机制不混淆

---

### 共识 ④ Superclaude 指令"选择触发 + 弱耦合"

**解决的业务问题**：用户问"节点里要不要保留对 superclaude 指令的自动映射或选择触发"。如果做"自动映射"——节点入口自动跑某 sc 指令——会**回到固定流程的老路**，违反"AI 自主决策"核心思想。

**共识方案**：
- 节点 = workflow unit（工作模式）
- `/sc:xxx` = tool（节点内可调用的专家能力）
- 节点 manifest 列**推荐 sc 指令清单**，不强制
- **AI 自己决定何时用、用哪个**
- 两个 plugin 弱耦合：sc 不可用（未安装 / crash）→ AI 自己分析或找其他 agent，**不阻塞节点工作**

**例**：需求分析节点的推荐清单可能含：
- `/sc:analyze --focus requirement-clarity` —— 深度分析需求歧义
- `/sc:research <topic>` —— 调研技术
- `/sc:business-panel` —— 业务视角审视
- `/sc:brainstorm` —— 探索性头脑风暴

**关键边界**：清单文案要让 AI 知道"完全可选"，不是"必须用"。

---

### 共识 ⑤ plugin 独立 + Console 只做投影

**解决的业务问题**：用户明确"plugin 和 skills 需要可以脱离 console 程序运行"。当前 SKILL.md 大量调用 Console HTTP API（如 `POST /api/requirements/:rid/breakdown-draft`），违反这一目标。

**共识方案**：
- **真相源**：plugin 直接读写 `docs/.ccb/*.md` / `docs/.ccb/*.json` / EventJournal 文件
- **Console 角色**：file watcher 监听 → 投影到 sqlite → 给前端可视化
- **Console 不写**业务字段
- plugin 不知道 Console 存在
- 没 Console 也能跑

**边界**：UI 按钮触发 anchor dispatch 这条链路 Console 仍有角色——它是**触发器**（dispatcher），不是**驱动器**（driver）。触发 = OK，写入业务字段 = 禁止。

**工程承载（codex 提，仅作前瞻）**：plugin-side runtime 需提供 lock / CAS / atomic write / schema 校验 / event intent+done 等基础能力，避免多 anchor 并发写冲突。**具体技术选型留 ADR-0030 起草时讨论**，本共识不展开。

---

## 三、已弃方案 / 暂不纳入

| 方向 | 状态 | 原因 |
|---|---|---|
| node-manifest 引入 yaml schema 字段（fixed_actions.steps / transition / guard registry） | **弃** | 写给机器看，AI 读不到，违反"AI 自治"思想 |
| agent_reply_reviewed yaml event payload | **弃** | 过度结构化，反思应该是自然语言 |
| Hook 拦截"深度反思质量" | **弃** | hook 只能看工具调用，不能理解语义。反思质量靠用户审计 |
| Decision Card 严格 yaml | **降级** | 仅用于 Layer 1/2 高影响决策，不卡片化每个小决策 |
| 节点主体重映射（前 3 → Requirement / 后 4 → DeliveryUnit） | **暂不纳入** | 实体建模问题，与核心思想关联度低，留 SP-A10 单独讨论 |
| sqlite WAL vs jsonl / 文件锁 / CAS 等工程细节 | **延后** | ADR-0030 起草时讨论，不在共识层展开 |
| Hook fail-closed vs fail-open / 版本协商 / kernel hash pin | **延后** | 实现层细节 |

---

## 四、表达约定

未来 claude 转述 codex 的工程内容给用户时，**必须按"业务问题 → 技术解法"格式**：

| 工程细节 | 解决的业务问题 |
|---|---|
| sqlite WAL | "两个 AI 同时写日志会不会丢数据" |
| atomic write | "AI 写文件到一半 crash 文件会不会残缺" |
| lock / CAS | "两个 anchor 同时改同一文件会不会冲突" |
| event intent + done | "AI 说做了某事但是不是真做完了" |

用户能直接判断技术方案是否解决真实产品问题，而不是被实现细节淹没。

---

## 五、下一步：产品语义样张（不写 ADR / 不动 runtime）

**codex 二轮建议 + claude 同意**：先出一份用户能读懂的"产品体验样张"，确认形态后再谈实现承载。

### 样张内容

1. **2 个节点定义示例**（需求分析 / 技术设计）：用"4 个白话问题 + 样例"格式写完整
2. **一段真实多 AI 协商样例**：模拟从用户输入 → AI 进入节点 → 找 codex → 深度反思 → 决策 → 升级用户 → 完成的**完整对话流**
3. **必问 12 类清单 + PoC 边界**：白话写
4. **sc 指令选择性调用样例**：在协商样例里展示

### 起草路径

claude 起草 v1 → 用户阅读反馈 → 调整后再讨论"怎么实现"。

**约束**：800-1500 字 markdown，不是技术文档，是产品体验示例。用户看完能判断"这就是我想要的样子"或"这里要调"。

---

## 六、关联文档

- ADR-0023 plugin sovereignty 主决策（含 Addendum）
- ADR-0023 Addendum（2026-05-19）"节点 ≠ 流水线工序"
- 待起草：ADR-0024 plugin-side primitive runtime
- 待起草：ADR-0030 SKILL.md / 节点 manifest 新形态规范
- 待起草：产品语义样张（基于本共识）
- 现 kernel：`su-ccb-claude-plugin/references/kernel/`（待重构）
- 现 7 节点：`su-ccb-claude-plugin/references/kernel/nodes/*.node.yaml`（身份保留，形态重写）

---

## 七、协商证据

| 节点 | 文件 / Job ID | 时间 | 关键产出 |
|---|---|---|---|
| 用户原话首轮 | 主仏对话 | 2026-05-20 | 4 条核心思想 + 5 个具体问题 |
| Claude 输出深度分析 | 主仏对话 | 2026-05-20 | Deep Consult Loop / Decision Layering / 三层模型 |
| ccb_codex 一轮 consult | job_01027d11fc53 / rep_ddca4d7d3581 | 2026-05-20 | 工程细节倾向（已修正）|
| 用户反馈"偏离核心思想" | 主仏对话 | 2026-05-20 | 表达约定 + sc 指令维度 |
| ccb_codex 二轮 consult | job_22c1744ee2cc / rep_c5ec94da955a | 2026-05-20 | 5 点产品语义确认 + 3 项增量 |
| **本共识落档** | docs/.ccb/decisions/2026-05-20-plugin-skill-redesign-consensus.md | 2026-05-20 | v1 草案 |
