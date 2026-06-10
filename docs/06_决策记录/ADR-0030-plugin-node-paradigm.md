---
id: ADR-0030
title: SKILL.md / 节点 manifest 新形态规范（AI 编排器范式）
status: active
decided_at: 2026-05-21
last_updated: 2026-05-21
decider: 用户（Claude + ccb_codex 五轮 consult 后拍板）
reviewer: ccb_codex
codename: ai-orchestrator-paradigm
related_doc: docs/02_需求设计/ccb-plugin/2026-05-20-plugin-product-semantics-sample-v2.md
related_consensus: docs/.ccb/decisions/2026-05-20-plugin-skill-redesign-consensus.md
consult_evidence: [rep_ddca4d7d3581, rep_c5ec94da955a, rep_343858374258, rep_0eece5b2c9b2, rep_4a954d5dda22]
supersedes_normative: [旧 node-manifest-schema.yaml fixed_actions.steps 范式, 旧 SKILL.md "thin facade 引用 manifest" 范式]
related_adrs: [ADR-0023, ADR-0023 Addendum, ADR-0024, ADR-0028, ADR-0029]  # ADR-0023: plugin sovereignty（主决策）; ADR-0023 Addendum: 节点≠流水线工序; ADR-0024: plugin-side primitive runtime（待起草）; ADR-0028: 两层实体; ADR-0029: 大状态指令层
implements_via: [SP-A11]  # SP-A11: plugin / skill / kernel 全量重写
---

# ADR-0030: SKILL.md / 节点 manifest 新形态规范

## Status

Accepted（2026-05-21）。基于用户多轮深度对话 + ccb_codex 五轮 consult 拍板，配套样张 v2.1。

## Context

ADR-0023 拍板"plugin sovereignty"方向，Addendum 已写"节点 ≠ 流水线工序，是可调用能力"，但**节点 manifest 和 SKILL.md 仍是为旧 ReactiveScheduler 模式服务的形态**：

1. `node-manifest-schema.yaml` 的 `fixed_actions.steps` 设计是给 Console scheduler 跑流水线用的
2. `transition-table.md` 是预定义状态转移图，AI 编排范式下应该 AI 自己判断
3. SKILL.md 大多是"thin facade，引用 kernel manifest"——但 AI 在 anchor 里**不会自动加载** SKILL.md link 到的 kernel yaml；AI 实际只读 SKILL.md 文本
4. 现有 SKILL.md 大量调用 Console HTTP API（如 `POST /api/requirements/:rid/breakdown-draft`），违反"plugin 独立运行"目标

用户对目标范式做了精确校正（详见样张 v2.1）：

- AI 是会思考的团队，不是流水线工人
- 多个 AI 之间真的讨论质疑，不是打招呼就结束
- 用户只在该被问的时候才被问，其他时候 AI 自治
- plugin 是核心，Console 是可选 UI

## Decision

### 决策 1 · 节点 manifest 新形态："4 个问题 + 列表骨架 + 段落深度 + sc 推荐 + 三档样例"

每个节点 manifest 必须包含 6 个章节，**全部用 markdown**（不是 yaml schema）：

```markdown
# 节点：<名称>

## ① 什么时候进入这个模式？
（触发意图清单 + AI 自判原则）

## ② 进入后大概怎么做？
（**必须覆盖的核心要点**：列表 7-10 项，强制覆盖）
（**深度说明**：自然段补充每个要点的"为什么这么做"和具体例子）

## ③ 什么时候算这个模式完成？
（**必须同时满足**：列表 5-7 项硬条件）
（完成后去向：自动继续 / 自然停下，**不每节点问"要继续吗"**）

## ④ 不能干什么？（硬约束）
（绝对禁止：列表 5-6 项）
（**为什么这些是硬约束**：自然段说明）

## ⑤ 推荐的 sc 指令（本节点强烈推荐使用）
（按"使用阶段"组织：第一阶段 / 第二阶段 / 第三阶段）
（每个 sc 指令：用途 + **为什么强烈推荐**）
（**工程兜底**：sc 不可用时不阻塞 + 必须显式说明替代方式）

## ⑥ 好 / 中等 / 坏输出样例
（好的样子：完整示例）
（**中等但不合格的样子**：最常见的"假合格"形态——这是关键）
（差的样子：反面教材）
```

**核心约束**：

- **列表骨架** 防漂移（AI 降智期容易跳过段落里的关键约束）
- **段落深度** 防填空作文（避免"已收到，继续"式空泛回复）
- **三档样例**（不是两档）—— 中等档反映 AI 最常出的"看似完整实际没问关键问题"的中间态

