---
doc_type: dev_task
task_id: subtask-2c399dd77c80
title: 3 份模板补强 + applyRequirementAnalysis 写 expression_spec 标记
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq3feiumac1ad394d74d8dbf
section_id: pr2-template-lib-mark
order: 2
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3feiumac1ad394d74d8dbf.json
source_draft_hash: ff7eb04d84c3a93a67878264b1f45843bf7dbf090332a2ab398e89f98f92ba3d
created_at: 2026-06-07T10:11:21.276Z
updated_at: 2026-06-07T11:06:00.000Z
updated_by: slot1_claude
code_workspace: {"path":"../SU-CCB-req-cmq3feiumac1ad394d74d8dbf","branch":"ccb/req-cmq3feiumac1ad394d74d8dbf"}
---

# 3 份模板补强 + applyRequirementAnalysis 写 expression_spec 标记

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | _模板_需求/_模板_技术设计/_模板_开发任务补目标对齐+模拟示例占位块；lib/requirement-analysis 落档时附写 expression_spec: v1（rollout gate 标记源头）；单测+scaffold 幂等测试。plugin 仓。 |
| 需求来源 | cmq3feiumac1ad394d74d8dbf |
| 本期范围 | pr2-template-lib-mark · 3 份模板补强 + applyRequirementAnalysis 写 expression_spec 标记 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述

把规范要求变成模板里现成的占位块——打开模板就看到「先写目标对齐」「复杂的配示例」；同时让需求分析落档自动盖 expression_spec: v1 标记（pr3 巡检靠它区分新旧文档，存量零打扰的源头机制）。仓库：su-ccb-claude-plugin。技术设计八章 PR2 清单。

#### 任务分解

1. [MODIFY] templates/docs/02_需求设计/_模板_需求.md：「二、背景与目标」内增目标对齐+模拟示例占位块（粗体块，不加 ## 级新标题——不破坏 13 章标题集对齐）。
2. [MODIFY] templates/docs/03_开发计划/_模板_技术设计.md：「一、设计概述」表格前增目标对齐叙事块（极小设计允许一行白话的自适应下限说明）；「四、核心流程」指引补端到端示例；frontmatter 示例加 expression_spec: v1。
3. [MODIFY] templates/docs/03_开发计划/_模板_开发任务.md：「一、任务概述」表上方补白话概述占位（轻改，最低优先级，不做大重构）。
4. [MODIFY] lib/requirement-analysis/index.mjs：applyRequirementAnalysis 写 frontmatter 时附加 expression_spec: v1（与 analysis_input_hash 同路径同模式写入）。
5. 测试：applyRequirementAnalysis 单测（新分析带标记/同输入重放幂等/不触碰未重分析旧文档）；su-init scaffold 测试（新模板块随 copyIfMissing 分发、幂等）。

#### 验收标准

- [ ] 3 模板含新占位块；占位措辞字面与设计文档四章固化标记一致（「目标对齐」「模拟示例」「无需示例」）；pr1 已合入时与 document-expression-spec.md R1/R2 用词 grep 对照一致（并行期以设计四章为契约）
- [ ] applyRequirementAnalysis 单测 3 场景通过；plugin 既有测试零回归
- [ ] scaffold/copyIfMissing 测试通过
- [ ] 不改模板文件名与章节标题集；不动 bodyMarkdown 校验逻辑与 5 锚点替换语义

#### 边界（不做项）

- 不动保留标题集（需求描述/原话/Claude 解读/歧义点/保真差异）；lib 只加 frontmatter 字段，不改任何校验/替换语义；不改 su-init 分发逻辑本身（仅补测试覆盖新块）。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-07 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmq3feiumac1ad394d74d8dbf
- Section: pr2-template-lib-mark
- Owner: ccb_codex
- Priority: high
- Dependencies: none
