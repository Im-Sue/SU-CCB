---
doc_type: dev_task
task_id: subtask-c4dc86b6fa21
title: applyAnalysis 支持 bodyMarkdown + 需求模板 C 形态 + skill 契约
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpr12lsa60ac902be46d5e9b
section_id: pr1-requirement-c-plugin
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpr12lsa60ac902be46d5e9b.json
source_draft_hash: 30c8d5e6f94d523f271eea5b66aac95406fdc8ec75b7719e677d66ddf8675ded
created_at: 2026-05-30T07:49:00.223Z
updated_at: 2026-05-30T08:11:33.970Z
updated_by: ai_session
---

# applyAnalysis 支持 bodyMarkdown + 需求模板 C 形态 + skill 契约

## 目标

让 su-flow / reanalyze 的 AI 解析产出 **C 两层并存**需求文档（开头 2 锚点 + 模板 13 章主体 + 文末 3 投影锚点），plugin 侧落地，投影链零改动。依据《技术设计》`docs/03_开发计划/需求文档C方案与文档模板对齐-6d5e9b-技术设计.md`、`ADR-0039`。

## 范围（plugin 侧，含测试）

- `[MODIFY] su-ccb-claude-plugin/lib/requirement-analysis/index.mjs`：
  - `applyAnalysis` 接受**可选** `bodyMarkdown`：写到「原话（verbatim）」section 之后、「Claude 解读」section 之前；缺失则跳过（退化为旧 3 锚点路径）。
  - **主体区整段替换（O2）**：用隐式边界（原话 section 后 ~ Claude 解读 section 前）定位并整段重写，二次运行不重复插入。
  - **锚点 sanitize**：`bodyMarkdown` 含 parser 识别的任一锚点二级标题即抛 `ValidationError` —— sanitize 须覆盖全部变体:`需求描述 / 原话（verbatim）/ 原话 / verbatim / Claude 解读 / Claude 解读（可选）/ 歧义点 / 歧义点（可选）/ 保真差异 / 保真差异（可选）`。
  - `validateAnalysis` 接受可选 `bodyMarkdown`（非字符串 / 含保留锚点才报错）；三字段仍必填。
  - `analysisInputHash` 维持 `sha256(title + 需求描述)`，**不纳入** `bodyMarkdown`。
- `[MODIFY] su-ccb-claude-plugin/templates/docs/02_需求设计/_模板_需求.md`：改 C 形态——开头 `## 需求描述` + `## 原话（verbatim）`；中间模板模块（二~十三，序号名，复杂度自适应）；文末 `## Claude 解读` + `## 歧义点` + `## 保真差异`。
- `[MODIFY] su-ccb-claude-plugin/skills/su-flow/SKILL.md` + `skills/requirement-reanalyze/SKILL.md`：artifact 契约补充——分析产物可带 `bodyMarkdown`（按需求模板主体），并说明 sanitize 约束与 O2 整段替换语义。

## 验收

- 提供 `bodyMarkdown`：产出文档 = 开头 2 锚点 + 模板主体 + 文末 3 锚点；`parseRequirementSections` 提取 5 字段全部正确（投影不变）。
- 不提供 `bodyMarkdown`：产出与现状一致（旧 3 锚点路径，后向兼容）。
- `bodyMarkdown` 含保留锚点名 → `ValidationError` 拒绝。
- 重跑（再次 applyAnalysis）整段替换主体、不重复插入。
- `analysisInputHash` 不随 `bodyMarkdown` 改变。
- 单测覆盖上述分支；现有 requirement-analysis 测试全绿。

## 边界

不改 `parseRequirementSections`；不改 hash 语义；不改 DB schema；不引依赖。

## 依赖

无（先读技术设计 + ADR-0039）。

## Materialization Context

- Requirement: cmpr12lsa60ac902be46d5e9b
- Section: pr1-requirement-c-plugin
- Owner: ccb_codex
- Priority: high
- Dependencies: none

## 审查结论（2026-05-30 · Claude autonomous-batch review）

**通过**。Codex 实施(job_04d07b956a40)+ Claude 自验:

- 范围:实际改动 5 文件均在 spec 内(applyAnalysis / 测试 / 需求模板 / su-flow + reanalyze SKILL);submodule 另两处投影收敛改动为预存、与本片无关。
- 测试:requirement-analysis 单测 5/5 自跑通过(bodyMarkdown 写入 / 缺省退化 / 保留锚点拒绝 / 重跑幂等 / hash 不变)。
- 硬约束:parseRequirementSections、analysisInputHash 语义(= title + 需求描述)、DB schema、依赖 均未改(已核验)。
- C 形态:模板开头 `## 需求描述` + `## 原话（verbatim）` → 二~十三章模块 → 文末 `## Claude 解读` / `## 歧义点` / `## 保真差异`,parser 5 锚点齐全。
- sanitize 覆盖 10 个 parser 变体;主体区 O2 整段替换(原话后 ~ Claude 解读前);后向兼容(无 bodyMarkdown 退旧路径)。