### 决策 2 · SKILL.md 新角色：意图入口 + 节点集声明

SKILL.md 不再是"thin facade 引用 kernel manifest"。新角色：

1. **指令意图说明**（用户视角：这个指令是干什么的）
2. **节点集声明**（这个指令进入时可用的节点列表 + 每个节点 manifest 路径）
3. **触发约定**（参数格式、调用入口、Console dispatch payload 等）
4. **plugin 独立运行约定**（不调用 Console HTTP API，直接读写 `docs/.ccb/*.md / *.json`）

SKILL.md 不再写"节点内执行规则"——那是节点 manifest 的事。

### 决策 3 · 跨 AI 协商规则：v1.x always-on + 退出原则

**v1.x 阶段强约束**（plugin 协作训练期）：

- 任何业务节点必须找 codex（或其他 agent）协商，**无论需求大小**
- 最小协商标准：1 轮 codex 回复 + 1 段 4 锚点反思
- 4 锚点：我同意的 / 我不同意的 / 我的盲点 / 接下来做什么
- **每段必须有具体推理段落**（防填空作文）
- codex 回复必须**指出至少一个风险或确认无风险的理由**（不能只说"看起来对"）

**多轮协商退出原则**（codex 五轮反质疑修正）：

- v1.x 不预设轮次上限
- 退出判据 = **当一轮无新增信息时立即升级用户**
- 不是"省 token"，而是"避免为了讨论而讨论的形式主义"

**v1.5+ 后期优化（占位）**：

- 简单需求的轻量协商
- 跳过条件设计
- 触发条件清单
- 当前 v1.x **不做这些**

### 决策 4 · 必问用户清单 12 类（前置询问 + 命中判定）

**3 大类共 12 项**：

工程不可逆类（6）：删除/覆盖文件 / DB migration / 依赖增删 / 公共 API/schema 改动 / git push merge reset / 外部服务凭证集成

用户偏好/价值观类（3）：需求歧义澄清 / 产品方向 UX 命名 / 业务规则定义

用户权利保护类（3）：隐私敏感数据外发 / 显著成本付费资源消耗 / 法律安全合规风险

**关键修正**（codex 五轮反质疑）：

- 节点完成条件 = **所有命中的必问项**已处理（不强求不存在的问题被回复）
- "命中"判定由 AI 按需求实质判定，不要凑数

**PoC 项目放宽边界**：

- 可放宽：1-6 工程不可逆类
- 限定条件：**必须在可恢复 sandbox 范围**（临时目录、容器、可 git revert）
- 绝不放宽：7-12（替用户定义业务含义 / 选择产品方向 / 暴露敏感信息）

### 决策 5 · sc 指令强推荐 + 工程兜底

- sc 不是装饰工具，是减少 AI 盲点的专家视角
- 每个节点 manifest ⑤ 章节明确**推荐使用顺序 + 用途 + 业务理由**
- AI 应该用，不用要显式说明替代方式
- sc 不可用（未安装 / crash）→ 不阻塞节点工作，但必须声明：
  - 哪个 sc 不可用
  - 原本想用它解决什么问题
  - 用什么替代方式覆盖

### 决策 6 · plugin 独立运行（不依赖 Console）

- 真相源：plugin 直接读写 `docs/.ccb/*.md / *.json / journal.jsonl`
- Console 角色：file watcher 监听 → 投影到 sqlite → 前端可视化
- Console 不写入业务字段
- plugin 不调用 Console HTTP API
- 没有 Console 也能完整跑节点工作

### 决策 7 · AI 自治 vs 节点级协商的边界

**节点级**必须协商：进入任意业务节点必须走最小协商

**节点内细节** AI 自决：变量命名 / 内部算法 / 文档措辞等局部决策不需要每个都协商

**审计层面**：所有自治决策也写 EventJournal，用户随时 grep / diff 审计

### 决策 8 · Glossary 小词典作为 kernel 标准产物

为防止 AI / 用户因不懂术语而漂移，**节点 manifest 之外**新增 `references/kernel/glossary.md`，含至少 18 个术语：节点 / manifest / kernel / EventJournal / anchor / ccbd / agent / spec / dispatch / projection / sc 指令 / ORM / schema / migration / runtime / CAS / fail-closed / fail-open / plugin 域。

工程术语保留 + 加业务化解释，而非删除工程词。

## 非目标（明确不做）

