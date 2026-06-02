---
id: td-6d5e9b-doc-template-alignment
title: 需求文档 C 方案与文档模板对齐 技术设计
doc_type: technical_design
requirement_id: cmpr12lsa60ac902be46d5e9b
updated: 2026-05-30
---

# 需求文档 C 方案与文档模板对齐 技术设计

> 一句话：让 AI 解析产出的需求文档按模板模块组织（C 两层并存），并把 technical_design / dev_task 纳入模板对齐治理 ｜ 最后更新: 2026-05-30
>
> **无独立 status** —— 跟随 `requirement_id` 指向的需求。

---

## 一、设计概述

| 项 | 说明 |
|----|------|
| 名称 | 需求文档 C 两层并存 + 文档模板对齐 |
| 核心职责 | **线 A**：需求文档主体按模板 13 章人读 + 文末保留 3 投影锚点；**线 B**：technical_design / dev_task 模板对齐治理 |
| 设计原则 | 投影链零改动（parser / hash 语义不变）；锚点 = 投影摘要、主体 = 人读全文；后向兼容（`bodyMarkdown` 可选）；非阻断校验（不污染 `parseStatus`） |
| 需求来源 | `docs/02_需求设计/需求详情内的产物内容优化-6d5e9b-需求.md` |
| 覆盖范围 | 需求文档生成（`applyAnalysis` + Console renderer）、需求模板、su-flow / reanalyze skill、dev_task 生成链路、Console 非阻断 conformance |
| 不覆盖 | 存量旧 5 段需求文档迁移（用户拍板不强迁）；改 parser 投影解析逻辑；改 DB 投影字段 schema |

---

## 二、方案与架构

### C 两层并存的需求文档结构

```
[frontmatter: id/title/doc_type/status/created/analysis_input_hash/analysis_applied_at]
# <标题> 需求设计
## 需求描述            ← parser 锚点(description)         ┐ 输入区(保留)
## 原话（verbatim）    ← parser 锚点(verbatimSource)      ┘
———————— AI 生成人读主体(按模板 二~十三 章, 复杂度自适应) ————————
## 二、背景与目标
## 三、讨论与决策
## 四、功能 / 范围
## 五、业务规则  …  ## 十三、风险      (用不上的章节删掉)
———————— Console 投影锚点(= 主体摘要) ————————
## Claude 解读         ← parser 锚点(claudeInterpretation) ┐
## 歧义点              ← parser 锚点(ambiguities)          ┼ 投影区(AI 接管)
## 保真差异            ← parser 锚点(fidelityDiff)         ┘
```

| 关键原则 | 说明 |
|----------|------|
| 投影链零改动 | parser `find()` 精确标题且不管位置 → 文末 3 锚点照常提取、开头 2 锚点保留 |
| 锚点 = 摘要 | 文末 3 锚点是主体的投影摘要（Console 卡片/详情用）；主体是完整人读文档 |
| 后向兼容 | `bodyMarkdown` 为**可选**字段，缺失时退化为旧 3 锚点路径，旧文档/旧调用不受影响 |

**与现有系统的关系 / 边界**：

| 涉及模块 | 本设计如何动它 | 保留 / 不动什么 |
|----------|----------------|------------------|
| `lib/requirement-analysis`（applyAnalysis） | 扩展：支持 `bodyMarkdown`、锚点 sanitize、主体区幂等 | 三锚点写入、CAS/journal、`analysisInputHash` 语义不动 |
| `document-parser`（parseRequirementSections） | **不动** | 5 锚点精确解析逻辑全保留 |
| Console renderer（project-indexer 729-757） | 改：输出 C 形态 | DB 投影字段不变 |
| 需求模板 `_模板_需求.md` | 改：本身长成 C 形态 | — |
| dev_task 生成链路（materialize/breakdown） | 改：`spec_section_md` 模板约束 | dev_task frontmatter 状态机不动 |
| technical_design（纯手写） | 加：写作规范 + 非阻断 lint | — |

---

## 三、关键决策与取舍

- **C 两层并存（用户 2026-05-30 拍板）**：主体满足模板、文末锚点保投影；以「锚点 = 摘要、主体 = 全文」约束漂移。否决 A（模块非顶层）、B（爆炸半径最大、parser 须双向兼容）、第四（schema/迁移成本高）。
- **applyAnalysis = A1（`bodyMarkdown` 可选字段）**：选 A1 因模板复杂度自适应（用不上的章节删）；`validateAnalysis` 当前不拒额外字段，可后向兼容扩展。否决 A2（每章结构化字段会固化模板，演进成本高）。
- **parser / hash 语义不变**：parser 零改动；`analysisInputHash` 仍 = `sha256(title + 需求描述)`，**`bodyMarkdown` 不纳入**——否则 indexer/reanalyze 的 stale 判断语义被破坏。
- **锚点 sanitize（防污染）**：`bodyMarkdown` 禁止出现 5 个保留 heading（`需求描述/原话（verbatim）/Claude 解读/歧义点/保真差异`），生成期校验拒绝；否则「首个 wins」污染投影。
- **AI 主体区所有权 = O2（✅ 用户 2026-05-30 拍板）**：用户声明「文档全 AI 驱动、人不手改、完全以 AI 产出为准」→ 主体区每次整段重写，无需保护用户编辑。见下表。
- **Console renderer 同步**：新建需求 renderer 也输出 C 形态，否则 Console 入口建的需求仍是 5 段。
- **线 B 分治**：technical_design 纯手写 → 写作规范 + 非阻断 lint；dev_task 经 `materializeRequirement` 从 `spec_section_md` 生成 → 模板对齐在**生成链路**（非写作规范）。
- **conformance 独立**：`template_conformance` 用独立字段 / 独立 sync warning，**不塞 `parseIssues`/`parseStatus`**——否则 dev_task/design 投影（只吃 `parseStatus===success`）会被整份跳过。

