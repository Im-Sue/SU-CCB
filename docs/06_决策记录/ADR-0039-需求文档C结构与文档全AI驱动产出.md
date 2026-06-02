---
id: ADR-0039
title: 需求文档采用 C 两层并存结构，文档全 AI 驱动以产出为准
doc_type: adr
status: accepted
supersedes: []
superseded_by:
date: 2026-05-30
---

# ADR-0039: 需求文档采用 C 两层并存结构，文档全 AI 驱动以产出为准

> 一个决策一篇，记下"为什么这么定"。
>
> **状态**: accepted ｜ **拍板人**: 用户 · 2026-05-30

---

## 一、背景

需求「需求详情内的产物内容优化」（`cmpr12lsa…6d5e9b`）发现：AI 解析（requirement_analysis 节点）产出的需求文档恒为固定 5 段（需求描述 / 原话 / Claude 解读 / 歧义点 / 保真差异），不按 `_模板_需求.md` 的 13 章模块组织。

根因（源码核验）：`lib/requirement-analysis/index.mjs` 的 `applyAnalysis()` 写死只产出 3 个分析 section——非"规则没限制模板"。张力在于：这 3 段同时是 Console 投影硬契约——`document-parser.ts` 的 `parseRequirementSections()` 按精确 heading 提取 5 个 section 投影到 DB / Web 详情页，改结构会断投影链。

经 slot1_codex 两轮协商核验（job_2deef2dc7289 需求分析、job_924ab6efba5a 技术设计）。

---

## 二、决策

1. **需求文档采用 C 两层并存结构**：主体按 `_模板_需求.md` 模块（背景目标 / 功能 / 规则…）人读，文末保留 `## Claude 解读 / ## 歧义点 / ## 保真差异` 三锚点供 Console 投影，开头保留 `## 需求描述 / ## 原话（verbatim）`。锚点 = 投影摘要，主体 = 人读全文。
2. **parser / 投影契约不变**：`parseRequirementSections` 与 `analysisInputHash`（= `title + 需求描述`）语义零改动；`applyAnalysis` 加**可选** `bodyMarkdown` 字段产出模板主体，后向兼容旧三字段路径。
3. **人读文档全 AI 驱动、以 AI 产出为准**：本项目 `docs/` 人读文档由 AI 生成、人不手动编辑；故需求文档主体区采用 **always-overwrite**（每次重分析整段重写，以隐式边界「原话后 ~ Claude 解读前」定位），不引入保护用户手改的机制。
4. **澄清 `docs-structure-contract`**：`field_editability.free_edit`（背景目标 / 设计正文等"人随便改"）在本项目实践中**不触发**——文档以 AI 产出为准；该字段仅表理论可改性，不作为设计约束（凡"是否保护用户手改"取舍默认无需保护）。
5. **文档模板对齐范围**：本需求一并纳入 technical_design（写作规范 + 非阻断 lint）与 dev_task（生成链路 `spec_section_md` 约束）的模板对齐；Console `template_conformance` 用独立字段，**不**污染 `parseStatus`（否则投影被整份跳过）。

---

## 三、否决的方案

| 方案 | 为什么没选 |
|------|------------|
| A 模板降为「Claude 解读」子结构 | 模块非顶层，不满足"按模板模块"字面诉求 |
| B 投影向模板靠拢（改 parser 多章节聚合） | 爆炸半径最大（8+ 处），parser 须双向兼容旧 5 段，回归面广 |
| 第四：独立 structuredAnalysis / sidecar 投影字段 | schema / API / 迁移成本高，本轮过重（留长期演进） |
| 主体区 O1 seed-once / O3 managed-marker | 用户明确文档不手改 → 保护机制无收益，徒增复杂度 |

---

## 四、影响

- **好处**：满足"按模板模块产出"人读诉求；投影链零改动、零回归风险；O2 实现最简、主体与锚点同源无漂移。
- **代价 / 风险**：C 固有的主体↔锚点信息冗余（O2 同源重写缓解）；`bodyMarkdown` 须 sanitize 禁含 5 个保留锚点名，防「首个 wins」污染投影。
- **受影响**：`applyAnalysis`、需求模板、su-flow / reanalyze skill、Console renderer、dev_task 生成链路、Console conformance 校验。存量旧 5 段需求文档**不强制迁移**。

---

## 五、关联

| 关系 | 对象 |
|------|------|
| 相关决策 | ADR-0037（文档驱动架构-真相源上移人读文档） |
| 相关文档 | 需求 `docs/02_需求设计/需求详情内的产物内容优化-6d5e9b-需求.md`；技术设计 `docs/03_开发计划/需求文档C方案与文档模板对齐-6d5e9b-技术设计.md` |

---

## 六、决策依据

- slot1_codex 需求分析协商 `job_2deef2dc7289`：核验根因 + 投影爆炸半径依赖链。
- slot1_codex 技术设计协商 `job_924ab6efba5a`：核验 parser 零改动成立、`applyAnalysis` A1 选型、纠正 dev_task 经 `materializeRequirement` 生成（非纯手写）、警告 template warning 不可接入 `parseStatus`。
- 用户 2026-05-30 拍板：归一方向 C、不迁旧档、其他文档本轮纳入、主体区 O2（文档全 AI 驱动、以产出为准）。
