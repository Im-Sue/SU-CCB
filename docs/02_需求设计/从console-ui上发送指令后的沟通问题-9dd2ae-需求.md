---
id: cmpzb7fxf8d099992749dd2ae
title: 从console UI上发送指令后的沟通问题
doc_type: requirement
status: delivered
created: 2026-06-04T09:45:07.683Z
analysis_input_hash: f194a34742c2e4facfedac6d03771048e7a5b20d88275a4370636a29a2239e41
analysis_applied_at: 2026-06-04T10:03:01.542Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

从console UI上发送指令后，claude code的回复全是英文，这似乎偏离了预期，尽管claude.md和ui的发送指令带上了中文参数，claude code的回复依然是英文。深度分析plugin和skills和claude.md机制思考一下如何优化这个问题

## 原话（verbatim）

从console UI上发送指令后，claude code的回复全是英文，这似乎偏离了预期，尽管claude.md和ui的发送指令带上了中文参数，claude code的回复依然是英文。深度分析plugin和skills和claude.md机制思考一下如何优化这个问题

## 二、背景与目标

**背景**：CCB 以 Console UI 派发指令给 Claude / Codex agent。用户期望 Claude 回复中文，并已通过两处「中文信号」表达——项目 CLAUDE.md「永远中文回答」、UI 发指令携带 `language:"中文"` 参数——但 Claude 回复仍频繁为英文。

**目标**：让 Console 触发的 Claude agent，其**面向用户的自然语言回复**稳定默认中文，且不误伤代码 / 标识符 / 工具输出等技术内容。

## 三、讨论与决策

### Codex 协商摘要（job_955610f07cb2，1 轮 consult）

Codex 独立核验并质疑了 framing，关键贡献：

- 确认 `language` 死字段，补充 `dispatch-parser:58` / `anchor-dispatch.schema.yaml:21` / `su-flow:52` 三处证据。
- **反对「只盯 su-flow」**：su-init / resume / cancel / defer / archive 等入口根本不注入 language，靠 skill 读 payload 覆盖不全。
- **暴露关键盲点**：ccbd wrapper 已有 `CCB_REPLY_LANG` / `CCB_LANG` 机制（`prompt.py:52`），每轮注入「Reply in Chinese.」，但当前环境未设置。
- **修正**「CLAUDE.md 已加载」为「CCB 物化 memory bundle，可能 skip / fail」（`home.py:254`）。
- 推荐 D（近请求注入 + skill 消费 + CLAUDE.md 兜底），提示实现要先定验收策略、勿把自然语言直接拼在 payload 后破坏 parser。

### Claude 4 锚点反思

- **我同意的**：① `language` 是死字段（已加三处证据）；② 范围不能只盯 su-flow（已核验多入口不注入 language）；③ 最该用的是 `CCB_REPLY_LANG`，已核验存在且实测未设置。
- **我保留 / 不同意的**：根因的「用户视角最小解」是「最强的层没开」，technical_design 应**优先评估「打开既有开关」的最小修**，而非先做三层契约大重构——范围广 ≠ 改动大。
- **我的盲点**：① 错把「CLAUDE.md 已加载」说死，实为有条件物化；② 差点从零发明注入，忽略了既有 `CCB_REPLY_LANG`；③ 忽略 `exports.py:52` 的 env 导出边界，设 env 的位置需验证。
- **接下来**：锁验收 / 范围 → 落 spec → 进入 technical_design（Codex hint: sc-design）评估最小稳健组合与 env 注入归属。

## 四、功能 / 范围

**范围内**：

1. **打开第 3 层**：为 Console 管理的 Claude agent 启用 `CCB_REPLY_LANG=zh`（最抗漂移、入口无关、立竿见影）。
2. **修复第 1 层**：让 plugin skill 在 `/ccb:*` 入口显式消费 `payload.language` 并重申回复语言（纵深防御）。
3. **保留第 2 层**：CLAUDE.md「永远中文回答」作为兜底，并校准其物化可靠性表述。

**范围外**：codex provider agent 的语言一致性；非 Console 触发的手工 `ccb ask`；多语言泛化（当前只锁中文，但实现应沿用 `CCB_REPLY_LANG` 既有 en/zh 切换能力，不写死「中文」）。

## 五、业务规则（语言策略）

1. **默认中文**：面向用户的自然语言结论、解释、摘要、追问。
2. **保留英文**：代码、命令、路径、标识符、API 名、commit message、工具 / 日志原始输出、被引用的英文原文。
3. **机制可切换**：经 `CCB_REPLY_LANG`（zh / en）控制，不在代码里写死「中文」。

## 六、边界 / 不做项

1. 不强制「100% 全中文」（会误伤代码与日志）。
2. 不直接把自然语言指令拼接在 `/ccb:* --payload <json>` 之后（破坏 parser）。
3. 本需求不改数据 schema、不引依赖、不动 codex agent 行为。
4. ccbd wrapper（仓外 `~/.local/share/codex-dual/`）若需改动，归属与可行性在 technical_design 拍板，本需求不预设改源码。

## 七、开放问题 / 假设

- **假设**：需求只要求 Claude 面向用户回复默认中文，技术内容允许英文（待用户确认验收档）。
- **开放（留 technical_design）**：`CCB_REPLY_LANG` 应设在哪一层（Console managed-config 生成的 agent env / ccbd 启动 env）才能被 `prompt.py` 读到，受 `exports.py:52` 导出边界约束；是否需要让 Console 各派发入口统一携带语言意图。

## 八、拆分预览（指向技术设计）

预计三个小修复点，分层独立、可增量交付：

