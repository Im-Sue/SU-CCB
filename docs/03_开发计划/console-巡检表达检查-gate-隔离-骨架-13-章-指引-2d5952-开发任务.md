---
doc_type: dev_task
task_id: subtask-1829d82d5952
title: Console 巡检表达检查（gate 隔离）+ 骨架 13 章📌指引
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmq3feiumac1ad394d74d8dbf
section_id: pr3-oriel-conformance-skeleton
order: 3
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3feiumac1ad394d74d8dbf.json
source_draft_hash: ff7eb04d84c3a93a67878264b1f45843bf7dbf090332a2ab398e89f98f92ba3d
created_at: 2026-06-07T10:11:21.276Z
updated_at: 2026-06-07T10:52:00.000Z
updated_by: slot1_claude
code_workspace: {"path":"../SU-CCB-req-cmq3feiumac1ad394d74d8dbf","branch":"ccb/req-cmq3feiumac1ad394d74d8dbf"}
---

# Console 巡检表达检查（gate 隔离）+ 骨架 13 章📌指引

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | template-conformance.ts 增 expressionIssues 类（expression_spec: v1 gate 启用）+placeholder 残留检查；project-indexer.ts 骨架空标题逐章📌一行指引；default 契约副本补 template 行（第三副本同步）；测试矩阵。su-oriel 仓。 |
| 需求来源 | cmq3feiumac1ad394d74d8dbf |
| 本期范围 | pr3-oriel-conformance-skeleton · Console 巡检表达检查（gate 隔离）+ 骨架 13 章📌指引 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述

让 Console 巡检学会看「表达质量」：带新标记的文档缺目标对齐/示例就亮黄灯（只提醒不拦人）；新建需求的 13 个空标题各配一行📌指引告诉写的人这章写什么。老文档（无标记）零新打扰。仓库：su-oriel（server TS+测试）。技术设计八章 PR3 清单、四章处理规则表。

#### 任务分解

1. [MODIFY] server/src/indexer/template-conformance.ts（现仅产 missingSections，见 :16/:72）：
   - 新增 expressionIssues 检查类，与 missingSections 并列输出（不混同一数组，消费方需区分严重度）
   - gate：frontmatter expression_spec: v1 存在 → 启用表达检查；缺失 → 只跑旧检查（存量行为不变）
   - requirement / technical_design 表达检查：正文含「目标对齐」；含「模拟示例」或「无需示例」（豁免合法）
   - placeholder 残留检查：非 _模板_* 文档含「[占位]」「<由系统生成>」→ expressionIssues（「复制了模板没填」失败模式）
   - dev_task 本轮不查（轻改范围，由 task_breakdown manifest 接线约束）
2. [MODIFY] server/src/indexer/project-indexer.ts：骨架 13 空标题逐章一行📌短指引（常量表实现）；renderRequirementMarkdown 与导出共用常量自动一致。
3. [MODIFY] server/.../default-docs-structure-contract.yaml：补 8 个 template 声明行（与 plugin references/docs-structure-contract.yaml 对齐，第三契约副本同步）。
4. 测试矩阵：conformance 单测（gate 开/关 × 三类检查 × 命中/豁免/残留）；骨架快照更新；parseRequirementSections roundtrip 回归（📌指引行不破坏 5 锚点提取）；_模板_* targeted reindex 行为测试（占位 requirement_id 不误匹配真文档）；frontmatter 未知字段容忍测试。

#### 验收标准

- [ ] 测试矩阵全绿（cd su-oriel/server && 相关 spec + 全量回归）
- [ ] 无 expression_spec 标记的存量文档：零新增 expressionIssues（注意：missingSections 维持现状，不要求归零——gate 隔离的精确证明口径）
- [ ] SyncJob metadata 形状：templateConformance[].expressionIssues: string[] 与 missingSections 并列（additive，零 DB schema 变更）
- [ ] 检查字面标记与设计四章规则表一致；pr1 已合入时与规范 grep 对照一致
- [ ] 13 章📌指引每章一行短句；roundtrip 测试证明 5 锚点提取与导出不受影响

#### 边界（不做项）

- 不动 13 章标题集本身、5 投影锚点、parseRequirementSections 解析逻辑、reindex 硬校验；不做 LLM 评分（巡检只做确定性字面检查）；su-oriel 仓当前有无关 dirty——严格只 stage 本任务三个目标文件+测试，不收编任何无关改动。

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
- Section: pr3-oriel-conformance-skeleton
- Owner: ccb_codex
- Priority: medium
- Dependencies: none