- 不重新设计实体模型（保留 ADR-0028 两层实体）
- 不动 Console 物理 anchor 生命周期 / file watcher / EventJournal collector（保留 ADR-0023 决策 2）
- 不立即清空 Console SQLite（ADR-0023 决策 6 的 clean start 时机由用户另行决定）
- 不立即实现 plugin-side runtime（ADR-0024 范围，本 ADR 仅定义新形态）
- 不引入新节点（保留 7 节点身份）
- 不在本 ADR 展开技术实现细节（lock / CAS / atomic write / sqlite WAL 等留 ADR-0024）

## 替代方案

| 方案 | 核心差异 | 拒绝原因 |
|---|---|---|
| A · 保留 fixed_actions.steps + Console scheduler 跑流水线 | 不变 | 与 ADR-0023 Addendum 哲学冲突，AI 无法发挥编排能力 |
| B · 全删 manifest 改纯 LangChain Tool Calling | 节点 = function call | 节点是工作模式不是 function，丢失"工作流约定" |
| C · 节点 = 纯自然语言指引（无列表骨架） | 完全自然语言 | 模型降智期容易漂移，用户 4 点纠偏明确拒绝 |
| D · 节点 manifest + yaml schema 严格 schema | 每个字段类型化 | 回到 thin facade 老路，AI 实际不读 yaml |

## 影响范围

### 替代

- 旧 `node-manifest-schema.yaml` 的 `fixed_actions.steps` 字段：deprecated（保留以兼容存量节点，新节点不用）
- 旧 `transition-table.md`：deprecated（事件 outcome 登记表保留作记录，但不再驱动转移）
- 旧 `guard-registry.md`：deprecated（节点内"硬约束"由 manifest ④ 章节自然语言表达）
- 旧 SKILL.md "thin facade 引用 manifest" 模式：全量重写

### 新增

- `references/kernel/glossary.md`（决策 8）
- `references/kernel/must-ask-checklist.md`（决策 4 的 12 类清单 + PoC 边界）
- `references/kernel/decision-card-schema.yaml`（待 v1.5+ 细化，本 ADR 仅占位）
- `references/kernel/agent-reply-reviewed-schema.yaml`（4 锚点反思的 minimal anchor，本 ADR 仅占位）
- 7 个新节点 manifest（按本 ADR 决策 1 形态）
- 17 个新 SKILL.md（按本 ADR 决策 2 形态）

### 保留

- 7 节点身份（requirement_analysis / technical_design / task_breakdown / dispatch / implementation / review / archive）
- `state-schema.yaml`（主体字段定义不变）
- `kernel.meta.json`（版本治理机制不变）
- ADR-0023 / 0028 / 0029 的主决策
- 现 Console 物理资源管理代码（anchor 生命周期 / file watcher / EventJournal collector / Broker）

## 验收

ADR-0030 落地（通过 SP-A11 实施）后必须满足：

1. 7 个节点 manifest 全部按决策 1 形态重写
2. 17 个 SKILL.md 全部按决策 2 形态重写
3. 新 kernel 文件齐全（glossary / must-ask-checklist / 两个 schema 占位）
4. 旧 kernel 文件标记 deprecated（保留兼容）
5. 至少一个真实需求按新范式从需求分析跑到归档跑通（不分批，全量验证）
6. `pnpm test` / build 通过（如果 SP-A11 涉及代码改动）

## 风险

| 风险 | 缓解 |
|---|---|
| AI 不读节点 manifest 只读 SKILL.md | SKILL.md 明确声明"必读节点 manifest"，且 manifest 用自然语言写让 AI 真愿意读 |
| 强约束变机械约束（codex 五轮指出的盲点）| 决策 4 的"命中判定" / 决策 3 的"退出原则" / 决策 1 的"三档样例" |
| Console 业务代码与新 plugin 行为冲突 | 决策 6 + 现 Console 业务代码冻结（不删但停止扩张） |
| AI 在 anchor 里实际不会主动调用 sc 指令 | 决策 5 的"必须显式声明替代方式"作为软约束；后续如发现严重不调用问题，再考虑 hook 兜底 |

## 关联

- ADR-0023 plugin sovereignty 主决策
- ADR-0023 Addendum 节点≠流水线工序
- ADR-0024（待起草）plugin-side primitive runtime
- ADR-0028 两层实体
- ADR-0029 大状态指令层
- 共识备忘录 `docs/.ccb/decisions/2026-05-20-plugin-skill-redesign-consensus.md`
- 产品语义样张 v2.1 `docs/02_需求设计/ccb-plugin/2026-05-20-plugin-product-semantics-sample-v2.md`
- 实施 SP：SP-A11