1. **Console / ccbd**：为 Claude agent 启用 `CCB_REPLY_LANG=zh`（核心、立竿见影）。
2. **plugin**：skill 入口消费 `payload.language` 重申语言（纵深）。
3. **docs**：校准 CLAUDE.md 语言规则表述（兜底）。

具体边界与归属由 technical_design 细化。

## 十三、风险

1. **env 注入位置失效**：`CCB_REPLY_LANG` 设错层级，`prompt.py` 读不到 → 需设计阶段验证。
2. **跨仓边界**：第 3 层在本仓外，改动归属需明确，避免越界改 ccbd 源码。
3. **过度中文化**：策略若不区分技术内容，会误伤代码 / 日志 / 标识符 → 由业务规则第 2 条约束。
4. **覆盖不全**：若只修 su-flow 路径，漏掉其它 Console 入口 → 故首选 env 级方案。

## Claude 解读

用户报告的现象——「Console UI 发指令后 Claude 回复全是英文」——根因不是单点 bug，而是**语言控制有三层，最强的一层没开、用户以为在用的一层是假的、剩下一层太弱且有条件**：

- **第 1 层 · payload `language:"中文"`（Console 注入）= 死契约**。仅 su-flow 派发路径在 `su-oriel/.../structured-dispatch.ts:18` 注入，且全 plugin 无任何消费（`dispatch-parser/index.mjs:58`、`anchor-dispatch.schema.yaml:21` 只把 payload 当业务对象；`su-flow/SKILL.md:52` 只说 payload 用于定位主体/意图）。其它入口（su-init/resume/cancel/defer/archive）连这个字段都不注入。→ 这正是用户以为「我带了中文参数」的那一层，实际零行为。
- **第 2 层 · 项目 CLAUDE.md「永远中文回答」= 弱且有条件的兜底**。它不是被原生读取，而是 CCB 物化的 managed memory bundle（`home.py:_materialize_claude_memory`）；inherit 关闭会 skip、缺项目上下文会 fail。即便成功物化，一行指令也压不过 Claude Code 英文主导的 harness（英文系统提示、英文工具 schema、大量英文工具结果），长上下文里易漂移回英文。
- **第 3 层 · ccbd prompt wrapper 的 `CCB_REPLY_LANG`/`CCB_LANG`（`prompt.py:_language_hint`）= 专门为此设计、最抗漂移、却当前未启用**。它每轮把 `Reply in Chinese.` 注入提示词（近请求、与入口无关）。实测当前环境 `CCB_REPLY_LANG`/`CCB_LANG` 为空 → 最强的开关没打开。

所以「优化」的核心不是发明新机制，而是：**打开第 3 层（最强、最该用）+ 让第 1 层从死契约变真消费（纵深防御）+ 保留第 2 层 CLAUDE.md 兜底并校准其物化可靠性**。这对应 Codex 推荐的 D 方案，关键修正是「第 3 层已存在，只需接通」——范围虽广，但改动可以很小。
## 歧义点

**原文模糊点与已澄清决定（决策者兜底，非 TBD）**：

1. 「回复全是英文」的「回复」边界 → **决定（默认）**：仅指 Claude **面向用户的自然语言结论/摘要/追问**；代码、路径、标识符、API 名、commit message、工具原始输出保留英文（强制全中文会误伤代码与日志，与 Codex 判断及常识一致）。
2. 入口范围「Console UI 发送指令」 → **决定（默认）**：锁定 **Console 触发 → Claude provider 的面向用户回复**；以 env 级 `CCB_REPLY_LANG` 实现，天然覆盖所有 Console 入口（含未注入 language 的 su-init/resume/cancel/defer/archive）。
3. 「优化」的程度 → **决定**：先评估「打开既有 `CCB_REPLY_LANG` + 接通 payload.language + CLAUDE.md 兜底」的最小稳健组合，不先做三层契约大重构。

**必问 12 类扫描（只列命中 + 关键不命中）**：

- **命中 · 产品方向/用户权利**：① 验收档位（全中文 vs 默认中文+技术英文）——已按「默认中文+技术英文」定，**请用户确认或改为全中文**；② 范围是否含 codex provider agent——**默认不含**（本需求只解决 Claude 回复），如需把语言一致性扩到 codex 应另立需求。
- **命中 · 工程边界**：第 3 层 ccbd wrapper 在本仓外（`~/.local/share/codex-dual/`）；`CCB_REPLY_LANG` 设在何处才能被 `prompt.py` 读到，受 `exports.py:52` 的 env 导出边界影响——留 technical_design 验证归属，本需求不预设改 ccbd 源码。
- **不命中**：隐私 / 合规 / 成本 / 不可逆动作 / schema 变更 / 新依赖——本需求是提示词与运行时配置层的语言一致性，不引依赖、不改数据 schema、完全可逆。已逐项确认不存在，故不问。
## 保真差异

- **无范围收窄**。用户要求「深度分析 plugin/skills/claude.md 机制并优化」，已全部覆盖，未用旧分析或假设收窄。
- **一处忠实扩展**：用户点名三处（plugin / skills / claude.md），但分析发现真正决定回复语言的是**第四处——ccbd prompt wrapper 的 `CCB_REPLY_LANG`**（`prompt.py:_language_hint`）。用户原文未提及，却是最关键的优化点。已纳入分析并明确标注为「原文之外的发现」，未改变用户原意，只补齐了机制全貌。
- **一处精度修正**：初始 framing 说「CLAUDE.md 已加载」，经核验应表述为「CCB 物化 memory bundle，可能 skip/fail」（`home.py:_materialize_claude_memory`）——更精确，不影响结论方向。
- **现象表述校准**：用户原话「全是英文」，实测为「不稳定地漂移回英文」（同配置下本会话即用中文回答）。这不弱化问题，反而指向「需要每轮重申的强机制」而非「修一个确定性 bug」。
