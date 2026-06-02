---
doc_type: dev_task
task_id: subtask-2784780329b7
title: runtime contract 诉求清单(上游依赖,含手敲拦截)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: low
requirement_id: cmpmlnqxd02346a524ec5c98f
section_id: pr4-runtime-contract
order: 4
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpmlnqxd02346a524ec5c98f.json
source_draft_hash: 9750cbc128d65b47876a065db851dadc30e5d3d63952966e447b861637086a82
created_at: 2026-05-31T12:06:01.567Z
updated_at: 2026-06-01T06:51:39.262Z
updated_by: ai_session
---

# runtime contract 诉求清单(上游依赖,含手敲拦截)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 产出给仓外 ccb runtime 的 contract 诉求(暴露 actor/window/peers + 跨组 warning,含手敲命令拦截);落 ADR-0040 关联,status=proposed;本仓不直接改 runtime。 |
| 需求来源 | cmpmlnqxd02346a524ec5c98f |
| 本期范围 | pr4-runtime-contract · runtime contract 诉求清单(上游依赖,含手敲拦截) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 目标

把'希望仓外 ccb runtime 支持'的能力固化为 contract 诉求(本仓不直接改 runtime),作为上游依赖跟踪 —— 这也是手敲命令错投的真正拦截所在(决策 a 已把它推给 runtime)。

### 范围(文档/诉求清单)

- [NEW] docs/06_决策记录/ADR-0040 关联或其附录,status=proposed:列明请 ccb ask runtime 暴露 current_actor、current_window/group、same_group_peers;并在跨组投递(含手敲命令)时支持 warning / 要求 reason。
- 说明 plugin 层(PR2)只做'流程内尽力提示',真正拦截需 runtime;两者分工写清。
- 标注为上游依赖,不阻塞 PR1-PR3。

### 验收

- 文档清晰列出请求字段/语义 + 动机 + 与 plugin 软提示的分工。

### 边界

不改仓外 runtime 代码;仅产出诉求。

### 依赖

无。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-05-31 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpmlnqxd02346a524ec5c98f
- Section: pr4-runtime-contract
- Owner: ccb_codex
- Priority: low
- Dependencies: none
