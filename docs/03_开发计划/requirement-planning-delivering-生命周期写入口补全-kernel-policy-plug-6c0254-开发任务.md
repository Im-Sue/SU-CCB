---
doc_type: dev_task
task_id: subtask-2fbd4b6c0254
title: requirement planning→delivering 生命周期写入口补全(kernel policy+plugin 重生+52441f 回填)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpzoupdv863041443e52441f
section_id: pr6-requirement-planning-delivering-kernel-policy-pl
order: 6
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpzoupdv863041443e52441f.json
source_draft_hash: 3ae3676bf12dacf12149b5cf6122f4ac5f568082f7b3fc990eabc1b7c9a4c28e
created_at: 2026-06-07T03:43:13.158Z
updated_at: 2026-06-07T03:56:45.115Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpzoupdv863041443e52441f","branch":"ccb/req-cmpzoupdv863041443e52441f"}
---

# requirement planning→delivering 生命周期写入口补全(kernel policy+plugin 重生+52441f 回填)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 批尾发现的体系 gap:lifecycles/requirement_lifecycle.yaml 已定义 req__on_first_subtask_dispatched__planning_to_delivering(trigger=subtask_dispatched),但 capability policy 层无 delivering 写入口(plugin generated-policy 无条目),导致批执行期 requirement md 永远停 planning、Console 投影无法呈现交付中状态。范围:① kernel capability policy 源 yaml 注册 requirement 状态写 delivering 条目(write_target=requirement_md,state_effects status set:delivering,from 语义=planning,evidence 引用 journal 的 dispatch_submitted 类事件,样式对齐既有 requirement.promote:planning / requirement.finalize:delivered 条目);② capabilities/global.yaml 如需补注册按 promote 既有样式;③ references lint(lint_manifest.py)回归 + plugin lib/capability-outcome/generated-policy.mjs 重生;④ 修复验证:用新写入口把本需求 cmpzoupdv863041443e52441f 从 planning 推到 delivering(走 applyCapabilityOutcome,严禁手写 status),投影 scan 后确认;⑤ plugin 单测矩阵:planning→delivering 成功、delivering 重入幂等语义(no-op 或 guard 拒,对齐 promote:planning 先例)、delivered/cancelled/deferred 态 guard 拒。边界:su-oriel server/src/generated/capability-outcome-policy.ts 重生不在本任务(归下一个 follow-up,其依赖本任务 kernel 变更);不改 CCB runtime;不动既有 transition 定义。 |
| 需求来源 | cmpzoupdv863041443e52441f |
| 本期范围 | pr6-requirement-planning-delivering-kernel-policy-pl · requirement planning→delivering 生命周期写入口补全(kernel policy+plugin 重生+52441f 回填) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### requirement planning→delivering 生命周期写入口补全(kernel policy+plugin 重生+52441f 回填)

> 派生自:task cmq2ikpop0g6hqrpli6fgyh5p(subtask-42f58c56b9cd)

#### Follow-up

- Type: subtask
- Description: 批尾发现的体系 gap:lifecycles/requirement_lifecycle.yaml 已定义 req__on_first_subtask_dispatched__planning_to_delivering(trigger=subtask_dispatched),但 capability policy 层无 delivering 写入口(plugin generated-policy 无条目),导致批执行期 requirement md 永远停 planning、Console 投影无法呈现交付中状态。范围:① kernel capability policy 源 yaml 注册 requirement 状态写 delivering 条目(write_target=requirement_md,state_effects status set:delivering,from 语义=planning,evidence 引用 journal 的 dispatch_submitted 类事件,样式对齐既有 requirement.promote:planning / requirement.finalize:delivered 条目);② capabilities/global.yaml 如需补注册按 promote 既有样式;③ references lint(lint_manifest.py)回归 + plugin lib/capability-outcome/generated-policy.mjs 重生;④ 修复验证:用新写入口把本需求 cmpzoupdv863041443e52441f 从 planning 推到 delivering(走 applyCapabilityOutcome,严禁手写 status),投影 scan 后确认;⑤ plugin 单测矩阵:planning→delivering 成功、delivering 重入幂等语义(no-op 或 guard 拒,对齐 promote:planning 先例)、delivered/cancelled/deferred 态 guard 拒。边界:su-oriel server/src/generated/capability-outcome-policy.ts 重生不在本任务(归下一个 follow-up,其依赖本任务 kernel 变更);不改 CCB runtime;不动既有 transition 定义。
- Source task title: 全链路实机冒烟
- Source task current node: archive

#### Acceptance

- Deliver the follow-up without changing unrelated requirement scope.
- Keep the source task provenance visible in the implementation receipt.

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

- Requirement: cmpzoupdv863041443e52441f
- Section: pr6-requirement-planning-delivering-kernel-policy-pl
- Owner: ccb_codex
- Priority: high
- Dependencies: none