### AI 主体区所有权（✅ 已定 · 用户 2026-05-30 拍板）

**定为 O2 always-overwrite**：用户声明「文档全 AI 驱动、人不手改、完全以 AI 产出为准」→ 无保护用户编辑的需求，主体区每次整段重写。

| 选项 | 行为 | 结论 |
|---|---|---|
| **✅ O2 always-overwrite（已选）** | 每次重写主体 + 锚点，以 AI 产出为准 | 用户不手改 → 最简、无漂移 |
| O1 seed-once | 仅首次生成、之后归用户 | 未选：用户不手改，无需保护 |
| O3 managed-marker | marker 包裹 AI 区 | 未选：marker 噪音无收益 |

> 实现要点：O2 仍需用**隐式边界**（`原话` section 之后 ~ `Claude 解读` section 之前）定位并**整段替换**主体区，避免二次解析重复插入；无需可见 marker。

---

## 四、核心流程 / 逻辑

```
applyAnalysis(C 改造):
  读 md → 解析输入(3 锚点字段 + 可选 bodyMarkdown)
    → sanitize: bodyMarkdown 含保留 heading? → 是: 拒绝(ValidationError)
    → 重写主体区(整段替换: 「原话」section 后 ~ 「Claude 解读」section 前为隐式边界)
    → replaceSection 写 3 锚点(原逻辑)
    → 更新 frontmatter(analysis_input_hash = title+需求描述, 不含 body)
    → safeWriteFile(CAS, expectedHash=beforeHash) + appendEvent(journal)
```

| 处理规则 | 说明 |
|----------|------|
| 幂等 | O2：用隐式边界(原话后 / Claude 解读前)定位并整段替换主体区，重跑不重复插入；以 AI 产出为准 |
| 锚点禁用 | `bodyMarkdown` 出现 5 保留 heading 之一即拒绝，防投影污染 |
| 后向兼容 | 无 `bodyMarkdown` → 走旧 3 锚点路径，结果与现状一致 |
| hash 稳定 | body 变化不改 `analysisInputHash`，stale 判断只看 title+需求描述 |

---

## 五、测试策略

- [ ] 单元：`applyAnalysis`（含/不含 `bodyMarkdown`、含非法保留锚点拒绝、重跑幂等）、sanitize、hash 不随 body 变
- [ ] 集成：`parseRequirementSections` 对 C 文档提取 5 锚点正确；Console renderer 输出 C 形态
- [ ] 端到端：su-flow 分析产出 C 文档 → Console 投影正确；reanalyze 重跑按所有权策略生效
- [ ] 回归：旧 5 段文档投影**不变**（不强迁验证）；dev_task/design 投影不被 conformance warning 跳过

---

## 八、文件结构 / 变更清单

- `[MODIFY] su-ccb-claude-plugin/lib/requirement-analysis/index.mjs`：`applyAnalysis` 支持 `bodyMarkdown` + sanitize + 主体区幂等；`validateAnalysis` 显式接受可选字段
- `[MODIFY] su-ccb-claude-plugin/templates/docs/02_需求设计/_模板_需求.md`：改 C 形态（开头 2 锚点 + 模板模块 + 文末 3 锚点）
- `[MODIFY] su-ccb-claude-plugin/skills/su-flow/SKILL.md`、`skills/requirement-reanalyze/SKILL.md`：artifact 契约要求产出 `bodyMarkdown`
- `[MODIFY] apps/ccb-console/server/src/indexer/project-indexer.ts`（renderer 729-757）：输出 C 形态
- `[MODIFY] technical_design / task_breakdown 节点 manifest/SKILL`：写作按模板规范
- `[MODIFY] su-ccb-claude-plugin/lib/subtask/index.mjs + breakdown`：`spec_section_md` 模板约束（dev_task 生成链路）
- `[NEW] Console 非阻断 template_conformance 校验`：独立字段，不接入 `parseStatus`

---

## 十、迁移影响与风险

- **受影响**：需求文档生成全链路（plugin lib + Console renderer + 模板 + skill）+ 两类下游文档治理
- **打法**：按 Codex 推荐顺序分批 —— ① lib（bodyMarkdown/sanitize/幂等，保三字段+hash 兼容）→ ② 模板/skill（C 形态 + 要求产出 bodyMarkdown）→ ③ dev_task 生成链路 → ④ Console 非阻断 conformance；`bodyMarkdown` 可选保后向兼容
- **回滚 / 恢复**：lib / 模板改动 `git revert`；parser / hash / DB 投影字段全程不动 → 投影侧零风险

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| `bodyMarkdown` 含同名 `##` 锚点污染投影 | 中 | 高 | 生成期 sanitize 拒绝 |
| 主体区整段替换时重复插入 | 低 | 中 | 隐式边界(原话后 / Claude 解读前)定位替换；用户不手改 → 无误删风险 |
| 模板 warning 接入 `parseStatus` → 投影被跳过 | 低 | 高 | 独立 `template_conformance` 字段 |
| 主体与锚点漂移（C 固有冗余） | 低 | 低 | O2 每次同源重写主体 + 锚点，二者天然一致 |

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-05-30 | v1.0 | 初版，基于 slot1_codex 设计协商（job_924ab6efba5a） |
| 2026-05-30 | v1.1 | 主体区所有权拍板 O2（全 AI 驱动、人不改文档、以 AI 产出为准） |
