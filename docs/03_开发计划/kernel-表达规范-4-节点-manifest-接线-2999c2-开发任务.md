---
doc_type: dev_task
task_id: subtask-79edea2999c2
title: kernel 表达规范 + 4 节点 manifest 接线
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq3feiumac1ad394d74d8dbf
section_id: pr1-expression-spec-wiring
order: 1
implementation_owner: claude
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3feiumac1ad394d74d8dbf.json
source_draft_hash: ff7eb04d84c3a93a67878264b1f45843bf7dbf090332a2ab398e89f98f92ba3d
created_at: 2026-06-07T10:11:21.276Z
updated_at: 2026-06-07T10:34:00.000Z
updated_by: slot1_claude
code_workspace: {"path":"../SU-CCB-req-cmq3feiumac1ad394d74d8dbf","branch":"ccb/req-cmq3feiumac1ad394d74d8dbf"}
---

# kernel 表达规范 + 4 节点 manifest 接线

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 新增 references/kernel/document-expression-spec.md（R1-R6+doc_type 应用矩阵+豁免语义+before/after 微例）；4 个 node manifest（requirement_analysis/technical_design/task_breakdown/review）接线落档前消费要求；README 索引。纯 markdown，plugin 仓。 |
| 需求来源 | cmq3feiumac1ad394d74d8dbf |
| 本期范围 | pr1-expression-spec-wiring · kernel 表达规范 + 4 节点 manifest 接线 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | claude |

## 二、任务分解

#### 任务概述

写一份「AI 怎么写文档」的规范并接进 4 个节点说明书。这是整个需求的真相源：规范定下的规则（目标对齐、示例、图表优先、术语解释），模板（pr2）和巡检（pr3）都向它对齐。仓库：su-ccb-claude-plugin，纯 markdown 零代码。技术设计：docs/03_开发计划/文档可读性-落档表达规范与写路径接线-4d8dbf-技术设计.md（八章 PR1 清单）。

#### 任务分解

1. [NEW] references/kernel/document-expression-spec.md（~150 行）：R1-R6 规则（编号与需求文档五章一致：目标对齐先行/示例复杂度自适应/场景→图型映射/术语首现白话解释/受众分层/图形语言 ASCII+GFM 表格）；doc_type 应用矩阵（requirement/technical_design/dev_task 各适用哪些规则、落在哪章）；豁免语义（「无需示例，因为…」「无需图，因为…」= 合法满足，审查看理由实质）；d21ff1 开篇 before/after 微例（素材在需求文档二章）。规范自身 dogfood：白话+表格+ASCII，不写成长文。
2. [MODIFY] references/kernel/nodes/requirement_analysis.node.md：②核心要点增「bodyMarkdown 按 _模板_需求.md 主体章节组织 + 遵守 document-expression-spec」；③完成条件、自检清单各加对应项。
3. [MODIFY] references/kernel/nodes/technical_design.node.md：②.9 补表达规范引用 + 首屏目标对齐 + 端到端示例要求。
4. [MODIFY] references/kernel/nodes/task_breakdown.node.md：spec_section_md 遵守表达规范（一行）。
5. [MODIFY] references/kernel/nodes/review.node.md：checklist 增 3 项（目标对齐能秒懂吗/示例有或豁免合理吗/黑话首现解释了吗）。
6. [MODIFY] references/kernel/README.md：索引加一行。

#### 验收标准

- [ ] document-expression-spec.md 含 R1-R6+应用矩阵+豁免语义+before/after 微例，且自身符合自身规则（首块白话、表格优先、零未解释黑话）
- [ ] grep 可证 4 个 node manifest 均引用 document-expression-spec 且含落档前消费要求
- [ ] README 索引含该规范
- [ ] 改动面恰为 6 文件；不触碰 manifest schema/transition/guard 表

#### 边界（不做项）

- 不动 manifest 6 章节骨架结构；不写入硬校验；不在规范里内嵌模板全文（模板真相在 pr2，重复真相源是反模式）；不动 must-ask-checklist.md 等其它 kernel reference。

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
- Section: pr1-expression-spec-wiring
- Owner: claude
- Priority: high
- Dependencies: none
